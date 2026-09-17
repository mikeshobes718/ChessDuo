import XCTest

/// Walks through every screen and taps every primary control. Runs against the simulator.
final class ChessDuoUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System dialogs") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app = XCUIApplication()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "home"
        app.launch()
    }

    override func record(_ issue: XCTIssue) {
        // Save a screenshot next to the failure so it can be inspected without the result bundle.
        let shot = XCUIScreen.main.screenshot().pngRepresentation
        let safe = name.replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression)
        try? shot.write(to: URL(fileURLWithPath: "/tmp/chessduo-test/shots/fail-\(safe)-\(issue.sourceCodeContext.location?.lineNumber ?? 0).png"))
        super.record(issue)
    }

    // MARK: Helpers

    private func tapSquare(_ name: String, orientationWhite: Bool = true) {
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5), "board not found")
        let file = Int(name.unicodeScalars.first!.value - 97)
        let rank = Int(String(name.last!))! - 1
        let col = orientationWhite ? file : 7 - file
        let row = orientationWhite ? 7 - rank : rank
        let frame = board.frame
        let side = min(frame.width, frame.height)
        let originX = frame.midX - side / 2
        let originY = frame.midY - side / 2
        // The 2D board has a 6pt frame inset inside the container; the cell grid fills the rest.
        let inset: CGFloat = 8
        let cell = (side - inset * 2) / 8
        let x = originX + inset + (CGFloat(col) + 0.5) * cell
        let y = originY + inset + (CGFloat(row) + 0.5) * cell
        let dx = (x - frame.minX) / frame.width
        let dy = (y - frame.minY) / frame.height
        board.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
    }

    private func moveCount() -> Int {
        let strip = app.scrollViews["moveStrip"].firstMatch
        if !strip.exists { return -1 }
        return Int(strip.value as? String ?? "") ?? -1
    }

    private func waitForMoves(_ n: Int, timeout: TimeInterval = 15) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if moveCount() >= n { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTFail("expected \(n) moves, have \(moveCount())")
    }

    private func tapButton(_ label: String, timeout: TimeInterval = 5) {
        let b = app.buttons[label].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "button \(label) missing")
        // Menus and sheets animate in; give them a moment to become hittable.
        let deadline = Date().addingTimeInterval(3)
        while !b.isHittable && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        b.tap()
    }

    private func openGameMenu() {
        app.buttons["game.menu"].firstMatch.tap()
        sleep(1)
    }

    /// Taps a button inside the frontmost alert (avoids matching an identically labelled button behind it).
    private func tapAlert(_ label: String, timeout: TimeInterval = 5) {
        let b = app.alerts.buttons[label].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "alert button \(label) missing")
        b.tap()
    }

    private func waitForGameScreen(_ text: String) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10))
        // Let the full-screen cover finish animating before computing board coordinates.
        sleep(2)
    }

    // MARK: Tests

    func testHomeAndSetupScreens() {
        XCTAssertTrue(app.staticTexts["Play Online"].waitForExistence(timeout: 5))
        app.buttons["Pass & Play, Two players, one phone"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Pass & Play"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Play the Computer'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Play the Computer"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Master'")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Casual'")).firstMatch.tap()
        app.buttons["Random"].firstMatch.tap()
        app.buttons["3+2, Blitz"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Play Online"].waitForExistence(timeout: 5))
    }

    func testComputerGameFullFlow() {
        app.terminate()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "computer"
        app.launch()
        waitForGameScreen("Your turn")
        // Play 1. e4 and wait for the engine reply.
        tapSquare("e2"); tapSquare("e4")
        waitForMoves(2)
        // Hint, then play for me.
        app.buttons["action.lightbulb.fill"].firstMatch.tap()
        sleep(2)
        app.buttons["action.cpu"].firstMatch.tap()
        tapAlert("Play for me")
        waitForMoves(4)
        // Undo takes back both plies.
        app.buttons["action.arrow.uturn.backward"].firstMatch.tap()
        sleep(1)
        XCTAssertEqual(moveCount(), 2)
        // Step back through history and forward again.
        app.buttons["nav.back"].firstMatch.tap()
        app.buttons["nav.forward"].firstMatch.tap()
        // Menu: flip, eval, copy FEN, then the 3D board (slowest for accessibility queries, so last).
        openGameMenu()
        tapButton("Flip board")
        openGameMenu()
        tapButton("Eval")
        openGameMenu()
        tapButton("Copy FEN")
        // The SceneKit board is covered by the CHESSDUO_SCREEN=computer3d screenshot pass; XCUITest taps are
        // unreliable while a Metal view is animating, so the 3D toggle is not exercised here.
        // Offer draw (computer declines or accepts), then resign.
        app.buttons["action.equal.circle"].firstMatch.tap()
        tapAlert("Offer draw")
        sleep(1)
        if app.buttons["action.flag.fill"].firstMatch.isEnabled {
            app.buttons["action.flag.fill"].firstMatch.tap()
            tapAlert("Resign")
        }
        XCTAssertTrue(app.staticTexts["You lost"].waitForExistence(timeout: 5) || app.staticTexts["It's a draw"].waitForExistence(timeout: 2))
        // Share sheet opens and closes; review opens.
        tapButton("Done")
        sleep(1)
        app.buttons["action.arrow.counterclockwise"].firstMatch.tap()   // rematch
        XCTAssertTrue(app.staticTexts["Your turn"].waitForExistence(timeout: 10) || app.staticTexts["Thinking…"].waitForExistence(timeout: 2))
        app.buttons["game.close"].firstMatch.tap()
        tapAlert("Leave")
        XCTAssertTrue(app.staticTexts["Play Online"].waitForExistence(timeout: 5))
    }

    func testPassAndPlayCheckmateAndReview() {
        app.terminate()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "local"   // Ruy Lopez position, black to move
        app.launch()
        waitForGameScreen("Black to move")
        tapSquare("f8"); tapSquare("e7")
        waitForMoves(10)
        // Draw offer accepted -> game over sheet with review.
        app.buttons["action.equal.circle"].firstMatch.tap()
        tapAlert("Offer draw")
        tapButton("Accept draw")
        XCTAssertTrue(app.staticTexts["It's a draw"].waitForExistence(timeout: 8))
        tapButton("Review")
        XCTAssertTrue(app.navigationBars["Match review"].waitForExistence(timeout: 30))
        sleep(1)
        app.buttons["review.end"].firstMatch.tap()
        app.buttons["review.start"].firstMatch.tap()
        app.navigationBars["Match review"].buttons["Close"].firstMatch.tap()
        let deadline = Date().addingTimeInterval(5)
        while app.navigationBars["Match review"].exists && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertFalse(app.navigationBars["Match review"].exists, "review sheet did not close")
        // New game from the finished game.
        app.buttons["action.arrow.counterclockwise"].firstMatch.tap()
        waitForGameScreen("White to move")
        // Scholar's mate to test checkmate detection + promotion sheet not needed.
        for sq in ["e2","e4","e7","e5","f1","c4","b8","c6","d1","h5","g8","f6","h5","f7"] { tapSquare(sq) }
        XCTAssertTrue(app.staticTexts["Checkmate"].waitForExistence(timeout: 5) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'wins'")).firstMatch.waitForExistence(timeout: 5))
        tapButton("Done")
        app.buttons["game.close"].firstMatch.tap()
        tapAlert("Leave")
        // History should now list games.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Past Games'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Past Games"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No games yet. Your finished games appear here."].exists)
        app.buttons.matching(NSPredicate(format: "label CONTAINS ' vs '")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Share PGN"].waitForExistence(timeout: 5))
        app.buttons["replay.play"].firstMatch.tap()
        sleep(2)
        tapButton("Close")
    }

    func testPromotionSheet() {
        app.terminate()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "analysis"
        app.launch()
        XCTAssertTrue(app.navigationBars["Analysis"].waitForExistence(timeout: 5))
        // Enter edit mode, clear board, place a white pawn on e7 via palette.
        sleep(1)
        app.buttons["analysis.edit"].firstMatch.tap()
        app.buttons["analysis.menu"].firstMatch.tap()
        tapButton("Clear board")
        let palettePawn = app.buttons["palette.P"].firstMatch
        XCTAssertTrue(palettePawn.waitForExistence(timeout: 5))
        palettePawn.tap()
        tapSquare("b7")
        app.buttons["analysis.edit"].firstMatch.tap()   // leave edit mode
        sleep(1)
        tapSquare("b7"); tapSquare("b8")
        XCTAssertTrue(app.staticTexts["Promote to"].waitForExistence(timeout: 5))
        tapButton("promote.Q")
        sleep(1)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'b8=Q'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["analysis.undo"].firstMatch.tap()
        app.buttons["analysis.flip"].firstMatch.tap()
        app.buttons["analysis.3d"].firstMatch.tap()
        sleep(1)
        app.buttons["analysis.3d"].firstMatch.tap()
        app.buttons["analysis.menu"].firstMatch.tap()
        tapButton("Start position")
        tapButton("Play from here")
        XCTAssertTrue(app.staticTexts["Your turn"].waitForExistence(timeout: 8))
        app.buttons["game.close"].firstMatch.tap()
        tapAlert("Leave")
    }

    func testPuzzlesLearnSettings() {
        app.terminate()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "puzzles"
        app.launch()
        XCTAssertTrue(app.navigationBars["Puzzles"].waitForExistence(timeout: 5))
        tapButton("Hint")
        tapButton("Show solution")
        XCTAssertTrue(app.buttons["Next puzzle"].waitForExistence(timeout: 10))
        tapButton("Next puzzle")
        XCTAssertTrue(app.buttons["Show solution"].waitForExistence(timeout: 5))
        tapButton("Show solution")
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 10))
        tapButton("Retry")
        app.buttons["Theme"].firstMatch.tap()
        tapButton("Mate in one")
        tapButton("Random puzzle")
        app.buttons["puzzle.3d"].firstMatch.tap()
        sleep(1)
        app.buttons["puzzle.3d"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Learn'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        for name in ["learn.K", "learn.Q", "learn.R", "learn.B", "learn.P"] {
            app.buttons[name].firstMatch.tap()
        }
        tapSquare("b2")
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Castling'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Analysis"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.navigationBars.buttons["gearshape.fill"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        for theme in ["Ocean", "Neon", "Custom colours", "Walnut"] {
            let b = app.buttons[theme].firstMatch
            if b.exists { b.tap() }
        }
        app.buttons["Modern"].firstMatch.tap()
        app.buttons["Minimal"].firstMatch.tap()
        app.buttons["Classic"].firstMatch.tap()
        app.buttons["Dark"].firstMatch.tap()
        app.buttons["System"].firstMatch.tap()
        let s3d = app.switches["3D board, Start games in the 3D view"].firstMatch
        if s3d.exists { s3d.tap(); s3d.tap() }
        app.swipeUp(); app.swipeUp()
        let sounds = app.switches["Sounds"].firstMatch
        if sounds.exists { sounds.tap(); sounds.tap() }
        app.swipeUp()
        tapButton("Reset statistics")
        tapAlert("Reset")
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testOnlineLobbyCreateAndLeave() {
        app.terminate()
        app.launchEnvironment["CHESSDUO_SCREEN"] = "lobby"
        app.launch()
        XCTAssertTrue(app.navigationBars["Play Online"].waitForExistence(timeout: 5))
        tapButton("Join room")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))   // needs a code
        app.alerts.buttons["OK"].tap()
        tapButton("Create a room")
        // Either the waiting room appears (server reachable) or an error alert (offline); both are handled.
        sleep(3)
        app.tap()   // triggers the interruption monitor if the notification permission dialog is up
        let waiting = app.staticTexts["Waiting for your partner…"].waitForExistence(timeout: 40)
        if waiting {
            tapButton("Copy code")
            tapButton("Leave room")
            XCTAssertTrue(app.staticTexts["Play Online"].waitForExistence(timeout: 5))
        } else {
            let alert = app.alerts.firstMatch.waitForExistence(timeout: 3)
            XCTAssertTrue(alert, "neither waiting room nor error alert appeared")
            if alert { app.alerts.buttons["OK"].tap() }
            app.buttons["lobby.close"].firstMatch.tap()
        }
    }
}
