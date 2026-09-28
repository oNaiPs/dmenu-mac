import XCTest
@testable import dmenu_mac

final class TerminalLauncherTests: XCTestCase {
    private func plan(_ terminal: Terminal, _ command: String = "nvim",
                      template: String = CommandSettings.defaultCustomTemplate) -> LaunchPlan {
        TerminalLauncher.plan(for: command, terminal: terminal, shell: "/bin/zsh", customTemplate: template)
    }

    // MARK: - Quoting

    func testShellQuotedEscapesSingleQuotes() {
        XCTAssertEqual(TerminalLauncher.shellQuoted("nvim"), "'nvim'")
        XCTAssertEqual(TerminalLauncher.shellQuoted("echo it's"), "'echo it'\\''s'")
    }

    func testAppleScriptQuotedEscapesQuotesAndBackslashes() {
        XCTAssertEqual(TerminalLauncher.appleScriptQuoted("say \"hi\" \\n"), "\"say \\\"hi\\\" \\\\n\"")
    }

    // MARK: - Plans

    func testTerminalAppUsesDoScript() {
        guard case .appleScript(let source) = plan(.terminal, "echo \"a\"") else {
            return XCTFail("Terminal.app should be scripted")
        }
        XCTAssertTrue(source.contains("tell application \"Terminal\""))
        XCTAssertTrue(source.contains("do script \"echo \\\"a\\\"\""))
    }

    func testITermWritesTextToNewWindow() {
        guard case .appleScript(let source) = plan(.iterm2) else {
            return XCTFail("iTerm2 should be scripted")
        }
        XCTAssertTrue(source.contains("tell application \"iTerm\""))
        XCTAssertTrue(source.contains("create window with default profile"))
        XCTAssertTrue(source.contains("write text \"nvim\""))
    }

    func testArgumentTerminalsRunThroughLoginShell() {
        let viaShell = ["/bin/zsh", "-l", "-i", "-c", "nvim"]
        XCTAssertEqual(plan(.ghostty), .openApplication(bundleIdentifier: "com.mitchellh.ghostty",
                                                        arguments: ["-e"] + viaShell))
        XCTAssertEqual(plan(.alacritty), .openApplication(bundleIdentifier: "org.alacritty",
                                                          arguments: ["-e"] + viaShell))
        XCTAssertEqual(plan(.kitty), .openApplication(bundleIdentifier: "net.kovidgoyal.kitty",
                                                      arguments: viaShell))
        XCTAssertEqual(plan(.wezterm), .openApplication(bundleIdentifier: "com.github.wez.wezterm",
                                                        arguments: ["start", "--"] + viaShell))
    }

    func testCustomTemplateSubstitutesQuotedCommand() {
        XCTAssertEqual(plan(.custom, "ranger ~/it's", template: "foot -e sh -c {cmd}"),
                       .shell("foot -e sh -c 'ranger ~/it'\\''s'"))
    }

    func testCustomTemplateWithoutPlaceholderAppendsCommand() {
        XCTAssertEqual(plan(.custom, "htop", template: "foot -e"), .shell("foot -e 'htop'"))
    }

    func testOpenArgumentsStartNewInstanceWithArguments() {
        XCTAssertEqual(TerminalLauncher.openArguments(bundleIdentifier: "org.alacritty", arguments: ["-e", "nvim"]),
                       ["-n", "-b", "org.alacritty", "--args", "-e", "nvim"])
    }

    func testLoginShellIsAbsolutePath() {
        XCTAssertTrue(TerminalLauncher.loginShell().hasPrefix("/"))
    }
}
