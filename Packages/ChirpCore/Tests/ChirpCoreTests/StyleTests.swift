import Testing
@testable import ChirpCore

struct StyleTests {
    @Test func chatDropsPeriodOnSingleSentence() {
        #expect(StyleFinisher.finish("See you at 5.", style: .chat) == "See you at 5")
        #expect(StyleFinisher.finish("Done. See you at 5.", style: .chat) == "Done. See you at 5.")
        #expect(StyleFinisher.finish("See you at 5.", style: .email) == "See you at 5.")
    }

    @Test func codeLowercasesOnlyPlainFirstWord() {
        #expect(StyleFinisher.finish("Git status.", style: .code) == "git status")
        #expect(StyleFinisher.finish("README needs work", style: .code) == "README needs work")
        #expect(StyleFinisher.finish("iPhone build", style: .code) == "iPhone build")
    }

    @Test func resolvesBuiltInApps() {
        let s = ChirpSettings()
        #expect(StyleResolver.resolve(AppContext(bundleID: "com.tinyspeck.slackmacgap"), settings: s) == .chat)
        #expect(StyleResolver.resolve(AppContext(bundleID: "com.apple.mail"), settings: s) == .email)
        #expect(StyleResolver.resolve(AppContext(bundleID: "com.microsoft.VSCode"), settings: s) == .code)
        #expect(StyleResolver.resolve(AppContext(bundleID: "com.unknown.app"), settings: s) == .other)
        #expect(StyleResolver.resolve(AppContext(), settings: s) == .other)
    }

    @Test func browserUsesTitleRules() {
        let s = ChirpSettings()
        let gmail = AppContext(bundleID: "com.google.Chrome", windowTitle: "Inbox (3) - me@gmail.com - Gmail")
        #expect(StyleResolver.resolve(gmail, settings: s) == .email)
        let other = AppContext(bundleID: "com.apple.Safari", windowTitle: "Apple")
        #expect(StyleResolver.resolve(other, settings: s) == .other)
    }

    @Test func userOverrideWins() {
        var s = ChirpSettings()
        s.appStyles["com.tinyspeck.slackmacgap"] = .raw
        #expect(StyleResolver.resolve(AppContext(bundleID: "com.tinyspeck.slackmacgap"), settings: s) == .raw)
    }

    @Test func pasteDecision() {
        #expect(PasteDecision.shouldPaste(focusedRole: "AXTextArea"))
        #expect(PasteDecision.shouldPaste(focusedRole: "AXWebArea"))
        #expect(!PasteDecision.shouldPaste(focusedRole: "AXOutline"))
        #expect(!PasteDecision.shouldPaste(focusedRole: nil))
    }
}
