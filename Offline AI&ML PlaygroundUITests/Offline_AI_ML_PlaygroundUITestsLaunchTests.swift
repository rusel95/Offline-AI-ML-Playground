//
//  Offline_AI_ML_PlaygroundUITestsLaunchTests.swift
//  Offline AI&ML PlaygroundUITests
//
//  Created by Ruslan Popesku on 03.07.2025.
//

import XCTest

final class Offline_AI_ML_PlaygroundUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
