import Testing
@testable import ChirpCore

struct RomanizerTests {
    @Test(arguments: [
        ("कल meeting है, 5 बजे", "kal meeting hai, 5 baje"),
        ("नमस्ते", "namaste"),
        ("क्या हाल है?", "kya hal hai?"),
        ("मैं घर जा रहा हूँ", "main ghar ja raha hun"),
        ("कल, परसों", "kal, parason"),
        ("बात ख़त्म।", "bat khatm."),
    ])
    func romanizesDevanagari(input: String, expected: String) {
        #expect(Romanizer.romanize(input) == expected)
    }

    @Test func leavesRomanTextUntouched() {
        #expect(Romanizer.romanize("Café, déjà vu") == "Café, déjà vu")
    }

    @Test func detectsUrduScript() {
        #expect(Romanizer.containsArabicScript("کیا تم میری ہندی سمجھ سکتے ہو"))
        #expect(!Romanizer.containsArabicScript("kya tum meri hindi samajh sakte ho"))
        #expect(!Romanizer.containsArabicScript("क्या तुम"))
    }
}
