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

    func testMusicPlayerQueueLyricsAndEqualizer() {
        captureMusic(large:false)
    }
    func testMusicPlayerLargeText() {
        captureMusic(large:true)
    }
    private func captureMusic(large:Bool) {
        let app=XCUIApplication()
        app.launchArguments=["--uitesting","--music-fixture","--light"]+(large ? ["--large-type"] : [])
        app.launch()
        app.buttons["Посмотреть демоверсию"].tap()
        app.tabBars.buttons["Музыка"].tap()
        let playlist=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@", "В дороге")).firstMatch
        for _ in 0..<6 {if playlist.exists && playlist.isHittable {break};app.swipeUp()}
        XCTAssertTrue(playlist.waitForExistence(timeout:10))
        capture(app,"music-library",large:large)
        playlist.tap()
        XCTAssertTrue(app.buttons["Добавить треки"].waitForExistence(timeout:5))
        capture(app,"music-playlist",large:large)
        app.navigationBars.buttons.element(boundBy:0).tap()
        // The global mini-player has one stable accessibility label.
        app.buttons["music-mini-player-open"].tap()
        XCTAssertTrue(app.navigationBars["Плеер"].waitForExistence(timeout:5))
        capture(app,"music-player",large:large)
        app.swipeUp()
        for destination in ["Очередь","Текст","Эквалайзер"] {
            let link=app.buttons[destination].firstMatch
            if !link.isHittable {app.swipeUp()}
            XCTAssertTrue(link.waitForExistence(timeout:5));link.tap()
            if destination=="Очередь" {
                XCTAssertTrue(app.staticTexts["Тихая дорога"].waitForExistence(timeout:5))
            } else if destination=="Текст" {
                XCTAssertTrue(app.buttons["Тихая тестовая запись"].waitForExistence(timeout:5))
                app.buttons["Проверка строки и перемотки"].tap()
            } else {
                let equalizer=app.switches["Эквалайзер"]
                XCTAssertTrue(equalizer.waitForExistence(timeout:5))
                equalizer.tap()
                XCTAssertEqual(equalizer.value as? String,"1")
            }
            capture(app,"music-"+destination,large:large)
            app.navigationBars.buttons.element(boundBy:0).tap()
            if !app.buttons["Очередь"].firstMatch.isHittable {app.swipeUp()}
        }
    }
    private func capture(_ app:XCUIApplication,_ name:String,large:Bool) {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=(large ? "large-" : "")+name
        attachment.lifetime = .keepAlways;add(attachment)
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
