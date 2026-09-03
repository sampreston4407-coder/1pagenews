import XCTest
@testable import OnePageNews

final class ModelTests: XCTestCase {
    func testFixtureEditionDecodes() throws {
        let edition = try XCTUnwrap(EditionCache.bundled(in: Bundle(for: AppModel.self)))
        XCTAssertEqual(edition.stories.count, 7)
        XCTAssertTrue(edition.stories.allSatisfy { $0.topic == .general })
        XCTAssertFalse(edition.stories(for: .ai).isEmpty)
        XCTAssertEqual(edition.date, "2026-09-03")
        XCTAssertNotNil(edition.day)
    }

    func testDatesWithAndWithoutFractionalSeconds() throws {
        let json = #"["2026-09-03T11:00:00Z", "2026-09-03T11:00:00.123456Z"]"#.data(using: .utf8)!
        let dates = try JSONDecoder.onePage().decode([Date].self, from: json)
        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), 0.123456, accuracy: 0.001)
    }

    func testOneLineStopsAtFirstSentence() throws {
        let edition = try XCTUnwrap(EditionCache.bundled(in: Bundle(for: AppModel.self)))
        let fed = try XCTUnwrap(edition.stories.first { $0.id.hasSuffix("fed-hold") })
        XCTAssertEqual(fed.oneLine, "The Fed left rates at 4.25 percent Wednesday.")
        let budget = try XCTUnwrap(edition.stories.first { $0.id.hasSuffix("budget") })
        XCTAssertEqual(budget.oneLine, "Negotiators walked out Wednesday with no deal.")
    }

    func testRoundTripEncoding() throws {
        let edition = try XCTUnwrap(EditionCache.bundled(in: Bundle(for: AppModel.self)))
        let data = try JSONEncoder.onePage().encode(edition)
        let again = try JSONDecoder.onePage().decode(Edition.self, from: data)
        XCTAssertEqual(again, edition)
    }
}

final class PreferencesTests: XCTestCase {
    private func fresh() -> (Preferences, UserDefaults) {
        let suite = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        return (Preferences(defaults: suite), suite)
    }

    func testGeneralIsAlwaysOnAndNeverStored() {
        let (prefs, _) = fresh()
        XCTAssertTrue(prefs.isOn(.general))
        prefs.set(.general, on: false)
        XCTAssertTrue(prefs.isOn(.general))
        XCTAssertFalse(prefs.selectedTopics.contains(.general))
    }

    func testTopicsPersist() {
        let (prefs, suite) = fresh()
        prefs.set(.ai, on: true)
        prefs.set(.finance, on: true)
        prefs.set(.ai, on: false)
        XCTAssertEqual(Preferences(defaults: suite).selectedTopics, [.finance])
    }

    func testNotificationTimeRoundTrips() {
        let (prefs, _) = fresh()
        prefs.notificationMinutes = 6 * 60 + 45
        let parts = Calendar.current.dateComponents([.hour, .minute], from: prefs.notificationTime)
        XCTAssertEqual(parts.hour, 6)
        XCTAssertEqual(parts.minute, 45)
    }

    func testServerURLValidation() {
        let (prefs, _) = fresh()
        XCTAssertNotNil(prefs.serverURL)
        prefs.serverURLString = "not a url"
        XCTAssertNil(prefs.serverURL)
        prefs.serverURLString = "ftp://example.org"
        XCTAssertNil(prefs.serverURL)
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    struct Failing: EditionProvider {
        func fetchEdition(topics: [Topic]) async throws -> Edition { throw URLError(.notConnectedToInternet) }
        func fetchMethodology() async throws -> Methodology { throw URLError(.notConnectedToInternet) }
        func fetchSources() async throws -> [SourceInfo] { throw URLError(.notConnectedToInternet) }
        func fetchCorrections() async throws -> [Correction] { throw URLError(.notConnectedToInternet) }
    }

    func testFallsBackToBundledEditionWhenNetworkFails() async {
        let suite = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: suite)
        let model = AppModel(preferences: prefs, bundled: BundledEditionProvider(bundle: Bundle(for: AppModel.self)), makeRemote: { _ in Failing() })
        await model.refresh()
        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(model.seven.count, 7)
    }

    func testTopicSectionsFollowPreferences() async {
        let suite = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: suite)
        prefs.serverURLString = ""
        prefs.set(.science, on: true)
        let model = AppModel(preferences: prefs, bundled: BundledEditionProvider(bundle: Bundle(for: AppModel.self)))
        await model.refresh()
        XCTAssertEqual(model.topicSections.map(\.topic), [.science])
    }
}
