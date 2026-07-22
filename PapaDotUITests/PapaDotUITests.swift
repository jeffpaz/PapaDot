// PapaDotUITests/PapaDotUITests.swift
import XCTest
import CoreImage

final class PapaDotUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Task rows live in a ScrollView; later rows (e.g. "Sand") can start off-screen
    /// depending on device height, so scroll incrementally until the element is hittable.
    private func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    /// Average RGB of an element's actual rendered pixels (a real screen capture, not the
    /// accessibility tree). Needed because XCUIElement's accessibility traits (isSelected,
    /// value) reflect SwiftUI's *logical* view state and update even when the composited
    /// frame doesn't repaint — the exact split this app hit before: data updates instantly,
    /// pixels stay stale. Only a pixel-level check can tell the two apart.
    private func averageColor(of element: XCUIElement) -> (r: Double, g: Double, b: Double)? {
        guard let cgImage = element.screenshot().image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: nil).render(
            output, toBitmap: &bitmap, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(bitmap[0]), Double(bitmap[1]), Double(bitmap[2]))
    }

    // MARK: - Smoke test

    func testScoreScreenLoadsWithBothPlayers() {
        // SwiftUI's TabView.tabItem doesn't propagate .accessibilityIdentifier to the
        // underlying native tab bar button — only the label text reaches it — so tab
        // bar lookups match by label ("Score") rather than the "tab_Score" identifier
        // set on MainGameView's tabItem content.
        XCTAssertTrue(app.tabBars.buttons["Score"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alice"].exists)
        XCTAssertTrue(app.staticTexts["Bob"].exists)
        XCTAssertTrue(app.buttons["toggle_Alice_Fairway"].exists)
        XCTAssertTrue(app.buttons["toggle_Bob_Fairway"].exists)
    }

    // MARK: - Regression: toggle must update immediately, without navigating away

    func testTaskToggleUpdatesImmediatelyOnTap() {
        let toggle = app.buttons["toggle_Alice_Fairway"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertFalse(toggle.isSelected, "Fairway should start untoggled for Alice")

        scrollUntilHittable(toggle)
        guard let before = averageColor(of: toggle) else {
            return XCTFail("Could not capture toggle screenshot before tap")
        }

        toggle.tap()

        XCTAssertTrue(toggle.isSelected,
            "Toggle must reflect the new state immediately on tap, without navigating away and back")

        guard let after = averageColor(of: toggle) else {
            return XCTFail("Could not capture toggle screenshot after tap")
        }
        // Toggling on fills the circle green (Color.green.opacity(0.2) background + a green
        // checkmark glyph). This checks the composited pixels, not just the accessibility
        // tree — isSelected above reflects SwiftUI's logical view state and, empirically,
        // stayed accurate even when the pre-fix static .id() was reinstated and re-tested
        // (Simulator/iOS 26.5), so it alone can't distinguish fixed from broken here. This
        // pixel check is the stronger signal for an actual stale-repaint regression.
        XCTAssertGreaterThan(after.g - before.g, 10,
            "Circle must visibly repaint green on tap, not remain stuck showing its pre-tap appearance")
    }

    // MARK: - Repeatable stepper updates immediately

    func testStepperIncrementsImmediatelyOnTap() {
        let plusButton = app.buttons["stepper_plus_Alice_Sand"]
        let count = app.staticTexts["stepper_count_Alice_Sand"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "0")

        scrollUntilHittable(plusButton)
        plusButton.tap()

        XCTAssertEqual(count.label, "1",
            "Stepper count must update immediately on tap, without leaving the screen")
    }

    // MARK: - Cross-player isolation

    func testTogglingOnePlayerDoesNotAffectAnother() {
        let aliceToggle = app.buttons["toggle_Alice_Fairway"]
        let bobToggle = app.buttons["toggle_Bob_Fairway"]
        XCTAssertTrue(aliceToggle.waitForExistence(timeout: 5))
        XCTAssertFalse(aliceToggle.isSelected)
        XCTAssertFalse(bobToggle.isSelected)

        scrollUntilHittable(aliceToggle)
        aliceToggle.tap()

        XCTAssertTrue(aliceToggle.isSelected)
        XCTAssertFalse(bobToggle.isSelected,
            "Toggling Alice's task must not affect Bob's adjacent control")
    }

    // MARK: - Scorecard defaults to Dot Score

    func testScorecardDefaultsToDotScoreTab() {
        let scorecardTab = app.tabBars.buttons["Scorecard"]
        XCTAssertTrue(scorecardTab.waitForExistence(timeout: 5))
        scorecardTab.tap()

        let dotScoreTab = app.buttons["scoreTab_dotScore"]
        XCTAssertTrue(dotScoreTab.waitForExistence(timeout: 5))
        XCTAssertTrue(dotScoreTab.isSelected, "Dot Score should be the default sub-tab on Scorecard")
    }
}
