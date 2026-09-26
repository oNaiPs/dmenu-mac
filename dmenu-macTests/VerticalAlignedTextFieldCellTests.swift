import XCTest
@testable import dmenu_mac

final class VerticalAlignedTextFieldCellTests: XCTestCase {
    var cell: VerticalAlignedTextFieldCell!
    var textField: NSTextField!

    override func setUp() {
        super.setUp()
        cell = VerticalAlignedTextFieldCell(textCell: "Hello")
        textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textField.cell = cell
    }

    override func tearDown() {
        cell = nil
        textField = nil
        super.tearDown()
    }

    func testDrawingRectIsVerticallyCentered() {
        let bounds = NSRect(x: 0, y: 0, width: 200, height: 100)
        let plain = NSTextFieldCell(textCell: "Hello").drawingRect(forBounds: bounds)

        let rect = cell.drawingRect(forBounds: bounds)

        XCTAssertLessThan(rect.height, plain.height)
        XCTAssertEqual(rect.midY, plain.midY, accuracy: 1.0)
    }

    func testDrawingRectIsUnchangedWhileEditing() {
        let bounds = NSRect(x: 0, y: 0, width: 200, height: 100)
        let plain = NSTextFieldCell(textCell: "Hello").drawingRect(forBounds: bounds)

        cell.editingOrSelecting = true

        XCTAssertEqual(cell.drawingRect(forBounds: bounds), plain)
    }

    func testEditDoesNotRecurseAndResetsFlag() {
        // Used to call self.edit(...) and overflow the stack.
        cell.edit(withFrame: textField.bounds, in: textField, editor: NSTextView(),
                  delegate: nil, event: nil)
        XCTAssertFalse(cell.editingOrSelecting)
    }

    func testSelectResetsFlag() {
        cell.select(withFrame: textField.bounds, in: textField, editor: NSTextView(),
                    delegate: nil, start: 0, length: 5)
        XCTAssertFalse(cell.editingOrSelecting)
    }
}
