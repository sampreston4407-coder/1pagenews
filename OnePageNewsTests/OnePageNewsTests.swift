import XCTest
@testable import OnePageNews

/// Placeholder so the test target builds. Real tests come with the build phase.
final class OnePageNewsTests: XCTestCase {
    func testSampleBriefingIsBundled() {
        XCTAssertNotNil(Bundle(for: AppModel.self).url(forResource: "SampleBriefing", withExtension: "json"))
    }
}
