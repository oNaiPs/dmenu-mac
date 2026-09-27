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

    func testCustomInputAllowedByDefault() throws {
        XCTAssertFalse(try DmenuMac.parse([]).noCustom)
    }

    func testNoCustomFlagParses() throws {
        XCTAssertTrue(try DmenuMac.parse(["--no-custom"]).noCustom)
    }

    func testBottomFlagDefaultsToOff() throws {
        XCTAssertFalse(try DmenuMac.parse([]).bottom)
    }

    func testBottomFlagParsesBothForms() throws {
        XCTAssertTrue(try DmenuMac.parse(["-b"]).bottom)
        XCTAssertTrue(try DmenuMac.parse(["--bottom"]).bottom)
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

    func testPromptPreservesSpaces() throws {
        let args = try DmenuMac.parse(["-p", "Are you sure?"])
        XCTAssertEqual(args.prompt, "Are you sure?")
    }

    func testPromptWithoutValueThrows() {
        XCTAssertThrowsError(try DmenuMac.parse(["-p"]))
    }

    func testUnknownOptionThrows() {
        XCTAssertThrowsError(try DmenuMac.parse(["--unknown"]))
    }
}
