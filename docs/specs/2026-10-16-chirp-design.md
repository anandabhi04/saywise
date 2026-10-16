# Chirp — design spec

Date: 2026-10-16
Status: approved design, ready for an implementation plan

## 1. What Chirp is

Chirp is a Mac menu bar app for voice typing. It is a personal version of Wispr Flow.

You hold a key, speak, and let go. Clean text appears where your cursor is, in any app.

Everything runs on your Mac. No audio and no text leave the machine.

## 2. Decisions

| Topic | Decision |
|---|---|
| Platform | macOS only. Native Swift and SwiftUI. Minimum macOS 15. |
| Users | Only the owner. No sign-in, no server, no billing, no sync. |
| Speech to text | On device. Default engine: Whisper large-v3-turbo through WhisperKit. |
| Languages | English, Hindi and Hinglish (mixed). |
| Hindi output | Roman letters. Example: "kal meeting hai, 5 baje". |
| Text cleanup | On device. Qwen3 4B Instruct (4-bit) through MLX Swift (`mlx-swift-lm`), inside the app. |
| v1 features | Dictation, personal dictionary, app-aware style, history, snippets. |
| Not in v1 | Command mode, live text while speaking, iPhone, Windows, voice commands such as "press enter". |
| Distribution | Built and signed locally with Xcode. Not sandboxed. Not on the App Store. |

Target machine: M4 Max with 128 GB of memory. The design should still work on any Apple Silicon Mac with 16 GB or more.

## 3. User experience

### 3.1 Hotkey

| Action | Result |
|---|---|
| Hold **Fn** | Start recording. Release to finish. |
| Double-tap **Fn** | Hands-free mode. Recording keeps going until you tap Fn again. |
| **Esc** while recording | Cancel. Nothing is pasted or saved. |

The hotkey can be changed in Settings. Fn is the default.

A press shorter than 0.3 seconds is ignored. This stops accidental taps.

Hands-free mode stops by itself after 10 minutes.

### 3.2 Recording pill

A small floating pill shows at the bottom center of the screen while recording.

- It shows a live sound wave from the mic level.
- After release it shows a short "working" state until the text is pasted.
- It never takes keyboard focus. The cursor stays in your app.
- On error it shows a short message for 3 seconds. For example: "Mic not allowed" or "Copied — no text field".

### 3.3 Menu bar icon

The menu shows:

- Current state: ready, recording, working, or loading models.
- Open History.
- Open Settings.
- Pause Chirp (turns off the hotkey).
- Quit.

### 3.4 Settings window

| Tab | Holds |
|---|---|
| General | Hotkey, start at login, sounds on or off. |
| Language | Mode: Auto, English, or Hindi/Hinglish. Speech engine choice. |
| Models | Which models are downloaded, their size, re-download button. |
| Dictionary | Your special words and fix rules. See section 6. |
| Snippets | Trigger phrase and the text it expands to. See section 7. |
| App styles | Which apps get which style. See section 5. |
| History | How long to keep history. Keep audio on or off. Clear all. |

### 3.5 History window

- A list of past dictations, newest first.
- Each row shows the clean text, the app it went to, and the time.
- Click a row to see the raw transcript next to the clean text.
- Search box over both texts.
- Copy button on each row.
- Delete one row or clear all. Clear all asks for a yes first.

## 4. How a dictation works

```
Fn down ─► record audio ─► read app context
Fn up   ─► speech to text ─► dictionary fixes ─► protect snippets
        ─► LLM cleanup ─► safety check ─► expand snippets ─► paste ─► save to history
```

| # | Step | Details |
|---|---|---|
| 1 | Record | `AVAudioEngine`. Mono, 16 kHz, 32-bit float. Kept in memory. Not written to disk unless "keep audio" is on. |
| 2 | Read context | At key-down: the front app's bundle id and window title, through `NSWorkspace` and the Accessibility API. This picks the style. |
| 3 | Silence check | A simple voice activity check (energy based). If there is no speech, stop here and paste nothing. This stops Whisper from inventing text on silence. |
| 4 | Speech to text | Whisper large-v3-turbo. Language from the Language setting. Dictionary words go into the initial prompt as hints. |
| 5 | Hallucination filter | Drop known silence phrases such as "Thank you for watching." when the audio has little speech. |
| 6 | Dictionary fixes | Apply the fix rules from section 6. Plain text replace, case-insensitive, whole words only. |
| 7 | Protect snippets | Replace inline snippet triggers with placeholders like `⟦S1⟧`, so the LLM does not change them. |
| 8 | LLM cleanup | Qwen3 4B with the prompt from section 8. Skipped for very short text (3 words or fewer) and for the "Raw" style. |
| 9 | Safety check | See section 9. If it fails, use the text from step 7 instead. |
| 10 | Expand snippets | Replace placeholders with the snippet text. If the whole utterance is one trigger, paste the snippet and skip steps 8 and 9. |
| 11 | Paste | See section 10. |
| 12 | Save | Write one history row. See section 11. |

### 4.1 Speed targets

Measured from key release to text pasted, on the M4 Max, warm models.

| Speech length | Target |
|---|---|
| 5 seconds | under 0.7 s |
| 10 seconds | under 1.0 s |
| 60 seconds | under 3.0 s |

Both models load at app start and stay in memory. The pill shows "loading models" until they are ready.

## 5. App-aware style

Each front app maps to one style. The style changes the LLM instructions.

| Style | Default apps | What it does |
|---|---|---|
| Chat | Slack, WhatsApp, Messages, Telegram, Discord | Casual. Short. No ending period on a single sentence. Keeps emoji words as words. |
| Email | Mail, Outlook, Spark | Full sentences. Proper punctuation. Paragraphs when the speaker pauses or says "new paragraph". |
| Code | VS Code, Cursor, Xcode, Terminal, iTerm, Ghostty, Zed | Light cleanup only. Remove fillers. Keep code words exactly as spoken. No added period. No capital first letter. |
| Document | Notes, Notion, Pages, Word, Obsidian | Clean prose with lists when the speaker lists things. |
| Raw | None by default | No LLM. Dictionary and snippets only. |
| Default | Every other app | Same as Document. |

Browsers (Safari, Chrome, Arc) use the window title to pick a style. For example, a title with "Gmail" picks Email. A title with "Slack" picks Chat. These title rules are editable.

The user can change the style of any app in Settings.

## 6. Personal dictionary

Two kinds of entries.

| Kind | Example | Used where |
|---|---|---|
| Word | `UnifyApps`, `Nebula`, `Abhishek` | Whisper prompt as a hint, and the LLM prompt as "spell these exactly". |
| Fix rule | `unify apps` → `UnifyApps` | Plain text replace after speech to text (step 6). |

The Whisper prompt has a size limit of about 224 tokens. If the word list is too long, the most recently used words go first.

## 7. Snippets

A snippet is a trigger phrase and the text it expands to.

Example: trigger `my email` expands to `anandabhibhu04@gmail.com`.

- **Whole match:** if the whole utterance is the trigger, paste the snippet text directly. No LLM.
- **Inline match:** if the trigger is inside a longer sentence, it becomes a placeholder before cleanup and is expanded after. Example: "send it to my email" → "Send it to anandabhibhu04@gmail.com."

Trigger matching is case-insensitive and ignores ending punctuation.

## 8. LLM cleanup

### 8.1 Model

- Default: `mlx-community/Qwen3-4B-Instruct` 4-bit (exact repo id is fixed during the plan).
- Thinking mode off.
- Temperature 0. Max output tokens: 2 × input tokens + 50.
- Kept warm in memory. Settings can swap to any mlx-community text model.

### 8.2 Prompt rules

The system prompt tells the model to:

1. Only rewrite the text. Never answer it, even if it is a question or an instruction.
2. Remove fillers: um, uh, like, you know, matlab, haan, etc. when they carry no meaning.
3. Apply self-corrections. "Meet at 5, no wait, 6" → "Meet at 6."
4. Turn spoken punctuation into marks: "comma", "full stop", "question mark", "new line", "new paragraph".
5. Format spoken lists as lists when the style allows it.
6. Keep Hindi and Hinglish words in Roman letters. Do not translate between languages.
7. Spell dictionary words exactly as given.
8. Leave `⟦S1⟧` style placeholders untouched.
9. Follow the style block for the current app (section 5).
10. Output only the final text. No quotes, no notes.

The prompt includes a few short before/after examples per style.

## 9. Safety check on cleanup

The LLM output is thrown away, and the step-7 text is used instead, when any of these is true:

- Cleanup took longer than 2 seconds.
- Output is empty.
- Output length is under 40% or over 150% of the input length (counted in characters).
- A placeholder is missing or changed.
- Output starts like an answer, for example "Sure", "Here is", "I can".

Each fallback is logged in history with the reason.

## 10. Pasting text

1. Save the current clipboard (all types).
2. Put the final text on the clipboard.
3. Send Cmd+V with `CGEvent`.
4. After 300 ms, put the old clipboard back.

If no text field has focus (checked with the Accessibility API), Chirp does not send Cmd+V. It leaves the text on the clipboard and the pill shows "Copied — no text field".

## 11. Storage

| Data | Where | Format |
|---|---|---|
| Settings, dictionary, snippets, app styles | `~/Library/Application Support/Chirp/` | JSON files |
| History | Same folder, `history.sqlite` | SQLite through GRDB |
| Audio (only if "keep audio" is on) | Same folder, `audio/` | 16 kHz WAV, last 50 clips only |
| Models | Same folder, `models/` | As downloaded |

History row fields: id, created at, app bundle id, app name, style, language, audio length, raw text, final text, cleanup used (yes / no / fallback reason), time per step in milliseconds.

Default history keep time: 30 days. Options: 7 days, 30 days, forever, off.

## 12. Permissions

| Permission | Why |
|---|---|
| Microphone | Record speech. |
| Accessibility | Send Cmd+V, read the focused field and the front window title. |
| Input Monitoring | Watch the Fn key with a `CGEventTap`. |

First launch shows a short setup window. It asks for each permission one by one and shows a green check when granted.

## 13. Models and network

- Models download on first launch from Hugging Face, with a progress bar.
- Whisper large-v3-turbo: about 1.6 GB. Qwen3 4B 4-bit: about 2.5 GB.
- After the download, Chirp makes no network calls.
- If a download fails, the setup window shows the error and a retry button.

## 14. Code structure

One Xcode project. Logic lives in a local Swift package so it can be tested without the UI.

| Module | Job | Depends on |
|---|---|---|
| `HotkeyMonitor` | Watches Fn and Esc. Emits start, stop, cancel, hands-free. | CGEventTap |
| `AudioRecorder` | Records 16 kHz mono audio. Emits levels for the pill. | AVAudioEngine |
| `ContextReader` | Reads front app and window title. Checks for a focused text field. | NSWorkspace, AX API |
| `StyleResolver` | Maps context to a style. Pure logic. | Settings |
| `Transcriber` | Protocol: audio + language + hints → text. | — |
| `WhisperKitTranscriber` | Default `Transcriber`. | WhisperKit |
| `Qwen3ASRTranscriber` | Second `Transcriber`, for testing. See section 16. | speech-swift |
| `Cleaner` | Protocol: text + style + dictionary → text. | — |
| `MLXCleaner` | Default `Cleaner`. Builds the prompt and runs Qwen3. | mlx-swift-lm |
| `TextRules` | Silence filter, dictionary fixes, snippet protect and expand, safety check. Pure logic. | — |
| `Inserter` | Clipboard save, paste, restore. | NSPasteboard, CGEvent |
| `HistoryStore` | Read and write history rows. Applies the keep time. | GRDB |
| `DictationPipeline` | Runs the steps in section 4 in order and times each one. | All of the above |
| App UI | Menu bar, pill, Settings, History, setup window. | SwiftUI, AppKit |

`Transcriber` and `Cleaner` are protocols so the engines can be swapped and faked in tests.

## 15. Errors

| Problem | What the user sees | What Chirp does |
|---|---|---|
| Mic permission missing | Pill: "Mic not allowed" | Opens the setup window. |
| Accessibility missing | Pill: "Copied — allow Accessibility to paste" | Leaves text on the clipboard. |
| Models still loading | Pill: "Loading models…" | Ignores the hotkey until ready. |
| No speech in audio | Nothing | Pastes nothing. Saves nothing. |
| Speech to text fails | Pill: "Couldn't transcribe" | Logs the error. Keeps audio for that one clip if "keep audio" is on. |
| Cleanup fails or is slow | Nothing special | Pastes the raw text (section 9). |
| No focused text field | Pill: "Copied — no text field" | Leaves text on the clipboard. |
| Hotkey pressed while working | Nothing | Ignored until the current dictation is done. |

## 16. Speech engine choice

Source used: Gladia, "Best open-source speech-to-text models in 2026" (14 Apr 2026).

| Model | Hindi / Hinglish | Decision |
|---|---|---|
| Whisper large-v3-turbo | Yes. 99+ languages. 809M params. 7.75% WER in the article. | **Default.** Mature Apple Silicon support through WhisperKit. |
| Qwen3-ASR 0.6B / 1.7B | 52 languages. Hindi not yet confirmed. | **Test it.** Runs on Apple Silicon through the speech-swift package (MLX). Keep it if it beats Whisper on our test set. |
| Parakeet TDT, Canary-Qwen | No. English or European languages only. | Not used. |
| Moonshine | No. English only. | Not used. |
| Granite Speech, Wav2Vec 2.0 | Too large, or too weak without fine-tuning. | Not used. |

Note from the article: benchmark error rates come mostly from clean read speech. Real speech can be much worse. So the choice is made on our own test set (section 17), not on published numbers.

## 17. Testing

### 17.1 Unit tests (no models needed)

- `StyleResolver`: bundle ids and window titles map to the right style.
- `TextRules`: dictionary fixes, snippet whole and inline match, placeholder protect and expand, every safety check rule, silence phrase filter.
- Prompt builder: the right style block, dictionary words and examples go in.
- `DictationPipeline` with a fake `Transcriber` and fake `Cleaner`: step order, fallback on slow or bad cleanup, cancel with Esc, short press ignored.
- `HistoryStore`: write, search, keep-time cleanup.

### 17.2 Voice test set (real models)

- About 40 recorded clips of the owner's own voice: 15 English, 10 Hindi, 15 Hinglish.
- Each clip has an expected final text.
- A command-line runner sends every clip through the full pipeline and reports:
  - word error rate for speech to text (per language),
  - how often cleanup fell back,
  - time per step.
- The same runner compares Whisper turbo and Qwen3-ASR.

### 17.3 Manual check before calling v1 done

Dictate into Slack, Mail, Notes, VS Code, Terminal, Safari (Gmail) and Chrome. Check the style, the paste, and that the old clipboard comes back.

## 18. Done means

- Hold Fn, speak, release: clean text appears in the front app.
- English, Hindi and Hinglish work. Hindi comes out in Roman letters.
- Speed targets in section 4.1 are met on the M4 Max.
- Dictionary, snippets, app styles and history work as written.
- No network calls after models are downloaded.
- All unit tests pass. The voice test set runs and its numbers are recorded.

## 19. Decisions made while planning

Found while checking the real library code on 2026-10-16. Full table in the [implementation plan](../plans/2026-10-16-chirp-plan.md).

- Both speech engines write Hindi in Devanagari. Chirp turns it into Roman letters on every path, not only through the LLM.
- A dictionary entry is one word plus optional "heard as" forms. This covers both kinds in section 6.
- All settings live in one `settings.json`.
- Pressing another key while holding Fn cancels the dictation (Fn is also used for shortcuts).
- Cleanup model: `mlx-community/Qwen3-4B-Instruct-2507-4bit`.
- speech-swift forces two pins: `mlx-swift-lm` exactly 3.31.4, and WhisperKit from `github.com/argmaxinc/WhisperKit`.
- Qwen3-ASR's model card does list Hindi, so it is a real candidate for section 16.
