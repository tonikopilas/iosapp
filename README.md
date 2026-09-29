# Chordflow — native iOS app

A SwiftUI app for writing songs on guitar, built from the Claude Design prototype in
`project/Chordflow.dc.html`. It has a dark ambient stage with light cards, a
`#FF3B5C` accent, and real synthesized guitar sound.

## Open & run

1. Open `Chordflow.xcodeproj` in **Xcode 16 or newer**.
2. Choose your team under *Signing & Capabilities* (the bundle id is `com.chordflow.app`; change it if you need to).
3. Run on an iPhone or the simulator. The app needs **iOS 17+** and runs in portrait on iPhone only.

The project uses a folder-synchronized group. Any file you add under `Chordflow/` is picked up automatically.

## What's inside

| Screen | What it does |
|---|---|
| **Song** | Section cards made of chord chips. Tap a chip to hear it, tap it again to edit it. Hold and drag a chip to move it, even into another section. Each chip shows its length in bars, and a red dot marks chords outside the key. Each section's **•••** menu can rename, repeat (×2, ×3, ×4, ×8), duplicate, move or delete the section. |
| **Neck** | Fretboard that switches between chord shape and full scale, with animated finger dots. You can change the chord type and step through the chords. |
| **Key** | Circle of fifths, transpose, mode picker, scale notes and the chords in the key. |
| **Next** | Suggestions for the next chord, with a reason for each and the notes it shares with the current chord. |
| **Chord editor** | Change the root, the type and the length (½, 1, 2, 3 or 4 bars). You can also duplicate or delete the chord. |
| **Song setup** (sliders icon) | Tempo (slider, ± buttons, tap tempo), time signature (2/4, 3/4, 4/4, 6/8), key and mode, sound (Guitar, Keys, Pad), playing style (Strum, Pulse, Arpeggio, Block), metronome click, count-in and note colours. |
| **Your songs** (list icon) | Every saved song. Songs save automatically while you edit. Start a new song from a template (Blank, Pop, Ballad, 12-bar blues, Waltz), or open, duplicate or delete a saved one. |

The mini-player has play/pause, a song/section loop switch, beat pills for the current bar and a bar counter for long chords.

## Code map

```
Chordflow/
  App/ChordflowApp.swift        entry point; injects SongStore
  Model/Theory.swift            pitch classes, modes, qualities, roman numerals, voicing search
  Model/Palette.swift           circle-of-fifths hues, OKLCH → Display P3 colors, design tokens
  Model/SongStore.swift         @Observable state + all actions (playback clock, editing, transposing)
  Model/Suggestions.swift       "what comes next" logic
  Model/SongLibrary.swift       JSON save/load (Application Support/Songs) and templates
  Audio/GuitarSynth.swift       AVAudioEngine synth: detuned saw+triangle, sweeping low-pass, echo, click bus
  Views/                        RootView (stage, header, tabs, pager, toast), Song/Neck/Key/Next panels, MiniPlayer
  Resources/                    Onest + JetBrains Mono fonts (OFL), asset catalog
Config/Info.plist               font registration (merged with generated Info.plist)
```

## Differences from the web prototype

- **Reordering** uses the system drag and drop: hold a chip until it lifts, then drag it anywhere, even into another section. Scrolling stays smooth.
- **Status bar and home indicator** come from the system; the prototype's `ios-frame.jsx` bezel isn't needed.
- **Blur and glass** use system materials (`.ultraThinMaterial`) with the design's tint on top.
- **Songs are saved** as JSON files, which the prototype didn't do.
- **Lyrics were removed** from the chord chips.

---

## Design handoff bundle

`project/` holds the original HTML/JS prototype, and `chats/` holds the design conversation it came from. Read the transcripts for intent. `project/Chordflow.dc.html` is the primary design.
