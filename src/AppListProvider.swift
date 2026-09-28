/*
 * Copyright (c) 2020 Jose Pereira <onaips@gmail.com>.
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

import Cocoa
import FileWatcher
import Fuse

/**
 * Provide a list of launcheable apps and preference panes for the OS
 */
class AppListProvider: ListProvider {

    var appDirDict = [String: Bool]()

    static let launchableExtensions: Set<String> = ["app", "prefPane"]

    private var appList = [ListItem]()
    private let appListQueue = DispatchQueue(label: "com.dmenu-mac.applist", attributes: .concurrent)

    init() {
        let applicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .localDomainMask, true)[0]

        // Catalina moved default applications under a different mask.
        let systemApplicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .systemDomainMask, true)[0]

        // Per-user apps, e.g. nix home-manager's "Home Manager Apps" or "Chrome Apps.localized".
        let userApplicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .userDomainMask, true)[0]

        // appName to dir recursivity key/valye dict
        appDirDict[applicationDir] = true
        appDirDict[systemApplicationDir] = true
        appDirDict[userApplicationDir] = true
        appDirDict["/System/Library/CoreServices/"] = false

        // System Settings panes, e.g. Displays or Network.
        appDirDict["/System/Library/PreferencePanes"] = false
        appDirDict["/Library/PreferencePanes"] = false
        appDirDict[NSSearchPathForDirectoriesInDomains(
            .preferencePanesDirectory, .userDomainMask, true)[0]] = false

        initFileWatch(Array(appDirDict.keys))
        updateAppList()
    }

    func initFileWatch(_ dirs: [String]) {
        let filewatcher = FileWatcher(dirs)
        filewatcher.callback = {_ in
            self.updateAppList()
        }
        filewatcher.start()
    }

    func updateAppList() {
        var newAppList = [ListItem]()
        appDirDict.keys.forEach { path in
            let urlPath = URL(fileURLWithPath: path, isDirectory: true)
            let list = getAppList(urlPath, recursive: appDirDict[path]!)
            newAppList.append(contentsOf: list.map { ListItem(name: AppListProvider.displayName(for: $0), data: $0) })
        }
        appListQueue.async(flags: .barrier) {
            self.appList = newAppList
        }
    }

    func getAppList(_ appDir: URL, recursive: Bool = true) -> [URL] {
        var visited = Set<String>()
        return getAppList(appDir, recursive: recursive, visited: &visited)
    }

    private func getAppList(_ appDir: URL, recursive: Bool, visited: inout Set<String>) -> [URL] {
        var list = [URL]()
        let fileManager = FileManager.default

        // Guard against symlink loops.
        guard visited.insert(appDir.resolvingSymlinksInPath().path).inserted else {
            return list
        }

        do {
            let subs = try fileManager.contentsOfDirectory(atPath: appDir.path)

            for sub in subs {
                let dir = appDir.appendingPathComponent(sub)

                if AppListProvider.launchableExtensions.contains(dir.pathExtension) {
                    list.append(dir)
                } else if recursive && isDirectory(dir) {
                    list.append(contentsOf: getAppList(dir, recursive: true, visited: &visited))
                }
            }
        } catch {
            NSLog("Error on getAppList: %@", error.localizedDescription)
        }
        return list
    }

    /// Follows symlinks, e.g. nix-darwin's "/Applications/Nix Apps" pointing into /nix/store.
    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Pane file names can be cryptic (UniversalAccessPref), so prefer the bundle name (Accessibility).
    static func displayName(for url: URL) -> String {
        if url.pathExtension == "prefPane",
           let bundle = Bundle(url: url),
           let name = (bundle.localizedInfoDictionary?["CFBundleName"] ?? bundle.infoDictionary?["CFBundleName"])
            as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }

    func get() -> [ListItem] {
        return appListQueue.sync { appList }
    }

    func doAction(item: ListItem) {
        guard let app: URL = item.data as? URL else {
            NSLog("Cannot do action on item \(item.name)")
            return
        }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(app)
        }
    }

    /// Runs the typed text as a shell command.
    func doAction(input: String) {
        do {
            try AppListProvider.shellProcess(command: input).run()
        } catch {
            NSLog("Cannot run command %@: %@", input, error.localizedDescription)
        }
    }

    /// Uses a login shell so PATH includes Homebrew/nix; apps launched from Finder only get /usr/bin:/bin.
    static func shellProcess(command: String,
                             environment: [String: String] = ProcessInfo.processInfo.environment) -> Process {
        let home = environment["HOME"] ?? NSHomeDirectory()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: environment["SHELL"] ?? "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: home, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }
}
