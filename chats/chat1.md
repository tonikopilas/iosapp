# Music creator app design

_Started 2026-09-29 16:41 UTC_

---

## User

Music creator app when creating songs
Like oolimo.com
Everything is fluid and showing user whats going with it and so on

## Assistant



## Assistant

_[tool: ask_user]_

I've put up a short form about features, instrument, theme and platform. Answer what you like and I'll decide the rest.

## User

Answered — Asked for follow-up questions; core: Chord progression builder, Scale / key explorer, Fretboard (guitar), Chord suggestions (what fits next), Song sections (verse/chorus), Lyrics alongside chords, Circle of fifths; instrument: Guitar; user: Hobbyists; fluid: Notes light up as chords play, Animated transitions between chords, Drag-to-reorder chords; platform: Mobile; variations: One polished prototype

## Assistant



## Assistant

_[tool: ask_user]_

_[tool: ask_user]_

I've added a few follow-up questions: how the screens are organized, whether chords play real sound, and how the fretboard displays.

## User

Answered — Asked for follow-up questions; nav: Swipeable panels; audio: Yes, real synthesized sound; fret_view: Toggle between both; open_q: 1. Use design like oolimo.com, spotify, apple  2. Must be different  3. Dont use nocturno i organic design system

## Assistant



## Assistant

_[tool: ask_user]_

Since you don't want either attached design system, I've added three visual-direction questions: dark or light, which style is closest, and an accent color.

## User

Answered — mode: Dark with light cards; feel: Apple Music — glassy blur, big bold type, vivid album-like color; accent: #FF3B5C

## Assistant

_[tool: copy_starter_component]_

_[tool: grep]_

_[tool: read_file]_

_[tool: list_files]_

_[tool: dc_write]_

## Assistant

_[tool: grep]_

_[tool: dc_write]_

Now the logic.

_[tool: dc_js_str_replace]_

_[tool: show_html]_

_[tool: ready_for_verification]_

I built **Chordflow**, a phone-sized prototype you can play. It uses a dark background with blurred colour, light cards and a pink-red accent. Chords make real synthesized guitar sound. A check is still running in the background, and I haven't looked at the result myself yet.

Swipe between four panels, or tap the tabs at the top:
- **Song:** Verse, Chorus and Bridge cards, each chord with its own lyric line. Tap a chord to hear it, drag to reorder, and a red dot marks chords outside the key. While playing, the current chord lights up and a bar fills across it on each beat.
- **Neck:** a guitar fretboard that switches between the chord shape and the full scale. Finger dots slide to their new frets when the chord changes and light up on each strum. You can also change the chord type (minor, 7, sus and so on).
- **Key:** a circle of fifths where the chords in your key are lit. Tap a key to move the whole song there, or transpose it up or down. It also shows the scale and the chords that belong to the key.
- **Next:** suggestions for what chord could follow, with a short reason for each and the notes it shares with the current chord. Tap to hear one, then add it with one tap.

A mini-player at the bottom has play/pause, a loop switch (whole song or one section) and beat dots. Tempo and the metronome click sit in the header.

You can adjust two settings: beats per chord, and whether notes are coloured or plain.

Two limits: dragging chords only works within a section, and on touch screens it works best as a sideways drag.

