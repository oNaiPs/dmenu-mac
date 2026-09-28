/*
 * Copyright (c) 2026 Jose Pereira <onaips@gmail.com>.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import FileWatcher

/// A program found in $PATH.
struct Command: Equatable {
    var commandLine: String
}

/**
 * Provide the programs in the user's $PATH, like dmenu_run. Actions open them in a terminal.
 */
class CommandListProvider: ListProvider {
    private let settings: CommandSettings
    private let launcher: TerminalLauncher
    private let searchPathsLoader: () -> [String]
    private let inputFallback: ListProvider?

    private var commands = [String]()
    private var loaded = false
    private var loading = false
    private var fileWatcher: FileWatcher?
    private var pendingUpdate: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.dmenu-mac.commandlist", attributes: .concurrent)

    init(settings: CommandSettings = .shared,
         launcher: TerminalLauncher = TerminalLauncher(),
         searchPathsLoader: @escaping () -> [String] = { CommandListProvider.searchPaths() },
         inputFallback: ListProvider? = nil) {
        self.settings = settings
        self.launcher = launcher
        self.searchPathsLoader = searchPathsLoader
        self.inputFallback = inputFallback

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged), name: .commandSettingsChanged, object: nil)
        if settings.enabled {
            reload()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // A started FileWatcher is retained by its FSEvents stream until stopped.
        fileWatcher?.stop()
    }

    @objc private func settingsChanged() {
        let idle = queue.sync { !loaded && !loading }
        if settings.enabled && idle {
            reload()
        }
    }

    /// Loads in the background: the login shell can take a while to start.
    func reload(completion: (() -> Void)? = nil) {
        queue.sync(flags: .barrier) { loading = true }
        DispatchQueue.global(qos: .userInitiated).async {
            let paths = self.searchPathsLoader()
            self.update(paths)
            DispatchQueue.main.async {
                self.watch(paths)
                completion?()
            }
        }
    }

    private func update(_ paths: [String]) {
        let newCommands = CommandListProvider.executables(in: paths)
        queue.async(flags: .barrier) {
            self.commands = newCommands
            self.loaded = true
            self.loading = false
        }
    }

    private func watch(_ paths: [String]) {
        fileWatcher?.stop()
        let watcher = FileWatcher(paths)
        watcher.callback = { [weak self] _ in
            self?.scheduleUpdate(paths)
        }
        watcher.start()
        fileWatcher = watcher
    }

    /// Coalesces bursts of file events, e.g. from `brew upgrade`, into one rescan.
    private func scheduleUpdate(_ paths: [String]) {
        pendingUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.update(paths)
        }
        pendingUpdate = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - $PATH discovery

    /// Directories from the login shell's $PATH, since apps launched by launchd only get a bare PATH.
    static func searchPaths(loginShellPath: [String]? = CommandListProvider.loginShellPath()) -> [String] {
        let paths = loginShellPath ?? fallbackPaths()
        var seen = Set<String>()
        return paths.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static let pathStartMarker = "__DMENU_PATH__"
    static let pathEndMarker = "__DMENU_PATH_END__"
    /// Prints $PATH between markers, so rc and logout file output around it is ignored.
    static let pathProbeCommand = "printf '\(pathStartMarker)%s\(pathEndMarker)' \"$PATH\""

    /// Interactive so PATH set in .zshrc/.bashrc is picked up.
    static func loginShellPath(shell: String = TerminalLauncher.loginShell(),
                               arguments: [String] = ["-l", "-i", "-c", pathProbeCommand],
                               timeout: TimeInterval = 5) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        // Wait for the end marker or EOF rather than for exit: rc files may start daemons
        // that keep the pipe open, and interactive zsh ignores SIGTERM.
        let lock = NSLock()
        var data = Data()
        let finished = DispatchSemaphore(value: 0)
        let endMarker = Data(pathEndMarker.utf8)
        output.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            lock.lock()
            data.append(chunk)
            let done = chunk.isEmpty || data.range(of: endMarker) != nil
            lock.unlock()
            if done {
                handle.readabilityHandler = nil
                finished.signal()
            }
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            NSLog("Cannot read PATH from %@: %@", shell, error.localizedDescription)
            return nil
        }

        let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
        output.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        if timedOut {
            NSLog("Timed out reading PATH from %@", shell)
            return nil
        }

        lock.lock()
        let str = String(data: data, encoding: .utf8)
        lock.unlock()
        return str.flatMap(parsePath)
    }

    static func parsePath(_ output: String) -> [String]? {
        guard let start = output.range(of: pathStartMarker, options: .backwards),
              let end = output.range(of: pathEndMarker, range: start.upperBound..<output.endIndex) else {
            return nil
        }
        let path = output[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path.components(separatedBy: ":")
    }

    /// Used when the login shell can't be queried: system paths plus common brew and nix locations.
    static func fallbackPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths = [String]()
        if let etcPaths = try? String(contentsOfFile: "/etc/paths", encoding: .utf8) {
            paths += etcPaths.components(separatedBy: .newlines)
        }
        if let files = try? FileManager.default.contentsOfDirectory(atPath: "/etc/paths.d") {
            for file in files.sorted() {
                if let contents = try? String(contentsOfFile: "/etc/paths.d/\(file)", encoding: .utf8) {
                    paths += contents.components(separatedBy: .newlines)
                }
            }
        }
        paths += [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            "\(home)/.nix-profile/bin", "/etc/profiles/per-user/\(NSUserName())/bin",
            "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin",
            "\(home)/.local/bin"
        ]
        return paths.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Executable file names in the given directories, first occurrence winning like PATH lookup.
    static func executables(in paths: [String]) -> [String] {
        let fileManager = FileManager.default
        var seen = Set<String>()
        var result = [String]()
        for path in paths {
            guard let names = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            for name in names.sorted() where !name.hasPrefix(".") && !seen.contains(name) {
                let full = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                // fileExists follows symlinks, e.g. nix profiles pointing into /nix/store.
                if fileManager.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue,
                   fileManager.isExecutableFile(atPath: full) {
                    seen.insert(name)
                    result.append(name)
                }
            }
        }
        return result
    }

    // MARK: - ListProvider

    func get() -> [ListItem] {
        guard settings.enabled else { return [] }
        return queue.sync {
            commands.map { ListItem(name: $0, data: Command(commandLine: $0)) }
        }
    }

    func doAction(item: ListItem) {
        guard let command = item.data as? Command else {
            NSLog("Cannot do action on item \(item.name)")
            return
        }
        launcher.run(command.commandLine)
    }

    /// Typed commands, e.g. "nvim notes.md", open in the terminal once programs are enabled.
    /// Otherwise they go to the fallback, which runs them in the background.
    func doAction(input: String) {
        if settings.enabled {
            launcher.run(input)
        } else {
            inputFallback?.doAction(input: input)
        }
    }
}
