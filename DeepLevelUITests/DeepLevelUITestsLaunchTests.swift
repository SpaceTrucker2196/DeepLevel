//
//  DeepLevelUITestsLaunchTests.swift
//  DeepLevelUITests
//
//  Created by Jeffrey Kunzelman on 8/21/25.
//

import XCTest

/// Launch-specific UI tests for the DeepLevel application.
///
/// Specialized test class focusing on application launch behavior
/// across different device configurations and orientations. Captures
/// launch screenshots for visual regression testing.
///
/// - Since: 1.0.0
final class DeepLevelUITestsLaunchTests: XCTestCase {

    /// Indicates whether tests should run for each target application UI configuration.
    ///
    /// - Returns: Always `true` to ensure comprehensive testing across configurations
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// Sets up test environment before launch test execution.
    ///
    /// Configures test behavior to continue after failures for comprehensive
    /// screenshot capture across different launch scenarios.
    ///
    /// - Throws: Setup errors if test environment cannot be configured
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Tests application launch and captures launch screen screenshot.
    ///
    /// Launches the application and captures a screenshot of the launch
    /// screen for visual verification and regression testing across
    /// different device configurations.
    ///
    /// - Throws: Test failures if application launch fails or screenshot capture fails
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
