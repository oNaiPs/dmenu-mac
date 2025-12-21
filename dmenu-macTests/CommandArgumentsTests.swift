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
}
