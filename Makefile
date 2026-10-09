SIMULATOR_SIGNING ?= CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
IPHONE_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
WATCH_DESTINATION ?= platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)

.PHONY: generate test test-watch-ui test-platform test-iphone-ui build build-watch build-iphone

generate:
	xcodegen generate

test:
	swift test --package-path Packages/BulbCore --scratch-path build/swift-package

test-watch-ui:
	xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssistWatch -destination '$(WATCH_DESTINATION)' -derivedDataPath build/Watch $(SIMULATOR_SIGNING) test

build: build-watch build-iphone

build-watch:
	xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssistWatch -destination 'generic/platform=watchOS Simulator' -derivedDataPath build/Watch $(SIMULATOR_SIGNING) build

build-iphone:
	xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssist -destination 'generic/platform=iOS Simulator' -derivedDataPath build/iPhone $(SIMULATOR_SIGNING) build

test-platform:
	xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssist -destination '$(IPHONE_DESTINATION)' -derivedDataPath build/iPhone -only-testing:BulbAssistPlatformTests $(SIMULATOR_SIGNING) test

test-iphone-ui:
	xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssist -destination '$(IPHONE_DESTINATION)' -derivedDataPath build/iPhone -only-testing:BulbAssistUITests $(SIMULATOR_SIGNING) test
