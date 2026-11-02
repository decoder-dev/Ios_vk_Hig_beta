import XCTest

final class SmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testLaunchAndDemoNavigation() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["Войти через VK ID"].waitForExistence(timeout:10))
        app.buttons["Посмотреть демоверсию"].tap()
        XCTAssertTrue(app.tabBars.buttons["Сообщения"].waitForExistence(timeout:5))
        for tab in ["Лента","Сервисы","Музыка","Профиль","Сообщения"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }
    func testLightScreens() { captureScreens(dark:false) }
    func testDarkScreens() { captureScreens(dark:true) }
    private func captureScreens(dark:Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", dark ? "--dark" : "--light"]
        app.launch()
        app.buttons["Посмотреть демоверсию"].tap()
        for tab in ["Сообщения","Лента","Сервисы","Профиль"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout:10))
            app.tabBars.buttons[tab].tap()
            let attachment = XCTAttachment(screenshot:app.screenshot())
            attachment.name = "\(dark ? "dark" : "light")-\(tab)"; attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
