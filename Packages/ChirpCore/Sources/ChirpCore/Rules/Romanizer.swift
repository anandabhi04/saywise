import Foundation

/// Turns Devanagari into plain Roman letters ("कल meeting है" -> "kal meeting hai").
/// The LLM does the nicer job. This is the safety net when cleanup is skipped or rejected.
public enum Romanizer {
    public static func containsDevanagari(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
    }

    public static func romanize(_ text: String) -> String {
        guard containsDevanagari(text) else { return text }
        let all = Array(text.unicodeScalars)
        var scalars = String.UnicodeScalarView()
        for (i, scalar) in all.enumerated() {
            scalars.append(scalar)
            let next = i + 1 < all.count ? all[i + 1].value : 0
            // ICU adds the inherent "a" to a word-final consonant ("कल" -> "kala").
            // Hindi drops it, so add a virama to silence it.
            if endsInConsonant(scalar.value) && !isDevanagariLetter(next) {
                scalars.append(Unicode.Scalar(0x094D)!)
            }
        }
        var out = String(scalars).replacingOccurrences(of: "\u{0964}", with: ".")
        out = out.applyingTransform(.toLatin, reverse: false) ?? out
        for (from, to) in [("m\u{0310}", "n"), ("ṁ", "n"), ("ṅ", "n"), ("ñ", "n")] {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out.applyingTransform(.stripDiacritics, reverse: false) ?? out
    }

    private static func endsInConsonant(_ v: UInt32) -> Bool {
        (0x0915...0x0939).contains(v) || (0x0958...0x095F).contains(v) || v == 0x093C
    }

    /// Devanagari letters and signs, but not the danda punctuation marks.
    private static func isDevanagariLetter(_ v: UInt32) -> Bool {
        (0x0900...0x0963).contains(v) || (0x0966...0x097F).contains(v)
    }
}
