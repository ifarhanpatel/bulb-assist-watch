#!/usr/bin/env python3
"""Export only the reviewed publication manifest, without Git or local settings."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def approved_files():
    names = (ROOT / "scripts/public-files.txt").read_text().splitlines()
    if not names or len(names) != len(set(names)):
        raise ValueError("Empty or duplicate publication manifest")
    result = []
    for name in names:
        relative = PurePosixPath(name)
        forbidden = {".git", "build", ".build", "xcuserdata", "__pycache__",
                     ".ssh", ".aws", ".codex", ".agents", ".claude"}
        if (relative.as_posix() != name or "\\" in name or
                relative.is_absolute() or ".." in relative.parts or
                forbidden.intersection(relative.parts) or
                relative.suffix in {".pen", ".p12", ".cer", ".pem", ".key", ".mobileprovision"} or
                relative.name.startswith(".env") or name == "Config/Local.xcconfig"):
            raise ValueError("Forbidden publication path: " + name)
        path = ROOT / name
        if any(part.is_symlink() for part in [path, *path.parents]) or not path.is_file():
            raise ValueError("Missing file or symlink in publication manifest: " + name)
        result.append((name, path))
    return sorted(result)


def export(destination):
    files = approved_files()
    destination.mkdir(parents=True, exist_ok=False)
    source = destination / "bulb-assist-source"
    source.mkdir()
    manifest = {}
    for name, original in files:
        data = original.read_bytes()
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o755 if original.stat().st_mode & 0o111 else 0o644)
        manifest[name] = hashlib.sha256(data).hexdigest()
    (source / "SOURCE_MANIFEST.json").write_text(json.dumps({
        "format": 1, "algorithm": "sha256",
        "files": [{"path": name, "sha256": digest} for name, digest in sorted(manifest.items())],
        "note": "Hashes cover every source file except this generated manifest."
    }, indent=2, sort_keys=True) + "\n")
    archive = destination / "bulb-assist-source.tar.gz"
    with archive.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as bundle:
                for path in sorted(source.rglob("*")):
                    if path.is_file():
                        data = path.read_bytes()
                        info = tarfile.TarInfo("bulb-assist-source/" + path.relative_to(source).as_posix())
                        info.size = len(data)
                        info.mode = path.stat().st_mode & 0o777
                        info.mtime = 0
                        bundle.addfile(info, io.BytesIO(data))
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (destination / "SHA256SUMS").write_text(checksum + "  " + archive.name + "\n")
    print(f"Exported {len(files)} reviewed files to {source}")
    print(f"Archive: {archive}")
    print(f"SHA-256: {checksum}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New output directory; must not already exist")
    args = parser.parse_args()
    if args.output is None:
        parent = ROOT / "build/release"
        parent.mkdir(parents=True, exist_ok=True)
        allocated = Path(tempfile.mkdtemp(prefix="candidate-", dir=parent))
        allocated.rmdir()
        args.output = allocated
    export(args.output.resolve())
