import XCTest
import BulbCore

final class PlatformContractTests: XCTestCase {
    func testProvisioningSerializationKeepsRevision() throws {
        let message = ProvisioningMessage.remove(revision: 3)
        let restored = try JSONDecoder().decode(ProvisioningMessage.self, from: JSONEncoder().encode(message))
        XCTAssertEqual(restored, message)
    }
}
