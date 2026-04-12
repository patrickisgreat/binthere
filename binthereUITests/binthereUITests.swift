import XCTest

// swiftlint:disable:next type_name
final class binthereUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsAuthScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // App should show the auth gate — either "binthere" logo or "Sign In"
        let signInButton = app.buttons["Sign In"]
        let logo = app.staticTexts["binthere"]

        let authScreenAppeared = signInButton.waitForExistence(timeout: 10)
            || logo.waitForExistence(timeout: 5)

        XCTAssertTrue(authScreenAppeared, "Auth screen should appear on launch")
    }
}
