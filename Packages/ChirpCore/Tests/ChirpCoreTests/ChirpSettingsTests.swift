import Foundation
import Testing
@testable import ChirpCore

struct ChirpSettingsTests {
    @Test func defaultsMatchSpec() {
        let s = ChirpSettings()
        #expect(s.triggerKey == .fn)
        #expect(s.languageMode == .auto)
        #expect(s.speechEngine == .whisper)
        #expect(s.historyRetention == .days30)
        #expect(s.keepAudio == false)
        #expect(s.showFloatingButton == true)
        #expect(s.cleanupModelID == "mlx-community/Qwen3-4B-Instruct-2507-4bit")
    }

    @Test func roundTripsThroughJSON() throws {
        var s = ChirpSettings()
        s.dictionary = [DictionaryEntry(word: "UnifyApps", spokenForms: ["unify apps"])]
        s.snippets = [Snippet(trigger: "my email", expansion: "me@example.com")]
        s.appStyles = ["com.apple.mail": .chat]
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(ChirpSettings.self, from: data) == s)
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(ChirpSettings.self, from: Data(#"{"keepAudio": true}"#.utf8))
        var expected = ChirpSettings()
        expected.keepAudio = true
        #expect(decoded == expected)
    }

    @Test func floatingButtonSettingRoundTrips() throws {
        let decoded = try JSONDecoder().decode(ChirpSettings.self, from: Data(#"{"showFloatingButton": false}"#.utf8))
        #expect(decoded.showFloatingButton == false)
    }
}
