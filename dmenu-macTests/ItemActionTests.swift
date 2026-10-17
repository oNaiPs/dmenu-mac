import XCTest
@testable import dmenu_mac

final class ItemActionTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var revealed: [URL] = []
    private var newInstances: [URL] = []
    private var opened: [URL] = []

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name("dmenu-mac-tests-\(UUID().uuidString)"))
        revealed = []
        newInstances = []
        opened = []
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    private func makeFileActions() -> FileActions {
        var actions = FileActions()
        actions.reveal = { self.revealed.append($0) }
        actions.openNewInstance = { self.newInstances.append($0) }
        actions.open = { self.opened.append($0) }
        actions.pasteboard = pasteboard
        return actions
    }

    private func drainMainQueue() {
        let done = expectation(description: "main queue drained")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    private func keyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
                         isARepeat: false, keyCode: keyCode)
    }

    // MARK: - Modifier mapping

    func testModifierMapping() {
        XCTAssertEqual(ItemAction(modifiers: []), .open)
        XCTAssertEqual(ItemAction(modifiers: .command), .reveal)
        XCTAssertEqual(ItemAction(modifiers: .option), .copyPath)
        XCTAssertEqual(ItemAction(modifiers: .control), .openNewInstance)
        XCTAssertEqual(ItemAction(modifiers: .shift), .open)
        // Caps Lock or the keypad flag must not change the action
        XCTAssertEqual(ItemAction(modifiers: [.capsLock, .numericPad]), .open)
    }

    // MARK: - Submit detection

    func testInsertNewlineIsAlwaysSubmit() {
        XCTAssertTrue(ItemAction.isSubmit(#selector(NSResponder.insertNewline(_:)), event: nil))
    }

    func testModifiedReturnCommandsAreSubmit() {
        let event = keyDown(keyCode: 36, modifiers: .command)
        XCTAssertTrue(ItemAction.isSubmit(Selector(("noop:")), event: event))
        XCTAssertTrue(ItemAction.isSubmit(#selector(NSResponder.insertLineBreak(_:)), event: event))
        XCTAssertTrue(ItemAction.isSubmit(#selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                                          event: keyDown(keyCode: 76)))
    }

    func testOtherKeysAreNotSubmit() {
        // ⌃O sends insertNewlineIgnoringFieldEditor too
        let ctrlO = keyDown(keyCode: 31, modifiers: .control)
        XCTAssertFalse(ItemAction.isSubmit(#selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                                           event: ctrlO))
        XCTAssertFalse(ItemAction.isSubmit(Selector(("noop:")), event: nil))
        XCTAssertFalse(ItemAction.isSubmit(#selector(NSResponder.moveRight(_:)), event: keyDown(keyCode: 36)))
    }

    // MARK: - FileActions

    func testOpenIsLeftToTheProvider() {
        XCTAssertFalse(makeFileActions().perform(.open, on: URL(fileURLWithPath: "/Applications/Safari.app")))
    }

    func testCopyPathPutsPathOnPasteboard() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        XCTAssertTrue(makeFileActions().perform(.copyPath, on: url))
        XCTAssertEqual(pasteboard.string(forType: .string), "/Applications/Safari.app")
    }

    func testRevealAndNewInstance() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let actions = makeFileActions()
        actions.perform(.reveal, on: url)
        actions.perform(.openNewInstance, on: url)
        drainMainQueue()
        XCTAssertEqual(revealed, [url])
        XCTAssertEqual(newInstances, [url])
    }

    // MARK: - Providers

    func testAppProviderRoutesAlternateActions() {
        let provider = AppListProvider()
        provider.fileActions = makeFileActions()
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        let item = ListItem(name: "Calculator", data: url)

        provider.doAction(item: item, action: .copyPath)
        provider.doAction(item: item, action: .reveal)
        provider.doAction(item: item, action: .openNewInstance)
        drainMainQueue()

        XCTAssertEqual(pasteboard.string(forType: .string), url.path)
        XCTAssertEqual(revealed, [url])
        XCTAssertEqual(newInstances, [url])
    }

    func testNewInstanceOfPaneJustOpensIt() {
        let provider = AppListProvider()
        provider.fileActions = makeFileActions()
        let pane = URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane")

        provider.doAction(item: ListItem(name: "Displays", data: pane), action: .openNewInstance)
        drainMainQueue()

        XCTAssertTrue(newInstances.isEmpty)
        XCTAssertEqual(opened, [pane])
    }

    /// Goes through the real provider stack so a wrapper that drops the action is caught.
    func testFactoryStackDeliversActionToAppProvider() throws {
        let provider = ProviderFactory().createProvider(stdinContent: "")
        let composite = try XCTUnwrap(provider as? CompositeListProvider)
        let apps = try XCTUnwrap(composite.providers.first { $0 is AppListProvider } as? AppListProvider)
        apps.fileActions = makeFileActions()
        let item = try XCTUnwrap(provider.get().first { $0.name == "Calculator" })

        provider.doAction(item: item, action: .copyPath)
        provider.doAction(item: item, action: .reveal)
        drainMainQueue()

        XCTAssertEqual(pasteboard.string(forType: .string), "/System/Applications/Calculator.app")
        XCTAssertEqual(revealed.map { $0.path }, ["/System/Applications/Calculator.app"])
        XCTAssertTrue(opened.isEmpty)
    }

    func testCompositeForwardsAction() {
        let first = MockListProvider(items: [ListItem(name: "a", data: nil)])
        let second = MockListProvider(items: [ListItem(name: "b", data: nil)])
        let composite = CompositeListProvider(providers: [first, second])
        let item = composite.get()[1]

        composite.doAction(item: item, action: .reveal)

        XCTAssertEqual(second.lastAction, .reveal)
        XCTAssertEqual(second.lastActionedItem?.name, "b")
        XCTAssertNil(first.lastAction)
    }

    func testProvidersWithoutAlternateActionsFallBackToPlainAction() {
        // e.g. PipeListProvider keeps printing the choice on ⌘/⌥/⌃ Enter.
        final class PlainProvider: ListProvider {
            var actioned: [String] = []
            func get() -> [ListItem] { [] }
            func doAction(item: ListItem) { actioned.append(item.name) }
        }
        let provider: ListProvider = PlainProvider()
        provider.doAction(item: ListItem(name: "Yes", data: nil), action: .copyPath)
        XCTAssertEqual((provider as? PlainProvider)?.actioned, ["Yes"])
    }
}
