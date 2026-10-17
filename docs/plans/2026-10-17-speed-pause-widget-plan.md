# Speed, cleanup, clipboard, pause and vertical widget

Branch: `saywise-speed`. One Codex run per task, in order. Each task ends with a passing build and
`swift test` in `Packages/ChirpCore`, then one commit.

Build: `xcodegen generate && xcodebuild -project Chirp.xcodeproj -scheme Chirp -configuration Debug -derivedDataPath build/DerivedData -skipPackagePluginValidation -skipMacroValidation build`

## Facts measured before the work (History database, 27 dictations)

| Clip | Transcribe | Cleanup | Total after stop |
|---|---|---|---|
| 3 s | 0.56 s | 0.42 s | 1.0 s |
| 20 s | 0.85 s | 0.86 s | 1.7 s |
| 75 s | 2.4 s | 2.1 s | 4.6 s |

All work starts after the key is released. Cleanup has a fixed 2 s limit, and long clips are near it.

## T0. Speed bench clips

The `TestClips/*.wav` files are not on disk. Add `scripts/make-speed-clips.sh` that makes English
clips with macOS `say` (16 kHz mono WAV, via `afconvert`): about 3 s, 20 s, 45 s and 75 s. Put them
in `TestClips/speed/` with their own `manifest.json`. Run ChirpBench on them and save the output to
`docs/plans/bench-before.txt`. Do not change app code in this task.

## T1. Clipboard keeps the dictation

`App/System/PasteInserter.swift`: after pasting, do not put the old clipboard back. The dictated
text stays on the clipboard, so Cmd+V works when no input was focused. Remove `ClipboardSnapshot`
if nothing else uses it.

## T2. Cleanup fixes misheard words

`CleanupPromptBuilder`:
- New rule: the transcript comes from a speech engine and can hold misheard words. When a word
  does not fit the meaning, replace it with the similar-sounding word the speaker meant
  ("start a new stations" → "start a new session"). Never add new ideas.
- Add one misheard-word example to each style's examples.
- Give the model the app name and window title as context, outside the `<transcript>` tags, with a
  line saying it is only a hint about the topic and must not be copied into the output.

`DictationPipeline`: call the LLM for 2 words or more (today it skips 3 words or fewer). Pass the
context into the prompt builder. Update `CleanupPromptBuilderTests` and `DictationPipelineTests`.

## T3. Cleanup speed and time limit

- Cleanup time limit grows with length: 2 s plus 30 ms per word, at most 6 s.
- Look at `MLXLMCommon` in the resolved package version. If it can reuse a prepared prompt prefix
  (KV cache) across calls, keep one cache per style for the instruction text, so each call only
  processes the transcript. Keep it only if the bench shows it is faster. Never share chat history
  between dictations.
- Run the bench, save `docs/plans/bench-after-t3.txt`.

## T4. Transcribe while recording

While recording, when at least 15 s of untranscribed audio exist, find a quiet gap (low RMS, at
least 300 ms) in the newest part and transcribe the audio up to that gap in the background. Only
one background chunk runs at a time. On stop, transcribe only the rest and join the parts with a
space. Hints and language stay as today. The Urdu retry stays per chunk. Cancel drops all of it.
The pipeline gets the joined raw text and skips its own transcribe step for it. Keep the logic
that picks chunk points in ChirpCore with tests. Run the bench with clips fed in real time and
save `docs/plans/bench-after-t4.txt`.

## T5. Pause and resume

- New recording state "paused" (the name `Status.paused` is taken by "mic is off", so use
  `recordingPaused`). Pause stops taking audio but keeps what was said. Resume adds to it.
- Hold-to-talk with Fn works as today. Pause is a widget button. In hands-free mode one Fn tap
  still finishes. Esc still cancels, also while paused.
- The hands-free 10 minute limit counts only time spent listening.
- While paused, the mic is released (no orange dot).

## T6. Vertical widget, option A

Design: `docs/design/saywise-widget-preview.html`, option A.
- The pill stands up: 32 pt wide, round ends. Default place: middle of the right screen edge.
- Dragging keeps working. On release it snaps to the nearest side edge (left or right), keeping
  its height.
- Waiting: mic icon. Listening: red dot, vertical wave, timer, Pause button, Stop button.
  Paused: amber dot, dim wave, timer, Resume button, Stop button. Finishing: spinner.
- Messages ("Copied · ⌘V to paste", errors) open as a small label beside the pill, toward the
  screen.
- Buttons must be hit by the mouse. Clicking the pill outside a button keeps today's behavior.
- The panel never takes focus.

## T7. Final check

Bench again, save `docs/plans/bench-final.txt`. Build and all tests pass.
