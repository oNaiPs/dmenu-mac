import XCTest
@testable import dmenu_mac

final class CommandArgumentsTests: XCTestCase {
    func testDefaultPromptIsNil() throws {
        let args = try DmenuMac.parse([])
        XCTAssertNil(args.prompt)
    }

    func testShortPromptParsesValue() throws {
        let args = try DmenuMac.parse(["-p", "hello"])
        XCTAssertEqual(args.prompt, "hello")
    }

    func testLongPromptParsesValue() throws {
        let args = try DmenuMac.parse(["--prompt", "menu"])
        XCTAssertEqual(args.prompt, "menu")
    }

    func testExitFlagDefaultsToUnset() throws {
        let args = try DmenuMac.parse([])
        XCTAssertNil(args.exit)
    }

    func testExitFlagParsesBothForms() throws {
        XCTAssertEqual(try DmenuMac.parse(["--exit"]).exit, true)
        XCTAssertEqual(try DmenuMac.parse(["--no-exit"]).exit, false)
    }

    func testExitsWhenStartedFromShell() {
        XCTAssertTrue(DmenuMac.shouldExitOnClose(flag: nil, parentPID: 4242))
    }

    func testStaysWhenLaunchedByLaunchServices() {
        XCTAssertFalse(DmenuMac.shouldExitOnClose(flag: nil, parentPID: 1))
    }

    func testFlagOverridesDetection() {
        XCTAssertTrue(DmenuMac.shouldExitOnClose(flag: true, parentPID: 1))
        XCTAssertFalse(DmenuMac.shouldExitOnClose(flag: false, parentPID: 4242))
    }
}
