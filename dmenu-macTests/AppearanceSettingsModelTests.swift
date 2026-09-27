import XCTest
import SwiftUI
@testable import dmenu_mac

final class AppearanceSettingsModelTests: XCTestCase {
    var model: AppearanceSettingsModel!
    private var snapshot: AppearanceDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = AppearanceDefaultsSnapshot()
        AppearanceDefaultsSnapshot.clear()
        model = AppearanceSettingsModel()
    }

    override func tearDown() {
        model = nil
        snapshot.restore()
        super.tearDown()
    }

    // MARK: - Ranges

    func testControlRangesMatchPreviousLimits() {
        XCTAssertEqual(AppearanceSettingsModel.opacityRange, 0.2...1.0)
        XCTAssertEqual(AppearanceSettingsModel.fontSizeRange, 8...72)
    }

    // MARK: - Reflecting stored settings

    func testModelReflectsStoredSettings() {
        let manager = AppearanceManager.shared
        manager.windowOpacity = 0.75
        manager.fontSize = 18
        manager.windowPosition = .bottom

        XCTAssertEqual(model.windowOpacity, 0.75, accuracy: 0.0001)
        XCTAssertEqual(model.opacityText, "75%")
        XCTAssertEqual(model.fontSize, 18, accuracy: 0.0001)
        XCTAssertEqual(model.fontSizeText, "18 pt")
        XCTAssertEqual(model.windowPosition, .bottom)
    }

    func testOpacityTextRoundsInsteadOfTruncating() {
        AppearanceManager.shared.windowOpacity = 0.29
        XCTAssertEqual(model.opacityText, "29%")
    }

    func testFontDisplayNameFallsBackToSystemFont() {
        XCTAssertEqual(model.fontDisplayName, NSFont.systemFont(ofSize: 13).displayName)
    }

    // MARK: - Writing settings

    func testChangingPositionStoresItAndNotifies() {
        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        model.windowPosition = .bottom
        wait(for: [notified], timeout: 1.0)

        XCTAssertEqual(AppearanceManager.shared.windowPosition, .bottom)
    }

    func testChangingOpacityStoresItAndNotifies() {
        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        model.windowOpacity = 0.4
        wait(for: [notified], timeout: 1.0)

        XCTAssertEqual(AppearanceManager.shared.windowOpacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(model.opacityText, "40%")
    }

    func testChangingFontSizeStoresItAndNotifies() {
        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        model.fontSize = 21
        wait(for: [notified], timeout: 1.0)

        XCTAssertEqual(AppearanceManager.shared.fontSize, 21, accuracy: 0.0001)
        XCTAssertEqual(model.fontSizeText, "21 pt")
    }

    func testChangingColorPersistsAsArchivableColor() {
        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        model.searchTextColor = Color(red: 1, green: 0, blue: 0)
        wait(for: [notified], timeout: 1.0)

        // Read back through a fresh manager so the value must come from UserDefaults.
        let stored = AppearanceManager().searchTextColor.usingColorSpace(.sRGB)
        XCTAssertEqual(stored?.redComponent ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(stored?.greenComponent ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(stored?.blueComponent ?? 1, 0, accuracy: 0.01)
    }

    func testModelPublishesBeforeEachChange() {
        var published = 0
        let subscription = model.objectWillChange.sink { published += 1 }
        defer { subscription.cancel() }

        model.windowOpacity = 0.5
        model.fontSize = 14
        model.windowPosition = .bottom

        XCTAssertEqual(published, 3)
    }

    // MARK: - Reset

    func testResetToDefaultsRestoresValuesAndNotifies() {
        let manager = AppearanceManager.shared
        manager.windowOpacity = 0.3
        manager.fontSize = 40
        manager.windowPosition = .bottom

        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        model.resetToDefaults()
        wait(for: [notified], timeout: 1.0)

        XCTAssertEqual(manager.windowOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(model.opacityText, "60%")
        XCTAssertEqual(model.fontSizeText, "13 pt")
        XCTAssertEqual(model.windowPosition, .top)
    }

    // MARK: - Font panel

    func testChooseFontMakesModelTheFontManagerTarget() {
        model.chooseFont()
        defer { NSFontPanel.shared.orderOut(nil) }

        XCTAssertTrue(NSFontManager.shared.target === model)
    }

    func testDeallocatedModelClearsFontManagerTarget() {
        weak var weakModel: AppearanceSettingsModel?

        autoreleasepool {
            let model = AppearanceSettingsModel()
            weakModel = model
            NSFontManager.shared.target = model
        }

        XCTAssertNil(weakModel)
        XCTAssertNil(NSFontManager.shared.target)
    }
}
