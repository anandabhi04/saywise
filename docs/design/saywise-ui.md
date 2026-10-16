# Saywise UI design
Replaced by docs/specs/2026-10-17-saywise-ui-design.md. Kept for history.

Date: 2026-10-17
Status: proposal, waiting for approval
Mockup: `docs/design/saywise-ui.html` (open it in a browser)

## 1. The feel

**Quiet. Native. Alive when you speak.**

Saywise should feel like a part of macOS, not like a tool. Most of the time it is almost invisible. When you talk, one thing moves: the sound wave. Nothing else.

| Reference app | What we take from it |
|---|---|
| Wispr Flow | One small floating bar at the bottom of the screen. It grows when you speak and shows a live wave. It is the only thing you look at. |
| Raycast | Restraint. Dark glass, one font, few words, no decoration. Every pixel has a job. |
| Apple Voice Memos and Notes | System materials, system colors, system controls. Red only for "live". Big round record button. |
| Things | Lots of air. Short labels. Nothing explains itself twice. |

Rules that follow from this:

1. One accent: the system accent color. One "live" color: system red. Everything else is black, white and grey.
2. No sentence on screen that the user does not need right now.
3. Status is shown by a dot and two words, not by a paragraph.
4. Motion is used only to show sound and state change. No decoration.

## 2. What changes, in short

| Today | Proposed |
|---|---|
| Round floating button on the right edge, plus a separate black pill at the bottom. | One floating bar. It is the button and the wave in one place. |
| Main window with six sections and long explanation text. | Main window with three parts: status strip, record button, text card. |
| "Click to talk", "Your words appear in the box below", a long "Mic on" paragraph. | Short copy. See section 8. |
| Setup window is a list of permissions, a note about Fn, model status and a restart row, all at once. | One step per page. Each step has one title, one line and one button. |
| Status text "Ready — hold Fn to talk" in the menu bar menu. | "Ready" plus a short hint line. |

## 3. Main window

The window has one job: let the user talk to Saywise and see the text.

### 3.1 Size and chrome

| Item | Value |
|---|---|
| Size | 400 × 520 pt. Min 360 × 440. Resizable. |
| Title bar | Hidden title, full-size content (`titlebarAppearsTransparent`, `fullSizeContentView`). Traffic lights only. |
| Toolbar | Two icon buttons at the top right: History (`clock.arrow.circlepath`) and Settings (`gearshape`). |
| Background | Standard window background. No material. |

### 3.2 Layout, top to bottom

| Part | What it holds | Height |
|---|---|---|
| Status strip | Left: status dot + status text + hint. Right: mic switch. | 44 pt |
| Stage | The round record button, centered. Under it: one caption line, or the live wave. | 150 pt |
| Text card | The dictated text. Placeholder when empty. Copy and Clear icons at its bottom right, only when there is text. | fills the rest |

Padding: 20 pt on all sides. Gap between parts: 16 pt.

### 3.3 What is NOT on it

| Removed | Why | Where it went |
|---|---|---|
| "Recent" list | It made the window a second History window. | History window, one click away in the toolbar. |
| "Show floating button" toggle | A setting, not a daily action. | Settings > General, and the menu bar menu. |
| Long "Mic on" explanation | Nobody reads it twice. | The status text says "Mic is off" when it is off. |
| "Your words appear in the box below" | The box is right there. | Placeholder inside the box. |
| Bordered Copy and Clear buttons | Heavy. | Two small icon buttons inside the card. |
| "Settings…" button at the bottom | Duplicate. | Toolbar icon. |

### 3.4 The record button

| Property | Value |
|---|---|
| Size | 72 pt circle. Glyph 28 pt semibold. |
| Idle | Filled with `.primary` (black in light mode, white in dark). Glyph `mic.fill` in the window background color. |
| Hover | Scale 1.04, 120 ms ease-out. Cursor stays an arrow. |
| Pressed | Scale 0.96. |
| Recording | Filled system red. Glyph `stop.fill`. A soft red ring (opacity 0.25) breathes behind it: scale 1.0 → 1.18, 1.2 s, repeat. |
| Working | Fill `.primary` at 0.6 opacity. A small white `ProgressView` instead of the glyph. Not clickable. |
| Disabled (mic off, loading, failed) | Fill `.quaternary`. Glyph `.tertiary`. Not clickable. |

Under the button, one line in `.callout` `.secondary`, centered:

| State | Caption |
|---|---|
| Ready | Press to talk |
| Recording | Live wave (24 bars, 3 pt wide, 2 pt gap, 4 to 24 pt tall) and no text |
| Working | Finishing… |
| Mic off | Turn the mic on to talk |
| Loading | Getting ready… |

### 3.5 The text card

| Property | Value |
|---|---|
| Shape | `RoundedRectangle(cornerRadius: 12)`. Fill `Color(nsColor: .controlBackgroundColor)`. Stroke `.separator`, 0.5 pt. |
| Text | `TextEditor`, `.body`, padding 12 pt, no inner border, scrolls. |
| Placeholder | "What you say will appear here." in `.secondary`. Shown only when empty. |
| Actions | Bottom right, inside the card: `doc.on.doc` (Copy) and `xmark.circle` (Clear). `.borderless`, `.secondary`. Hidden when the card is empty. |
| After a dictation | New text is appended with one blank line. The card scrolls to the end. Copy shows "Copied" in place for 1.5 s. |

### 3.6 Window states

| State | Status dot | Status text | Hint | Button | Extra |
|---|---|---|---|---|---|
| Ready | green | Ready | Hold Fn in any app | idle | — |
| Recording | red, pulsing | Listening | — | recording | wave under the button |
| Working | grey | Finishing | — | working | — |
| Mic off | grey | Mic is off | — | disabled | switch is off |
| Loading models | grey | Getting ready | 1.6 GB of 4.1 GB | disabled | thin progress bar under the status strip |
| Models failed | orange | Needs attention | — | disabled | banner, see below |
| Permission missing | orange | Needs attention | — | idle or disabled | banner, see below |

The banner sits between the status strip and the stage. One per state, never two.

| Case | Banner text | Button |
|---|---|---|
| Models failed | Saywise could not load its models. | Try again |
| Microphone missing | Saywise needs the microphone to hear you. | Allow |
| Accessibility missing | Saywise needs Accessibility to paste into other apps. | Allow |
| Input Monitoring missing | Saywise needs Input Monitoring to notice the Fn key. | Allow |

Banner style: `RoundedRectangle(cornerRadius: 10)`, fill `.orange.opacity(0.12)`, icon `exclamationmark.circle.fill` in orange, text `.callout`, button `.bordered` small. The "Allow" button requests the permission. If the system cannot ask again, it opens System Settings instead.

The hint "Hold Fn in any app" uses the real key name from settings.

## 4. The floating bar

### 4.1 Recommendation: one bar, not two controls

| Option | What it is | Cost | When right |
|---|---|---|---|
| A. One bar (recommended) | One floating capsule. Idle it is a small mic button. Click it or hold Fn and it grows into the wave. It shows "Finishing" and the result in the same place. | The hotkey wave is no longer at the bottom center if the user moved the bar. | Always. One thing to learn, one place to look. |
| B. Keep both | Round button on the side, pill at the bottom. | Two overlays. The wave appears somewhere else from where you clicked. Two things to position, two things that can look wrong. | Never. |

Recommendation: A. This is how Wispr Flow works, and it is why it feels simple.

### 4.2 Shape and place

| Property | Value |
|---|---|
| Shape | Capsule. Height 36 pt. Width changes with the state (spring). |
| Default place | Bottom center of the main screen, 24 pt above the Dock area. |
| Drag | Press and move more than 4 pt, anywhere on the bar. The place is saved. If the saved place is off every screen, it goes back to the default. The bar never leaves the visible screen: it is kept 12 pt inside the edges. |
| Window | Non-activating `NSPanel`. Level `.statusBar`. All Spaces, full-screen auxiliary. Never key, never main. Clicking it never takes focus from the app the user is typing in. |
| Material | Dark glass in both modes: `NSVisualEffectView` with `.hudWindow` material, `.behindWindow` blending, `.dark` appearance. Over it a black tint at 0.35. Inner stroke `.white.opacity(0.14)`, 0.5 pt. |
| Shadow | `.black.opacity(0.28)`, radius 14, y 6. |
| Text | 13 pt medium, white. Monospaced digits. |

The bar stays dark in light mode on purpose. It floats over other apps, and a dark bar reads as "overlay", not as "window".

### 4.3 States

| State | Width | Content | Click does |
|---|---|---|---|
| Idle | 56 pt | `mic.fill` 15 pt, white at 0.9 | Start recording |
| Hover | 56 pt | Same. Bar brightens: tint 0.35 → 0.5 white stroke 0.14 → 0.22. Scale 1.03. Tooltip after 0.8 s: "Talk · drag to move". | — |
| Recording | 200 pt | Red dot 8 pt at left (pulse 1.0 → 0.5 opacity, 1 s) + 24 wave bars, 3 pt wide, 2 pt gap, 4 to 20 pt tall, white | Stop recording |
| Working | fits | `ProgressView` small, white + "Finishing" | Nothing |
| Done (pasted) | — | Bar shrinks back to idle. No message. The text appearing is the message. | — |
| Done (copied) | fits | `doc.on.clipboard` + "Copied. Click where you want it and press ⌘V" for 3 s, then idle | Dismiss |
| Mic off | 56 pt | `mic.slash.fill`, white at 0.5. Bar at 0.7 opacity. | Turn the mic on. The bar shows "Mic on" for 1.5 s, then idle. |
| Loading | 56 pt | Small `ProgressView` white at 0.7 | Shows "Getting ready…" for 1.5 s |
| Error | fits | `exclamationmark.circle.fill` orange + message for 3 s, then idle | Dismiss |
| Hidden | — | Setting "Show floating bar" is off | — |

Recordings started from the hotkey or the main window use the same bar. There is one place the wave lives.

Wave: each bar height = 4 + min(1, level × 12) × 16 pt. Bars update at the recorder's level rate. Animation `.easeOut(duration: 0.08)` on the levels, as today.

Width change: `.spring(response: 0.35, dampingFraction: 0.8)`. Content fade: `.easeOut(duration: 0.15)`.

### 4.4 Why a dark capsule and not a round button

A round button with a glyph on it looks like a chat widget on a website. A low, dark capsule looks like a system HUD (volume, brightness). It takes less of the screen, and it has room to grow into the wave without changing shape.

## 5. First run

One window, 480 × 400 pt. Hidden title bar. One step per page. A row of small dots at the bottom shows progress. Steps move with a spring slide (`.spring(response: 0.4, dampingFraction: 0.85)`). The window is not resizable.

Each step: SF Symbol 44 pt in the accent color, title `.title2` semibold, one line `.body` `.secondary`, one primary button. Nothing else.

| # | Symbol | Title | Line | Button | Then |
|---|---|---|---|---|---|
| 1 | `waveform` | Welcome to Saywise | Hold Fn, speak, let go. Your words appear where you type. English, Hindi, or both. Everything stays on this Mac. | Continue | step 2 |
| 2 | `mic.fill` | Microphone | So Saywise can hear you. | Allow | The system asks. On yes, the step shows a green check for 0.6 s and moves on by itself. |
| 3 | `keyboard` | Input Monitoring | So Saywise notices when you hold Fn. | Allow | Opens System Settings. The step waits and polls once a second. When granted, it moves on. |
| 4 | `accessibility` | Accessibility | So Saywise can paste into other apps. | Allow | Same as step 3. |
| 5 | `globe` | One setting for Fn | By default Fn opens the emoji picker. Set "Press 🌐 key to" to "Do Nothing". | Open Keyboard Settings | A secondary link "Done, continue" moves on. |
| 6 | `arrow.down.circle` | Downloading models | About 4 GB, once. After this, Saywise never uses the network. | — | A progress bar with "1.6 GB of 4.1 GB". Moves on when loaded. |
| 7 | `checkmark.circle.fill` (green) | You're set | Hold Fn in any app and start talking. | Open Saywise | Closes setup, opens the main window. |

Rules:

- Steps already granted are skipped. A returning user with one missing permission sees only that step.
- If Input Monitoring needs a restart to take effect (the tap fails after grant), the step shows a second line "Saywise needs a quick restart to use this." and the button becomes "Restart Saywise".
- A download error replaces the progress bar with one line "The download stopped." and a "Try again" button. No raw error text on this page. A small "Details" link shows it.
- Skip the Fn step when the trigger key is not Fn.
- The Escape key does nothing here. The red close button closes setup. Setup opens again on the next launch if anything is still missing.

## 6. Menu bar

Icon: `waveform` template image. Recording: `waveform.circle.fill`. Working: `ellipsis.circle`. Mic off: `mic.slash`. Needs attention: `exclamationmark.triangle`.

Menu, top to bottom:

| Item | Type | Note |
|---|---|---|
| Ready · hold Fn to talk | disabled text | The status line. See section 8 for each state. |
| — | divider | |
| Open Saywise | item, ⌘O | Main window |
| Mic on | checkmark toggle | Off = paused |
| Show floating bar | checkmark toggle | |
| — | divider | |
| History… | item | |
| Settings… | item, ⌘, | |
| Finish setup… | item | Only when a permission or the models are missing |
| — | divider | |
| Quit Saywise | item, ⌘Q | |

The keyboard shortcuts only work while Saywise is the front app. That is normal for menu bar apps.

## 7. Visual system

| Area | Value |
|---|---|
| Font | System font (SF Pro). Styles: `.title2` semibold (onboarding titles), `.headline` (status), `.body` (text), `.callout` (captions, banners), `.caption` (meta). Bar text: `.system(size: 13, weight: .medium).monospacedDigit()`. |
| Colors | `.primary`, `.secondary`, `.tertiary`, `.quaternary` for text and fills. `Color.accentColor` for the switch, links, onboarding symbols. `Color.red` for recording. `Color.orange` for attention. `Color.green` for the ready dot and checks. No custom hex colors anywhere. |
| Window material | Standard window background. Cards: `Color(nsColor: .controlBackgroundColor)`. |
| Bar material | `NSVisualEffectView` `.hudWindow`, dark appearance, plus black 0.35 overlay. |
| Corner radii | 6 (small controls), 10 (banners), 12 (cards), capsule (bar, record button). |
| Spacing scale | 4, 8, 12, 16, 20, 24, 32. Window padding 20. Section gap 16. Inline gap 8. |
| Strokes | `.separator` at 0.5 pt on cards. `.white.opacity(0.14)` at 0.5 pt inside the bar. |
| Shadows | Only on the bar: black 0.28, radius 14, y 6. Windows use the system shadow. |
| Springs | State change: `.spring(response: 0.35, dampingFraction: 0.8)`. Page slide: `.spring(response: 0.4, dampingFraction: 0.85)`. Hover: `.easeOut(duration: 0.12)`. Wave: `.easeOut(duration: 0.08)`. Breath ring: `.easeInOut(duration: 1.2).repeatForever(autoreverses: true)`. |
| Sounds | Start: `Tink`. Stop: `Pop`. Keep as is. No sound on error; the bar shows it. Off in Settings. |
| Dark mode | Everything uses semantic colors, so it follows the system. The bar is dark in both modes. The record button flips: black on light, white on dark. |
| SF Symbols | `mic.fill`, `mic.slash.fill`, `stop.fill`, `waveform`, `waveform.circle.fill`, `ellipsis.circle`, `clock.arrow.circlepath`, `gearshape`, `doc.on.doc`, `doc.on.clipboard`, `xmark.circle`, `exclamationmark.circle.fill`, `exclamationmark.triangle`, `checkmark.circle.fill`, `keyboard`, `accessibility`, `globe`, `arrow.down.circle`. |

Icon in the Dock: a white waveform on a black rounded square, in the macOS 15 icon style. Not part of this spec; needs a design asset.

## 8. All copy

Short, calm, human. No dashes inside sentences. The key name comes from settings; "Fn" below is the default.

### Main window

| Where | Text |
|---|---|
| Window title (hidden, used by the Dock and ⌘-tab) | Saywise |
| Status, ready | Ready |
| Status hint, ready | Hold Fn in any app |
| Status, recording | Listening |
| Status, working | Finishing |
| Status, mic off | Mic is off |
| Status, loading | Getting ready |
| Status hint, loading | 1.6 GB of 4.1 GB |
| Status, attention | Needs attention |
| Switch label (accessibility only) | Mic |
| Caption under button, ready | Press to talk |
| Caption, working | Finishing… |
| Caption, mic off | Turn the mic on to talk |
| Caption, loading | Getting ready… |
| Text card placeholder | What you say will appear here. |
| Copy icon tooltip | Copy |
| Copy done | Copied |
| Clear icon tooltip | Clear |
| Toolbar, history tooltip | History |
| Toolbar, settings tooltip | Settings |
| Banner, models failed | Saywise could not load its models. |
| Banner button | Try again |
| Banner, microphone | Saywise needs the microphone to hear you. |
| Banner, accessibility | Saywise needs Accessibility to paste into other apps. |
| Banner, input monitoring | Saywise needs Input Monitoring to notice the Fn key. |
| Banner permission button | Allow |
| Banner, after a window dictation with no speech | Nothing heard. Try again a bit closer to the mic. |

### Floating bar

| Where | Text |
|---|---|
| Idle tooltip | Talk · drag to move |
| Recording tooltip | Click to stop |
| Working | Finishing |
| Copied, no text field | Copied. Click where you want it and press ⌘V |
| Copied, no accessibility | Copied. Allow Accessibility to paste next time |
| Mic turned on by click | Mic on |
| Loading, clicked | Getting ready… |
| Mic not allowed | Saywise can't use the mic |
| Mic busy | The mic is not available |
| No speech | Nothing heard |
| Transcription failed | Couldn't make that out |

### Menu bar status line

| State | Text |
|---|---|
| Ready | Ready · hold Fn to talk |
| Recording | Listening |
| Working | Finishing |
| Mic off | Mic is off |
| Loading | Getting ready · 40% |
| Failed | Models did not load |
| Permission missing | Setup not finished |

### First run

See the table in section 5. Extra lines:

| Where | Text |
|---|---|
| Permission granted check | Allowed |
| Restart needed, line | Saywise needs a quick restart to use this. |
| Restart button | Restart Saywise |
| Fn step, secondary link | Done, continue |
| Download error | The download stopped. |
| Download retry | Try again |
| Details link | Details |

### Settings and History (changed lines only)

| Where | Text |
|---|---|
| General, new toggle | Show floating bar |
| General, key picker label | Talk key |
| Language, note | Hindi is written in Roman letters, like "kal meeting hai". |
| History, empty list | No dictations yet. |
| History, no selection | Select a dictation to see the details. |
| History detail, left box | Heard |
| History detail, right box | Written |
| Clear all dialog | Delete all history? This cannot be undone. |

## 9. Settings and History

Only what is needed to match.

| Window | Change |
|---|---|
| Settings > General | Add "Show floating bar" toggle under "Talk key". Rename "Dictation key" to "Talk key". |
| Settings > Models | Keep. Replace `ModelStatusView` text "Models are ready" with a green check and "Ready". |
| Settings, all tabs | Keep the grouped form style. No other change. |
| History | Empty state text. Detail box titles "Heard" and "Written". Everything else stays. |

## 10. Build notes

All of this is plain SwiftUI and AppKit on macOS 15. No third-party libraries.

| File | Change |
|---|---|
| `App/UI/MainView.swift` | Rewrite the body: status strip, stage, text card. Remove the recent list, the floating toggle, the Settings button, the long mic text. Move `canTalkHere`, `isRecordingHere`, `isWorkingHere` and the status mapping into a small `MainViewModel` or keep as private computed properties. The record button becomes `RecordButton(state:)` in its own file with the breath ring. The wave becomes `WaveView(levels:)` shared with the bar. The window gets `.toolbar { }` with the two icon buttons. |
| `App/UI/WindowCoordinator.swift` | Main window: size 400 × 520, min 360 × 440, `titlebarAppearsTransparent = true`, `titleVisibility = .hidden`, `styleMask.insert(.fullSizeContentView)`. Setup window: 480 × 400, not resizable. |
| `App/UI/FloatingButton.swift` + `App/UI/Pill.swift` | Merge into `App/UI/FloatingBar.swift`. Keep `FloatingButtonHostView` (click vs drag) and the non-activating `NSPanel` subclass. Keep `PillModel` as `BarModel` with `phase` and `levels`. The panel resizes to the content's `fittingSize` on each phase change, anchored on the bar's center, inside the screen's `visibleFrame` with 12 pt margin. Drag stays as it is. Background: an `NSVisualEffectView` (`.hudWindow`, `.behindWindow`, `appearance = NSAppearance(named: .darkAqua)`) under the `NSHostingView`, with the hosting view's layer clear. `level = .statusBar`. Must stay a non-activating panel: `styleMask: [.nonactivatingPanel, .borderless]`, `canBecomeKey` and `canBecomeMain` return false, so a click never takes focus from the app the user is typing in. |
| `App/AppController.swift` | Replace `pill` with `bar`. `startRecording` shows `.recording` on the bar for every source (today it skips `.window`). `finish`: on `.pasted` hide, on `.copiedNoTextField` and `.copiedNoPermission` flash the new copy. `toggleRecording` from the bar when `.paused`: call `togglePause()` and flash "Mic on". Status text and `menuBarSymbol`: the new strings and symbols from sections 6 and 8. Add `statusHint` (the "Hold Fn in any app" line) and `modelProgressText` ("1.6 GB of 4.1 GB"; if the loader gives no byte count, show a percent). |
| `App/UI/SetupView.swift` | Rewrite as `OnboardingView` with a `step` state and a `steps` array built from what is missing. One `StepPage` view. Poll permissions once a second as today. `AppRelauncher.relaunch()` stays for the restart case. The download step reads `controller.modelProgress`. |
| `App/UI/MenuContent.swift` | Items from section 6. The two toggles use `Toggle` inside the menu (SwiftUI shows a checkmark). Add ⌘O on "Open Saywise". |
| `App/UI/Settings/SettingsView.swift` | General: rename the picker, add the floating bar toggle. |
| `App/UI/HistoryView.swift` | Empty state and the two box titles. |
| `App/System/Permissions.swift` | `reason` strings from section 5. |
| Shared views (new) | `WaveView` (bars from levels), `StatusDot` (color + optional pulse), `RecordButton`. One file each under `App/UI/Components/`. |

Things the engineer should check while building:

- The bar's width animation must not re-create the panel. Resize the existing panel with `setFrame(_:display:animate:)` set to `false` and let SwiftUI animate the content; or animate the frame with `NSAnimationContext` at 0.25 s. Pick the one that does not flicker.
- When the bar grows, keep its center fixed, not its left edge. Otherwise it jumps when it is at the right side of the screen.
- `TextEditor` has no placeholder. Overlay a `Text` at the top left with `.allowsHitTesting(false)` when the text is empty.
- Hover on the bar: `.onHover` in SwiftUI works inside a non-activating panel. The tooltip is `.help(_:)`.
- The toolbar in a hidden-title window: use `.toolbar` with `ToolbarItemGroup(placement: .primaryAction)`. The traffic lights stay on the left by themselves.
- Dark bar in light mode: set the `NSAppearance` on the panel, not on the app, so the rest of the app keeps following the system.

## 11. Open questions

1. The bar is dark in both light and dark mode. Is that fine, or should it follow the system in light mode?
2. Clicking the bar while the mic is off turns the mic on. Is that right, or should it only show "Mic is off"?
3. The Recent list leaves the main window. History is one click away in the toolbar. Fine?
