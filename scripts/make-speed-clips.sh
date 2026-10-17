#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/TestClips/speed"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$output"

printf '{\n  "clips": [\n' > "$output/manifest.json"
separator=""

make_clip() {
    local seconds="$1"
    local text="$2"
    local file="en-${seconds}s.wav"

    say -v Samantha -r 140 -o "$temporary/clip.aiff" "$text"
    afconvert -f WAVE -d LEI16@16000 -c 1 "$temporary/clip.aiff" "$output/$file"
    printf '%s    { "file": "%s", "group": "english", "language": "english", "expected": "%s" }' \
        "$separator" "$file" "$text" >> "$output/manifest.json"
    separator=$',\n'
}

make_clip 3 'Please send the updated notes before our next meeting.'

make_clip 20 'I reviewed the project this morning and wrote down a few changes for the next release. Please update the welcome screen, check the search results, and make sure the settings are saved when the app closes. We can review everything together tomorrow afternoon and decide which changes are ready to share with the team.'

make_clip 45 'Before we start the next round of testing, I want to explain how the new recording flow should work. Press the key to begin speaking, then release it when you have finished your thought. The app should turn the recording into text, remove repeated words, and keep the meaning of the original message. If you switch to another window while it is working, the result should still be available on the clipboard. Please try a short reminder, a longer message to a colleague, and a paragraph with several sentences. Write down how long each example takes and whether any words are missing. After that, compare the results with the previous version so we can see which changes helped and which parts still need attention.'

make_clip 75 'Today I would like to walk through the plan for our next product review. We will begin with the welcome screen and check that a new user can understand what to do without reading a long set of instructions. Then we will open the main window, search for a recent item, and confirm that the results stay in the expected order. After that, we will test the recording feature with several different messages. The first message should be a quick reminder about a meeting. The second should describe a problem and suggest a practical next step. The final message should be long enough to include a few pauses, some punctuation, and a change of topic. For every example, note the time between finishing the recording and seeing the completed text. Check the words carefully, because a fast result is only useful when it preserves what the speaker meant. If anything looks wrong, save the original recording and write a short explanation of what happened. We can use those examples to repeat the same checks after the next update. At the end of the review, we will compare our notes, choose the most important remaining issues, and agree on what needs to be ready before the release goes out to the wider team.'

printf '\n  ]\n}\n' >> "$output/manifest.json"
