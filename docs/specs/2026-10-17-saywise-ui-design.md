# Saywise UI design

Date: 2026-10-17
Status: approved in chat, waiting for review of this file
Replaces: `docs/design/saywise-ui.md` (the earlier "quiet" proposal). Where the two differ, this file wins.
Implementer: Codex CLI, model `gpt-6.1-sol`, one plan step at a time.

## 1. Goal

Make Saywise look and feel like a premium Mac app. Native, refined. It follows system light and dark. Premium comes from space, type and motion, not from color.

Three things change:

1. The four windows (main, settings, history, and the old main window content) become one window with a sidebar. The first page is Home, a dashboard.
2. The floating button and the pill become one floating bar.
3. First run becomes one step per page.

Nothing in the dictation pipeline, storage or engines changes, except one new read-only stats query.

## 2. Decisions

| Topic | Decision |
|---|---|
| Look | Native, refined. System materials, system colors, SF Pro. Follows light and dark. |
| App shape | One window with a sidebar. Home, History, Dictionary, Snippets, App styles, Settings. |
| Home | Stats and recent, with the record control. |
| Floating bar | One dark glass capsule, in both light and dark mode. |
| Setup | Separate small window, one step per page. Shows only when something is missing. |
| Stats storage | None. All numbers are computed from the existing history table. |
| Libraries | None added. SwiftUI, AppKit, Swift Charts (system framework) for the activity chart. macOS 15. |

## 3. The look

| Element | Value |
|---|---|
| Window | 980 × 640 pt. Min 820 × 560. Resizable. Hidden title, full-size content view, transparent title bar. Traffic lights float over the sidebar. |
| Sidebar | `NavigationSplitView` sidebar, 220 pt, not collapsible below 180. Sidebar material. Items: Home `house`, History `clock.arrow.circlepath`, Dictionary `character.book.closed`, Snippets `text.badge.plus`, App styles `app.badge`, Settings `gearshape`. Bottom of the sidebar: status row (status dot, status text, key hint in caption). |
| Content | Standard window background. Content column max 760 pt wide, centered. Padding 32 pt. Page title `.largeTitle` bold at the top, one help line under it in `.callout` `.secondary` where a page needs it. |
| Cards | `RoundedRectangle(cornerRadius: 16)`. Fill `Color(nsColor: .controlBackgroundColor)`. Stroke `.separator` 0.5 pt. No shadow. Inner padding 20 pt. |
| Type | SF Pro. Page title `.largeTitle` bold. Section title `.headline`. Big stat number 34 pt, rounded design, semibold, monospaced digits. Body `.body`. Caption `.caption` `.secondary`. |
| Color | Accent: system accent. Live: system red. Good: system green. Warning: system orange. Nothing else. |
| Motion | Stat numbers count from 0 to value over 0.6 s on first appear, ease out. Cards fade in with a 40 ms stagger on first appear. Page switch: crossfade 0.2 s. Live wave: see § 6. No other decoration motion. |
| Copy | Short. No sentence the user does not need right now. Status is a dot and one or two words. |

## 4. Home

Top to bottom, inside the content column, 20 pt between blocks.

### 4.1 Header

- Greeting from the clock: "Good morning", "Good afternoon", "Good evening". `.largeTitle` bold. No name.
- Under it: status dot + status text + " · " + hint. `.callout`. Example: "Ready · Hold Fn in any app". The key name comes from settings.
- Right side, same row as the greeting: the mic switch (`Toggle`, `.switch`). Disabled unless status is ready or paused.

### 4.2 Banner slot

Only when something is wrong. One banner, never two. Sits between the header and the Talk card.

| Case | Text | Button |
|---|---|---|
| Models failed | Saywise could not load its models. | Try again |
| Microphone missing | Saywise needs the microphone to hear you. | Allow |
| Accessibility missing | Saywise needs Accessibility to paste into other apps. | Allow |
| Input Monitoring missing | Saywise needs Input Monitoring to notice the Fn key. | Allow |

Style: `RoundedRectangle(cornerRadius: 12)`, fill `.orange.opacity(0.12)`, `exclamationmark.circle.fill` orange, text `.callout`, button `.bordered` small. "Allow" asks the system; if it cannot ask again it opens System Settings. "Try again" reloads models.

### 4.3 Talk card

Full width, 120 pt tall. Three parts in an `HStack`, 20 pt gaps.

| Part | Content |
|---|---|
| Record button | 64 pt circle. Idle: fill `.primary`, glyph `mic.fill` 24 pt semibold in the window background color. Hover: scale 1.04, 120 ms. Pressed: 0.96. Recording: fill red, glyph `stop.fill`, a red ring at 0.25 opacity breathes behind it, scale 1.0 to 1.18, 1.2 s, repeating. Working: fill `.primary` at 0.6, small white `ProgressView`, not clickable. Disabled (mic off, loading, failed): fill `.quaternary`, glyph `.tertiary`, not clickable. |
| Middle | Idle: "Press to talk" `.body` `.secondary`. Recording: the `WaveView` (§ 6.4), 24 bars, height 24 pt. Working: "Finishing…". Mic off: "Turn the mic on to talk". Loading: "Getting ready…" and a thin progress bar with "1.6 GB of 4.1 GB" (percent when bytes are unknown). |
| Last text | Takes the remaining width. Title "Last dictation" `.caption`. Under it the last `finalText`, two lines, `.body`. Under it `.caption` `.secondary`: app name · relative time. On hover a borderless Copy icon at the top right. Clicking the text opens History with that entry expanded. When there is no history: "Your words will show up here." |

A recording started from this button behaves like a hotkey recording in every way except one: the text is not pasted. It is saved to history and shown in "Last text", and copied to the clipboard. The bar (§ 6) shows the same states as for a hotkey recording.

### 4.4 Stats row

Four equal cards in an `HStack`, 16 pt gap. Each card: label `.caption` `.secondary`, number 34 pt rounded semibold monospaced, one line `.caption` `.secondary` under it.

| Card | Number | Line under |
|---|---|---|
| Words today | words dictated today | "+18% vs yesterday", "−5% vs yesterday", or "Same as yesterday". When yesterday is 0: "First words today". |
| Time saved | minutes this week, "26 min". Over 60: "1 h 12 min". | "this week" |
| Dictations | count this week | "this week" |
| Streak | days, "6 days" | "best 14" |

Time saved per entry: `max(0, words / 40 * 60 - audioSeconds)` seconds. 40 words per minute is the typing speed we assume.

### 4.5 Activity card

Title "Last 14 days" `.headline`. A Swift Charts `BarMark` chart, 140 pt tall. One bar per day, words. Bars in accent at 0.5 opacity, today at 1.0. X axis: weekday initials, Y axis hidden. Hover: a small callout with the day and the word count. When every day is 0: bars at 0 and a centered caption "Start talking to see your numbers".

### 4.6 Two half cards

`HStack`, 16 pt gap, equal widths.

**Top apps.** Title `.headline`. Up to 5 rows. Each row: app icon 20 pt (from `NSWorkspace` by bundle id, generic app icon when unknown), app name `.body`, word count `.callout` `.secondary` monospaced, and a 3 pt thin bar under the row scaled to the top app. Empty: "No apps yet."

**Recent.** Title `.headline`, right side a "See all" `.link` button to History. Up to 5 rows. Each row: `finalText` one line, under it `.caption`: app · relative time. Copy icon on hover. Click opens History with that entry expanded. Empty: "Nothing yet."

### 4.7 Window states

| State | Dot | Text | Hint | Button | Extra |
|---|---|---|---|---|---|
| Ready | green | Ready | Hold Fn in any app | idle | |
| Recording | red, pulsing | Listening | | recording | wave in the Talk card |
| Working | grey | Finishing | | working | |
| Mic off | grey | Mic is off | | disabled | switch off |
| Loading | grey | Getting ready | progress text | disabled | progress in the Talk card |
| Failed | orange | Needs attention | | disabled | banner |
| Permission missing | orange | Needs attention | | idle or disabled | banner |

The dot pulse: opacity 1.0 to 0.4, 1 s, repeating, only while recording.

## 5. The other pages

### 5.1 History

- Title "History". Top right: a search field (240 pt) and a `Menu` with "Clear all…".
- Rows grouped by day with section headers: Today, Yesterday, then "Mon 13 Oct" style.
- Row: `finalText` two lines `.body`; under it `.caption` `.secondary`: app · time · "12 s". Copy icon on hover. Context menu: Copy, Delete.
- Click a row: it expands in place with a 0.25 s spring. Expanded content: two boxes side by side, "Heard" (`rawText`) and "Written" (`finalText`), each with a Copy icon, `.quaternary` fill, radius 10. Under the boxes one caption line: "Style · Language · Cleanup · Paste outcome · speech 420 ms · cleanup 610 ms · paste 30 ms". Click again to collapse. Only one row expanded at a time.
- Opened from Home with an entry id: that row is expanded and scrolled into view.
- Empty: `waveform` symbol 40 pt `.tertiary`, "Your dictations will show up here." `.body` `.secondary`, centered.
- "Clear all…" shows the confirmation "Delete all history? This cannot be undone."

### 5.2 Dictionary, Snippets, App styles

The current `Form` content moves inside the new content column under the page title. One help line under the title, taken from the existing text in each tab. The forms keep `.formStyle(.grouped)`. No logic change.

### 5.3 Settings

One page, one grouped `Form`, sections in this order.

| Section | Rows |
|---|---|
| Talk | Talk key (picker, renamed from "Dictation key"). Show floating bar (toggle). Play sounds (toggle). |
| Language | Language (picker). Speech engine (picker). The Hinglish help line stays. |
| Models | Status row: green `checkmark.circle.fill` + "Ready", or a progress bar with the progress text, or orange `exclamationmark.circle.fill` + "Could not load" + "Try again". Cleanup model id field with Apply and Use default. Downloaded list with sizes. Show in Finder, Download again. |
| History | Keep history (picker). Delete all history (button, confirmation). |
| General | Start at login (toggle). Settings error line in orange when present. |

The `TabView` goes away. `settingsError` shows under the section it belongs to.

### 5.4 Menu bar menu

| Item | Shortcut |
|---|---|
| Status line: "Ready", "Listening", "Finishing", "Paused", "Getting ready", "Needs attention" | |
| Open Saywise | ⌘O |
| History | |
| Settings… | ⌘, |
| Pause Saywise / Resume Saywise | |
| Finish setup… (only when setup is needed) | |
| Quit Saywise | ⌘Q |

"History" and "Settings…" open the main window on that page.

## 6. The floating bar

The bar replaces both `FloatingButton` and `Pill`. It is the one place the live wave lives.

### 6.1 Shape, place, material

| Property | Value |
|---|---|
| Shape | Capsule, 34 pt tall. Width changes with state. |
| Default place | Bottom center of the main screen, 20 pt above the visible frame bottom. |
| Drag | Press and move more than 4 pt anywhere on the bar. Position saved in settings. Kept 12 pt inside the screen. If the saved place is off every screen, back to default. |
| Panel | `NSPanel`, `styleMask: [.nonactivatingPanel, .borderless]`, `canBecomeKey` and `canBecomeMain` return false. Level `.statusBar`. Collection behavior: all Spaces, full-screen auxiliary, stationary. Not in the window menu. |
| Material | `NSVisualEffectView`, `.hudWindow`, `.behindWindow`, `appearance = NSAppearance(named: .darkAqua)` set on the panel, not the app. Over it black at 0.3. Inner stroke white 0.12, 0.5 pt. |
| Shadow | Black 0.3, radius 16, y 6. |
| Text | 13 pt medium, white, monospaced digits. |

Dark in both modes on purpose. It floats over other windows and must read as an overlay.

### 6.2 States

| State | Width | Content | Click |
|---|---|---|---|
| Idle | 52 | `mic.fill` 14 pt, white 0.85 | Start recording |
| Hover | 52 | Tint 0.3 → 0.42, stroke 0.12 → 0.2, scale 1.03. Tooltip after 0.8 s: "Talk · drag to move". | |
| Listening | 184 | Red dot 8 pt at left, pulsing. `WaveView` 20 bars in the center, white. After 1 s an "esc" cap at the right, 11 pt, white 0.5. | Stop recording |
| Hands-free | 184 | Same, but the dot is `lock.fill` 10 pt red, no pulse. | Stop recording |
| Finishing | fits | Small white spinner + "Finishing" | nothing |
| Pasted | 52 | A green `checkmark` replaces the mic for 0.4 s, then idle. No text. | |
| Copied | fits | `doc.on.clipboard` + "Copied · ⌘V to paste", 3 s, then idle | Dismiss |
| Mic off | 52 | `mic.slash.fill` white 0.5, bar opacity 0.7 | Turn mic on. Shows "Mic on" 1.5 s, then idle. |
| Loading | 52 | Small spinner white 0.7 | Shows "Getting ready · 1.6 GB of 4.1 GB" for 2 s |
| Error | fits | Orange `exclamationmark.circle.fill` + short message, 3 s, then idle | Dismiss |
| Hidden | | Setting "Show floating bar" off | |

Esc while listening cancels, as today.

### 6.3 Motion

- Width: `.spring(response: 0.35, dampingFraction: 0.8)`. The center stays fixed. The panel frame is set from the content's `fittingSize` around the saved center, with `animate: false`; SwiftUI animates the content.
- Content crossfade: `.easeOut(duration: 0.15)`.
- Red dot: opacity 1.0 → 0.4, 1 s, repeating.
- Hover: 120 ms ease-out.

### 6.4 WaveView

Shared by the bar and the Talk card. Input: `[Float]` levels from the recorder. Bars: count, width 2.5 pt (bar) or 3 pt (card), gap 2 pt, min height 4 pt, max 18 pt (bar) or 24 pt (card). Height = min + min(1, level × 12) × (max − min). Capsule shape. `.easeOut(duration: 0.08)` on level change. Color is given by the parent.

## 7. First run

Separate window, 480 × 420 pt, hidden title, not resizable. One step per page, a row of dots at the bottom. Steps slide with `.spring(response: 0.4, dampingFraction: 0.85)`.

Each step: SF Symbol 44 pt in accent, title `.title2` semibold, one line `.body` `.secondary`, one primary button.

| # | Symbol | Title | Line | Button | Then |
|---|---|---|---|---|---|
| 1 | `waveform` | Welcome to Saywise | Hold Fn, speak, let go. Your words appear where you type. English, Hindi, or both. Everything stays on this Mac. | Continue | step 2 |
| 2 | `mic.fill` | Microphone | So Saywise can hear you. | Allow | System asks. On yes, green check 0.6 s, moves on. |
| 3 | `keyboard` | Input Monitoring | So Saywise notices when you hold Fn. | Allow | Opens System Settings. Polls once a second. Moves on when granted. |
| 4 | `accessibility` | Accessibility | So Saywise can paste into other apps. | Allow | Same as 3. |
| 5 | `globe` | One setting for Fn | By default Fn opens the emoji picker. Set "Press 🌐 key to" to "Do Nothing". | Open Keyboard Settings | Secondary link "Done, continue". |
| 6 | `arrow.down.circle` | Downloading models | About 4 GB, once. After this, Saywise never uses the network. | | Progress bar with the progress text. Moves on when loaded. |
| 7 | `checkmark.circle.fill` green | You're set | Hold Fn in any app and start talking. | Open Saywise | Closes setup, opens the main window. |

Rules: steps already done are skipped. If Input Monitoring needs a restart, step 3 shows "Saywise needs a quick restart to use this." and the button becomes "Restart Saywise". A download error shows "The download stopped." with "Try again" and a small "Details" link. Skip step 5 when the talk key is not Fn. Esc does nothing. The close button closes setup; it opens again on next launch if anything is missing.

## 8. Data: HistoryStats

New in `ChirpCore`, `Storage/HistoryStats.swift`. Pure computation over `[HistoryEntry]` plus one `HistoryStore` method that loads the last 14 days and the week.

```swift
public struct HistoryStats: Equatable, Sendable {
    public struct Day: Equatable, Sendable { public var date: Date; public var words: Int }
    public struct AppWords: Equatable, Sendable { public var bundleID: String?; public var name: String; public var words: Int }

    public var wordsToday: Int
    public var wordsYesterday: Int
    public var wordsThisWeek: Int
    public var dictationsThisWeek: Int
    public var secondsSavedThisWeek: Double
    public var streakDays: Int
    public var bestStreakDays: Int
    public var last14Days: [Day]          // oldest first, always 14 items
    public var topApps: [AppWords]        // this week, most words first, max 5

    public static func compute(entries: [HistoryEntry], now: Date, calendar: Calendar) -> HistoryStats
}
```

- Words: split `finalText` on whitespace and newlines, drop empty parts.
- "This week": the calendar week that contains `now`.
- Streak: consecutive calendar days ending today (or yesterday, if today has nothing yet) with at least one entry. Best streak: longest run in the entries given.
- `compute` takes `now` and `calendar` so tests use fixed dates.
- `HistoryStore.stats(now:calendar:)` loads entries from the start of the earliest of (14 days ago, start of this week, 60 days ago for the streak) and calls `compute`. History retention of 7 days limits the streak; that is accepted.

Tests in `HistoryStatsTests.swift`: empty input, one day, week boundary, streak with a gap, streak that ends yesterday, time saved never negative, top apps order and limit, 14 days always filled.

## 9. Code map

| File | Change |
|---|---|
| `App/UI/WindowCoordinator.swift` | `showMain(page:)` opens one window with `RootView`. `showHistory()` and `showSettings()` call it with a page. Window 980 × 640, min 820 × 560, hidden title, full-size content. Setup window 480 × 420, not resizable. |
| `App/UI/RootView.swift` (new) | `NavigationSplitView` with `Sidebar` and a `switch` on `Page`. Holds `@State page` and `historyFocus: HistoryEntry.ID?`. |
| `App/UI/Sidebar.swift` (new) | Items and the bottom status row. |
| `App/UI/Home/HomeView.swift` (new) | Header, banner slot, Talk card, stats row, activity, two half cards. Reads `HistoryStats` through `HomeModel`. |
| `App/UI/Home/HomeModel.swift` (new) | `@Observable`. Loads stats and recent on appear and on `historyRevision`. Greeting from the clock. Derived state for the Talk card (idle, recording, working, off, loading). |
| `App/UI/Home/TalkCard.swift`, `StatCard.swift`, `ActivityChart.swift`, `TopAppsCard.swift`, `RecentCard.swift` (new) | One view each. |
| `App/UI/Components/WaveView.swift`, `StatusDot.swift`, `RecordButton.swift`, `Card.swift`, `Banner.swift` (new) | Shared pieces. |
| `App/UI/HistoryView.swift` | Rewrite per § 5.1. Takes `focus: Binding<HistoryEntry.ID?>`. |
| `App/UI/Settings/SettingsView.swift` | Becomes one grouped form per § 5.3. `ModelStatusView` shows the check / progress / error row. |
| `App/UI/Settings/ListTabs.swift` | Wrap each in the page column with title and help line. Rename to `ListPages.swift`. |
| `App/UI/MainView.swift` | Deleted. |
| `App/UI/FloatingButton.swift`, `App/UI/Pill.swift` | Replaced by `App/UI/FloatingBar.swift` and `App/UI/FloatingBarPanel.swift`. Keep the click-vs-drag host view and the non-activating panel. `PillModel` becomes `BarModel` with `phase` and `levels`. |
| `App/UI/SetupView.swift` | Rewrite as `OnboardingView` with `StepPage`, per § 7. |
| `App/UI/MenuContent.swift` | Items per § 5.4. |
| `App/AppController.swift` | `pill` → `bar`. Recording from the window shows the bar too. Window source: save, copy, no paste. New `statusHint`, `modelProgressText`, short `statusText`. `finish` outcomes map to bar states. |
| `App/System/Permissions.swift` | `reason` strings from § 7. |
| `Packages/ChirpCore/.../Storage/HistoryStats.swift` + tests | § 8. |
| `Packages/ChirpCore/.../Models/ChirpSettings.swift` | `floatingBarPosition` if not already stored. Rename of `showFloatingButton` is not required; keep the key, change the label. |

## 10. Things to check while building

- The bar's width change must not re-create the panel. Set the frame around the saved center with `animate: false` and let SwiftUI animate the content. If it flickers, animate the frame with `NSAnimationContext` at 0.25 s instead.
- `TextEditor` is no longer used on Home. The Talk card shows text, not an editor.
- Hidden-title window with a sidebar: traffic lights sit over the sidebar. Use `.toolbar(removing: .sidebarToggle)` if the toggle looks wrong, or keep it.
- Swift Charts hover: `chartOverlay` with a `GeometryReader` and `onContinuousHover`.
- App icons: `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` then `NSWorkspace.shared.icon(forFile:)`. Cache per bundle id.
- Count-up animation: animate a `Double` with `.animation(.easeOut(duration: 0.6))` and show `Int`. Do not re-run on every refresh, only on first appear.
- Dark bar in light mode: `NSAppearance` on the panel only.
- The window page state must survive the window being closed and reopened from the menu with a different page.

## 11. Done means

- `xcodebuild` builds with no warnings in changed files.
- `swift test` in `ChirpCore` passes, including the new stats tests.
- The app launches; Home, History, Dictionary, Snippets, App styles and Settings open from the sidebar and from the menu bar.
- A hotkey recording, a bar click recording and a Home button recording all show the bar states in order: Listening, Finishing, then Pasted or Copied.
- Stats on Home match a hand count of the history rows for today.
- Light and dark mode both look right. Screenshots of Home, History, Settings, the bar in three states and setup step 1 are saved under `docs/design/screens/`.
