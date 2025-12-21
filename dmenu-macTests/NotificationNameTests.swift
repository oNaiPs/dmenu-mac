import XCTest
@testable import dmenu_mac

final class NotificationNameTests: XCTestCase {
    func testThemeChangeNotificationNameMatchesSystemKey() {
        XCTAssertEqual(
            Notification.Name.AppleInterfaceThemeChangedNotification.rawValue,
            "AppleInterfaceThemeChangedNotification"
        )
    }
}
