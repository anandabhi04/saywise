import Foundation

public enum StyleResolver {
    public static let browserBundleIDs: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser",
    ]

    public static let builtIn: [String: Style] = [
        "com.tinyspeck.slackmacgap": .chat,
        "net.whatsapp.WhatsApp": .chat,
        "com.apple.MobileSMS": .chat,
        "ru.keepcoder.Telegram": .chat,
        "com.hnc.Discord": .chat,
        "com.apple.mail": .email,
        "com.microsoft.Outlook": .email,
        "com.readdle.smartemail-Mac": .email,
        "com.microsoft.VSCode": .code,
        "com.todesktop.230313mzl4w4u92": .code,
        "com.apple.dt.Xcode": .code,
        "com.apple.Terminal": .code,
        "com.googlecode.iterm2": .code,
        "com.mitchellh.ghostty": .code,
        "dev.zed.Zed": .code,
        "com.apple.Notes": .document,
        "notion.id": .document,
        "com.apple.iWork.Pages": .document,
        "com.microsoft.Word": .document,
        "md.obsidian": .document,
    ]

    /// Order: the user's own app rule, then browser title rules, then built-in apps.
    public static func resolve(_ context: AppContext, settings: ChirpSettings) -> Style {
        guard let bundleID = context.bundleID else { return .other }
        if let style = settings.appStyles[bundleID] { return style }
        if browserBundleIDs.contains(bundleID), let title = context.windowTitle {
            if let rule = settings.titleRules.first(where: {
                !$0.contains.isEmpty && title.localizedCaseInsensitiveContains($0.contains)
            }) {
                return rule.style
            }
        }
        return builtIn[bundleID] ?? .other
    }
}
