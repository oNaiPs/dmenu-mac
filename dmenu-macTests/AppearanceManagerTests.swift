import XCTest
@testable import dmenu_mac

/// Saves and restores the appearance keys, since tests run against the host app's real defaults.
struct AppearanceDefaultsSnapshot {
    static let keys = [
        UserDefaults.AppearanceKeys.searchTextColor,
        UserDefaults.AppearanceKeys.resultsTextColor,
        UserDefaults.AppearanceKeys.selectionHighlightColor,
        UserDefaults.AppearanceKeys.windowBackgroundColor,
        UserDefaults.AppearanceKeys.windowOpacity,
        UserDefaults.AppearanceKeys.fontName,
        UserDefaults.AppearanceKeys.fontSize,
        UserDefaults.AppearanceKeys.windowPosition
    ]

    private let saved: [String: Any]

    init() {
        let defaults = UserDefaults.standard
        var saved = [String: Any]()
        for key in Self.keys {
            saved[key] = defaults.object(forKey: key)
        }
        self.saved = saved
    }

    static func clear() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    func restore() {
        Self.clear()
        saved.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
    }
}

final class AppearanceManagerTests: XCTestCase {
    var manager: AppearanceManager!
    private var snapshot: AppearanceDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = AppearanceDefaultsSnapshot()
        AppearanceDefaultsSnapshot.clear()
        manager = AppearanceManager()
    }

    override func tearDown() {
        snapshot.restore()
        manager = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultColorsWhenUnset() {
        XCTAssertEqual(manager.searchTextColor, NSColor.textColor)
        XCTAssertEqual(manager.resultsTextColor, NSColor.textColor)
        XCTAssertEqual(manager.selectionHighlightColor, NSColor.selectedTextBackgroundColor)
        XCTAssertEqual(manager.windowBackgroundColor, NSColor.windowBackgroundColor)
    }

    func testDefaultOpacityAndFontWhenUnset() {
        XCTAssertEqual(manager.windowOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(manager.fontName, "system")
        XCTAssertEqual(manager.fontSize, 13.0, accuracy: 0.0001)
    }

    // MARK: - Persistence

    func testColorsRoundTripThroughUserDefaults() {
        let red = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let green = NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        let gray = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

        manager.searchTextColor = red
        manager.resultsTextColor = green
        manager.selectionHighlightColor = blue
        manager.windowBackgroundColor = gray

        // A fresh instance must read what the previous one wrote.
        let other = AppearanceManager()
        XCTAssertEqual(other.searchTextColor, red)
        XCTAssertEqual(other.resultsTextColor, green)
        XCTAssertEqual(other.selectionHighlightColor, blue)
        XCTAssertEqual(other.windowBackgroundColor, gray)
    }

    func testOpacityRoundTrip() {
        manager.windowOpacity = 0.85
        XCTAssertEqual(AppearanceManager().windowOpacity, 0.85, accuracy: 0.0001)
    }

    func testZeroOpacityIsStoredRatherThanTreatedAsUnset() {
        manager.windowOpacity = 0
        XCTAssertEqual(manager.windowOpacity, 0, accuracy: 0.0001)
    }

    func testFontNameAndSizeRoundTrip() {
        manager.fontName = "Menlo-Regular"
        manager.fontSize = 20

        let other = AppearanceManager()
        XCTAssertEqual(other.fontName, "Menlo-Regular")
        XCTAssertEqual(other.fontSize, 20, accuracy: 0.0001)
    }

    func testCorruptedColorDataFallsBackToDefault() {
        UserDefaults.standard.set(Data([0x00, 0x01, 0x02]),
                                  forKey: UserDefaults.AppearanceKeys.searchTextColor)
        XCTAssertEqual(manager.searchTextColor, NSColor.textColor)
    }

    func testWindowPositionDefaultsToTop() {
        XCTAssertEqual(manager.windowPosition, .top)
    }

    func testWindowPositionRoundTrip() {
        manager.windowPosition = .bottom
        XCTAssertEqual(AppearanceManager().windowPosition, .bottom)
    }

    func testUnknownWindowPositionFallsBackToDefault() {
        UserDefaults.standard.set("sideways", forKey: UserDefaults.AppearanceKeys.windowPosition)
        XCTAssertEqual(manager.windowPosition, .top)
    }

    // MARK: - currentFont

    func testCurrentFontUsesSystemFontByDefault() {
        manager.fontSize = 17
        let font = manager.currentFont
        XCTAssertEqual(font.fontName, NSFont.systemFont(ofSize: 17).fontName)
        XCTAssertEqual(font.pointSize, 17, accuracy: 0.0001)
    }

    func testCurrentFontUsesNamedFont() {
        manager.fontName = "Menlo-Regular"
        manager.fontSize = 15
        let font = manager.currentFont
        XCTAssertEqual(font.fontName, "Menlo-Regular")
        XCTAssertEqual(font.pointSize, 15, accuracy: 0.0001)
    }

    func testCurrentFontFallsBackToSystemFontForUnknownName() {
        manager.fontName = "NoSuchFont-DoesNotExist"
        manager.fontSize = 11
        let font = manager.currentFont
        XCTAssertEqual(font.fontName, NSFont.systemFont(ofSize: 11).fontName)
        XCTAssertEqual(font.pointSize, 11, accuracy: 0.0001)
    }

    // MARK: - Reset

    func testResetToDefaultsRestoresAllValues() {
        manager.searchTextColor = .red
        manager.resultsTextColor = .red
        manager.selectionHighlightColor = .red
        manager.windowBackgroundColor = .red
        manager.windowOpacity = 0.3
        manager.fontName = "Menlo-Regular"
        manager.fontSize = 30
        manager.windowPosition = .bottom

        manager.resetToDefaults()

        XCTAssertEqual(manager.searchTextColor, NSColor.textColor)
        XCTAssertEqual(manager.resultsTextColor, NSColor.textColor)
        XCTAssertEqual(manager.selectionHighlightColor, NSColor.selectedTextBackgroundColor)
        XCTAssertEqual(manager.windowBackgroundColor, NSColor.windowBackgroundColor)
        XCTAssertEqual(manager.windowOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(manager.fontName, "system")
        XCTAssertEqual(manager.fontSize, 13.0, accuracy: 0.0001)
        XCTAssertEqual(manager.windowPosition, .top)
    }

    // MARK: - Keys and notifications

    func testUserDefaultsKeysAreNamespacedAndUnique() {
        let keys = AppearanceDefaultsSnapshot.keys
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertTrue(keys.allSatisfy { $0.hasPrefix("appearance.") })
    }

    func testAppearanceSettingsChangedNotificationName() {
        XCTAssertEqual(Notification.Name.appearanceSettingsChanged.rawValue, "appearanceSettingsChanged")
    }
}
