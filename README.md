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

| Panel | What it does |
|---|---|
| **Song** | Verse, Chorus and Bridge cards made of chord chips. Tap a chip to hear it. Hold and drag to reorder it within its section. A red dot marks chords outside the key. While playing, the current chip lights up and a bar fills across it on each beat. Use **Suggest** to add a chord to a section and **Add section** to add a new section. |
| **Neck** | Fretboard that switches between *Chord shape* and *Full scale*. Finger dots spring to their new frets with a staggered animation and glow on each strum. You can change the chord quality, step to the previous or next chord, and tap any dot to hear that note. |
| **Key** | Circle of fifths where the chords in your key are lit. Tap a wedge to move the whole song to that key, or transpose it up or down. Also shows the mode picker, the scale notes and the chords in the key (tap to hear, **+** to add). |
| **Next** | Suggestions for the next chord: strong diatonic moves, plus borrowed or spicy options. Each one has a short reason and shows the notes it shares with the current chord. Tap to hear one and **Add** to drop it in. |

The mini-player at the bottom has play/pause, a song/section loop switch and beat pills. Tempo and the metronome **Click** sit in the header. Swipe between panels or tap the tabs.

**Settings:** *Beats per chord* (2/4/8, default 8) and *Color notes* are in the iOS Settings app under Chordflow (`Settings.bundle`). These are the two settings from the prototype.

## Code map

```
Chordflow/
  App/ChordflowApp.swift        entry point; injects SongStore
  Model/Theory.swift            pitch classes, modes, qualities, roman numerals, voicing search
  Model/Palette.swift           circle-of-fifths hues, OKLCH → Display P3 colors, design tokens
  Model/SongStore.swift         @Observable state + all actions (playback clock, editing, transposing)
  Model/Suggestions.swift       "what comes next" logic
  Audio/GuitarSynth.swift       AVAudioEngine synth: detuned saw+triangle, sweeping low-pass, echo, click bus
  Views/                        RootView (stage, header, tabs, pager, toast), Song/Neck/Key/Next panels, MiniPlayer
  Resources/                    Onest + JetBrains Mono fonts (OFL), asset catalog, Settings.bundle
Config/Info.plist               font registration (merged with generated Info.plist)
```

## Differences from the web prototype

- **Reordering** uses the iOS pattern: hold a chip until it lifts (with a haptic), then drag it. A plain swipe still scrolls and pages normally. This avoids the prototype's conflict between dragging and scrolling on touch screens.
- **Status bar and home indicator** come from the system; the prototype's `ios-frame.jsx` bezel isn't needed.
- **Blur and glass** use system materials (`.ultraThinMaterial`) with the design's tint on top.
- **Song data is not saved** between launches. The prototype didn't save it either.

---

## Design handoff bundle

`project/` holds the original HTML/JS prototype, and `chats/` holds the design conversation it came from. Read the transcripts for intent. `project/Chordflow.dc.html` is the primary design.
