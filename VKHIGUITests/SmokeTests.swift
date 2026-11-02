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
    func testLargeTextScreens() {captureScreens(dark:false,large:true)}
    func testNativeServiceScreens() {
        let app=XCUIApplication();app.launchArguments=["--uitesting"];app.launch()
        app.buttons["Посмотреть демоверсию"].tap()
        app.tabBars.buttons["Сервисы"].tap()
        for destination in ["Сохранённое","Истории VK"] {
            app.buttons[destination].tap()
            let title=destination=="Истории VK" ? "Истории" : destination
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout:10))
            let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="service-"+destination;attachment.lifetime = .keepAlways;add(attachment)
            app.navigationBars.buttons.element(boundBy:0).tap()
        }
    }
    private func captureScreens(dark:Bool,large:Bool=false) {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", dark ? "--dark" : "--light"]+(large ? ["--large-type"] : [])
        app.launch()
        app.buttons["Посмотреть демоверсию"].tap()
        for tab in ["Сообщения","Лента","Сервисы","Музыка","Профиль"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout:10))
            app.tabBars.buttons[tab].tap()
            let attachment = XCTAttachment(screenshot:app.screenshot())
            attachment.name = "\(large ? "large" : dark ? "dark" : "light")-\(tab)"; attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
