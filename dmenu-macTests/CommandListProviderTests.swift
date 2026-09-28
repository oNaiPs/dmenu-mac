import XCTest
@testable import dmenu_mac

/// Records commands instead of opening a terminal.
final class RecordingTerminalLauncher: TerminalLauncher {
    var commands: [String] = []

    override func run(_ command: String) {
        commands.append(command)
    }
}

final class CommandListProviderTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var settings: CommandSettings!
    var binDir: URL!
    var otherBinDir: URL!
    var launcher: RecordingTerminalLauncher!
    var fallback: MockListProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CommandListProviderTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = CommandSettings(defaults: defaults)
        launcher = RecordingTerminalLauncher(settings: settings)
        fallback = MockListProvider()

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        binDir = root.appendingPathComponent("bin")
        otherBinDir = root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherBinDir, withIntermediateDirectories: true)

        try makeExecutable(binDir, "nvim")
        try makeExecutable(binDir, "ranger")
        try makeExecutable(binDir, ".hidden")
        try FileManager.default.createDirectory(at: binDir.appendingPathComponent("subdir"),
                                                withIntermediateDirectories: true)
        try "not executable".write(to: binDir.appendingPathComponent("README"), atomically: true, encoding: .utf8)
        try makeExecutable(otherBinDir, "nvim")
        try makeExecutable(otherBinDir, "htop")
        // Symlinked binaries, as in nix profiles
        try FileManager.default.createSymbolicLink(at: otherBinDir.appendingPathComponent("vi"),
                                                   withDestinationURL: binDir.appendingPathComponent("nvim"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: binDir.deletingLastPathComponent())
        defaults.removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    private func makeExecutable(_ dir: URL, _ name: String) throws {
        let url = dir.appendingPathComponent(name)
        try "#!/bin/sh\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func makeProvider() -> CommandListProvider {
        let paths = [binDir.path, otherBinDir.path]
        return CommandListProvider(settings: settings, launcher: launcher,
                                   searchPathsLoader: { paths }, inputFallback: fallback)
    }

    private func load(_ provider: CommandListProvider) {
        let done = expectation(description: "loaded")
        provider.reload { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    // MARK: - Executable discovery

    func testExecutablesSkipsHiddenDirectoriesAndNonExecutables() {
        XCTAssertEqual(CommandListProvider.executables(in: [binDir.path]), ["nvim", "ranger"])
    }

    func testExecutablesFirstPathWinsAndFollowsSymlinks() {
        XCTAssertEqual(CommandListProvider.executables(in: [binDir.path, otherBinDir.path]),
                       ["nvim", "ranger", "htop", "vi"])
    }

    func testExecutablesIgnoresMissingDirectories() {
        XCTAssertEqual(CommandListProvider.executables(in: ["/nonexistent-dmenu-path", binDir.path]),
                       ["nvim", "ranger"])
    }

    // MARK: - $PATH discovery

    // Uses /bin/sh with explicit scripts so tests never run the developer's rc files.
    private func probe(_ script: String, timeout: TimeInterval = 5) -> [String]? {
        CommandListProvider.loginShellPath(shell: "/bin/sh", arguments: ["-c", script], timeout: timeout)
    }

    func testLoginShellPathReadsPath() {
        XCTAssertEqual(probe("PATH=/a:/b; " + CommandListProvider.pathProbeCommand), ["/a", "/b"])
    }

    func testLoginShellPathIgnoresOutputAroundMarkers() {
        let script = "echo motd; PATH=/a:/b; " + CommandListProvider.pathProbeCommand + "; echo bye"
        XCTAssertEqual(probe(script), ["/a", "/b"], "e.g. .zlogout output must not corrupt the last entry")
    }

    func testLoginShellPathDoesNotWaitForBackgroundChildren() {
        let start = Date()
        let script = "sleep 30 & PATH=/a; " + CommandListProvider.pathProbeCommand
        XCTAssertEqual(probe(script), ["/a"])
        XCTAssertLessThan(Date().timeIntervalSince(start), 5, "a daemon holding stdout must not block")
    }

    func testLoginShellPathTimesOutOnShellIgnoringSigterm() {
        let start = Date()
        XCTAssertNil(probe("trap '' TERM; sleep 30", timeout: 0.5))
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testLoginShellPathReturnsNilWithoutMarkers() {
        XCTAssertNil(probe("echo /usr/bin"))
    }

    func testLoginShellPathReturnsNilForBrokenShell() {
        XCTAssertNil(CommandListProvider.loginShellPath(shell: "/nonexistent-shell"))
    }

    func testParsePathUsesLastStartMarker() {
        let start = CommandListProvider.pathStartMarker
        let end = CommandListProvider.pathEndMarker
        XCTAssertEqual(CommandListProvider.parsePath("\(start)junk \(start)/a:/b\(end)\n"), ["/a", "/b"])
        XCTAssertNil(CommandListProvider.parsePath("\(start)/a"), "No end marker means truncated output")
        XCTAssertNil(CommandListProvider.parsePath("\(start)\(end)"))
    }

    func testFallbackPathsIncludeSystemBrewAndNix() {
        let paths = CommandListProvider.fallbackPaths()
        XCTAssertTrue(paths.contains("/opt/homebrew/bin"))
        XCTAssertTrue(paths.contains("/run/current-system/sw/bin"))
        XCTAssertTrue(paths.contains("/nix/var/nix/profiles/default/bin"))
    }

    func testSearchPathsDropsDuplicatesAndEmptyEntries() {
        XCTAssertEqual(CommandListProvider.searchPaths(loginShellPath: ["/a", "", "/b", "/a"]), ["/a", "/b"])
    }

    func testSearchPathsFallsBackWhenShellFails() {
        XCTAssertTrue(CommandListProvider.searchPaths(loginShellPath: nil).contains("/opt/homebrew/bin"))
    }

    // MARK: - ListProvider

    func testGetIsEmptyWhenDisabled() {
        let provider = makeProvider()
        load(provider)
        XCTAssertTrue(provider.get().isEmpty)
    }

    func testGetListsCommandsWhenEnabled() {
        settings.enabled = true
        let provider = makeProvider()
        load(provider)

        let items = provider.get()
        XCTAssertEqual(items.map { $0.name }, ["nvim", "ranger", "htop", "vi"])
        XCTAssertEqual(items.first?.data as? Command, Command(commandLine: "nvim"))
    }

    func testEnablingLoadsCommands() {
        let provider = makeProvider()
        settings.enabled = true

        let loaded = expectation(description: "commands loaded after enabling")
        func poll() {
            if !provider.get().isEmpty {
                loaded.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }
        poll()
        wait(for: [loaded], timeout: 5)
    }

    func testDoActionOpensCommandInTerminal() {
        makeProvider().doAction(item: ListItem(name: "nvim", data: Command(commandLine: "nvim")))
        XCTAssertEqual(launcher.commands, ["nvim"])
    }

    func testTypedInputOpensInTerminalWhenEnabled() {
        settings.enabled = true
        makeProvider().doAction(input: "nvim notes.md")

        XCTAssertEqual(launcher.commands, ["nvim notes.md"])
        XCTAssertTrue(fallback.inputActions.isEmpty)
    }

    func testTypedInputGoesToFallbackWhenDisabled() {
        makeProvider().doAction(input: "mpv test.mp4")

        XCTAssertTrue(launcher.commands.isEmpty)
        XCTAssertEqual(fallback.inputActions, ["mpv test.mp4"])
    }

    func testDoActionWithInvalidDataDoesNotCrash() {
        makeProvider().doAction(item: ListItem(name: "Invalid", data: "not a command"))
        XCTAssertTrue(launcher.commands.isEmpty)
    }
}
