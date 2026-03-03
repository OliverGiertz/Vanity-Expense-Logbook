import XCTest

@MainActor
final class ScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var demoDataSeeded = false

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        registerSystemAlertHandler()
        setupSnapshot(app)              // kommt aus SnapshotHelper.swift
        app.launchArguments += ["-ui_testing"]
        app.launch()
    }

    func test_makeScreens() {
        handleOnboardingIfNeeded()
        seedDemoDataIfNeeded()

        captureOverviewScreen()
        captureEntryScreen()
        captureAnalysisScreen()
        captureMapScreen()
        captureProfileScreen()
    }

    // MARK: - Screenshot helpers

    private func snap(_ name: String) {
        snapshot(name, timeWaitingForIdle: 1)
    }

    private func captureOverviewScreen() {
        switchToTab(named: "Übersicht")
        XCTAssertTrue(app.navigationBars["Übersicht"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        snap("02-Uebersicht")
    }

    private func captureEntryScreen() {
        switchToTab(named: "Eintrag")
        XCTAssertTrue(app.navigationBars["Eintrag"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.3)
        snap("03-Eintrag")
    }

    private func captureAnalysisScreen() {
        switchToTab(named: "Auswertung")
        XCTAssertTrue(app.navigationBars["Auswertung"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0) // give Charts some time to render
        snap("04-Auswertung")
    }

    private func captureMapScreen() {
        switchToTab(named: "Karte")
        XCTAssertTrue(app.navigationBars["Karte"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0) // wait for annotations to appear
        snap("05-Karte")
    }

    private func captureProfileScreen() {
        switchToTab(named: "Profil")
        XCTAssertTrue(app.navigationBars["Profil"].waitForExistence(timeout: 5))
        fillProfileSection()
        dismissKeyboardIfNeeded()
        Thread.sleep(forTimeInterval: 0.3)
        snap("06-Profil")
    }

    // MARK: - Flow helpers

    private func handleOnboardingIfNeeded() {
        let continueButton = app.buttons["Weiter"]
        guard continueButton.waitForExistence(timeout: 5) else { return }

        snap("01-Start")

        let toggle = app.switches["Beim nächsten Start nicht anzeigen"]
        if toggle.exists, let value = toggle.value as? String, value == "0" {
            toggle.tap()
        }

        continueButton.tap()
    }

    private func seedDemoDataIfNeeded() {
        guard demoDataSeeded == false else { return }
        switchToTab(named: "Eintrag")
        XCTAssertNotNil(waitForEntryCard(named: "Tanken", timeout: 8), "Entry cards failed to load on Eintrag tab")

        createFuelEntry(currentKm: "53120", liters: "62", pricePerLiter: "1.89")
        createFuelEntry(currentKm: "53840", liters: "64", pricePerLiter: "1.92")
        createFuelEntry(currentKm: "54570", liters: "60", pricePerLiter: "1.95")

        createGasEntry(costPerBottle: "24.9", bottleCount: "2")
        createGasEntry(costPerBottle: "25.4", bottleCount: "1")

        createServiceEntry(cost: "9.5", freshWater: "85")

        demoDataSeeded = true
    }

    private func createFuelEntry(currentKm: String, liters: String, pricePerLiter: String) {
        openEntryCard(named: "Tanken")
        fillTextField("Aktueller KM Stand", with: currentKm)
        fillTextField("Getankte Liter", with: liters)
        fillTextField("Kosten pro Liter", with: pricePerLiter)
        pickManualLocation()
        saveForm()
        waitForEntryGrid()
    }

    private func createGasEntry(costPerBottle: String, bottleCount: String) {
        openEntryCard(named: "Gas")
        fillTextField("Kosten pro Flasche", with: costPerBottle)
        fillTextField("Anzahl Flaschen", with: bottleCount)
        pickManualLocation()
        saveForm()
        waitForEntryGrid()
    }

    private func createServiceEntry(cost: String, freshWater: String) {
        openEntryCard(named: "Ver- / Entsorgung")
        setSwitch("Versorgung", to: true)
        setSwitch("Entsorgung", to: true)
        fillTextField("Getankte Frischwasser (Liter)", with: freshWater)
        fillTextField("Kosten", with: cost)
        pickManualLocation()
        saveForm()
        waitForEntryGrid()
    }

    private func openEntryCard(named label: String) {
        switchToTab(named: "Eintrag")
        guard let card = waitForEntryCard(named: label, timeout: 6) else {
            XCTFail("Entry card \(label) not found")
            return
        }
        card.tap()
    }

    private func waitForEntryGrid() {
        XCTAssertNotNil(waitForEntryCard(named: "Tanken", timeout: 10), "Entry grid did not appear in time")
    }

    private func fillTextField(_ label: String, with text: String) {
        let field = app.textFields[label]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "TextField \(label) missing")
        field.tap()
        field.clearAndType(text)
    }

    private func setSwitch(_ label: String, to value: Bool) {
        let toggle = app.switches[label]
        guard toggle.waitForExistence(timeout: 5) else { return }
        guard let currentValue = toggle.value as? String else {
            toggle.tap()
            return
        }
        let isOn = currentValue == "1"
        if isOn != value {
            toggle.tap()
        }
    }

    private func pickManualLocation() {
        let button = app.buttons["Standort manuell auswählen"].firstMatch
        guard button.waitForExistence(timeout: 5) else { return }
        button.tap()

        let acceptButton = app.buttons["Übernehmen"]
        if acceptButton.waitForExistence(timeout: 5) {
            acceptButton.tap()
        } else if app.navigationBars.buttons["Übernehmen"].waitForExistence(timeout: 5) {
            app.navigationBars.buttons["Übernehmen"].tap()
        }
    }

    private func saveForm() {
        let saveButton = app.buttons["Speichern"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Speichern button not found")
        bringElementIntoView(saveButton)
        saveButton.tap()
    }

    private func fillProfileSection() {
        fillTextField("KFZ Kennzeichen", with: "RV CL 2025")
        fillTextField("Automarke", with: "Vanity Camper")
        fillTextField("Fahrzeugtyp", with: "Sprinter 4x4")
        fillTextField("Tankvolumen (Liter)", with: "80")
        let saveProfileButton = app.buttons["Profil speichern"]
        if saveProfileButton.waitForExistence(timeout: 2) {
            bringElementIntoView(saveProfileButton)
            saveProfileButton.tap()
        }
    }

    private func dismissKeyboardIfNeeded() {
        if app.keyboards.buttons["Fertig"].exists {
            app.keyboards.buttons["Fertig"].tap()
        } else if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else if app.keyboards.keys["Weiter"].exists {
            app.keyboards.keys["Weiter"].tap()
        } else if app.keyboards.keys["done"].exists {
            app.keyboards.keys["done"].tap()
        }
    }

    private func switchToTab(named title: String) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab \(title) not found")
        button.tap()
    }

    private func bringElementIntoView(_ element: XCUIElement) {
        guard !element.isHittable else { return }
        let scrollable = app.tables.firstMatch.exists ? app.tables.firstMatch : app.scrollViews.firstMatch
        guard scrollable.exists else { return }
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            scrollable.swipeUp()
            attempts += 1
        }
    }

    private func registerSystemAlertHandler() {
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let buttons = [
                "Allow While Using App",
                "Allow Once",
                "Allow",
                "OK",
                "Erlauben",
                "Beim Verwenden der App erlauben",
                "Einmal erlauben"
            ]
            for label in buttons {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - Query helpers

private extension ScreenshotsUITests {
    func waitForEntryCard(named label: String, timeout: TimeInterval) -> XCUIElement? {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", label)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: timeout) {
            return button
        }

        let staticText = app.staticTexts.matching(predicate).firstMatch
        if staticText.waitForExistence(timeout: 1) {
            return staticText
        }

        return nil
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let existing = value as? String, !existing.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            typeText(deleteString)
        }
        typeText(text)
    }
}
