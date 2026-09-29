import Foundation

/// Short theory lessons shown from the ⓘ buttons and the handbook.
enum LearnTopic: String, CaseIterable, Identifiable {
    case notes, intervals, chords, qualities, key, modes, numerals, circle, functions, borrowed
    case voicings, inversions, tempo, meter, bars, styles, tab, noteValues, keyFinding, chordFinder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: "The 12 notes"
        case .intervals: "Intervals"
        case .chords: "How chords are built"
        case .qualities: "Chord types"
        case .key: "What a key is"
        case .modes: "Major, minor & modes"
        case .numerals: "Roman numerals"
        case .circle: "The circle of fifths"
        case .functions: "Home, away, tension"
        case .borrowed: "Borrowed chords"
        case .voicings: "Shapes & positions"
        case .inversions: "Inversions & slash chords"
        case .tempo: "Tempo"
        case .meter: "Time signatures"
        case .bars: "Bars & beats"
        case .styles: "Playing styles"
        case .tab: "Reading tab"
        case .noteValues: "Note lengths"
        case .keyFinding: "How the key is guessed"
        case .chordFinder: "Naming what you play"
        }
    }

    var symbol: String {
        switch self {
        case .notes, .intervals: "pianokeys"
        case .chords, .qualities, .inversions: "square.stack.3d.up"
        case .key, .modes, .keyFinding: "key"
        case .numerals, .functions, .borrowed: "arrow.triangle.branch"
        case .circle: "circle.dashed"
        case .voicings, .chordFinder: "hand.point.up.left"
        case .tempo, .meter, .bars, .noteValues: "metronome"
        case .styles: "guitars"
        case .tab: "music.note.list"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .notes:
            ["Western music uses 12 notes that repeat in every octave: C, C♯/D♭, D, D♯/E♭, E, F, F♯/G♭, G, G♯/A♭, A, A♯/B♭, B.",
             "The distance between two neighbours is a semitone. On the guitar that's one fret. Twelve frets up, the string plays the same note an octave higher, which is why the 12th fret has a double dot.",
             "A sharp (♯) raises a note by a semitone and a flat (♭) lowers it. C♯ and D♭ are the same sound; the key decides which name reads better.",
             "In Chordflow every note keeps its own colour, picked by its place on the circle of fifths, so notes that sound related look related."]
        case .intervals:
            ["An interval is the distance between two notes, counted in semitones.",
             "3 = minor third (dark), 4 = major third (bright), 5 = perfect fourth, 7 = perfect fifth (strong, open), 10 = minor seventh (bluesy), 11 = major seventh (dreamy), 12 = octave.",
             "Thirds decide whether a chord sounds major or minor. Fifths make it solid. Sevenths and ninths add colour.",
             "On the fretboard: two frets higher on the same string is a whole tone; the same fret one string higher is usually a fourth (5 semitones), except from G to B, which is a major third."]
        case .chords:
            ["A chord is three or more notes played together. The simplest, a triad, stacks two thirds on a root: root, third, fifth.",
             "C major = C (root) + E (major third, 4 semitones up) + G (perfect fifth, 7 up).",
             "Guitar shapes repeat these notes on several strings. A six-string C chord (x32010) plays C, E, G, C, E: still just three different notes.",
             "Add a fourth note a third above the fifth and you get a seventh chord, which is richer and more restless."]
        case .qualities:
            ["Major: bright, settled. Minor: darker, emotional. Both are triads.",
             "7 (dominant): major triad + ♭7. Bluesy and pulls strongly to the chord a fifth below. maj7: soft, jazzy, dreamy. m7: mellow minor.",
             "sus2 / sus4: the third is replaced by a 2nd or 4th, so the chord is neither major nor minor. It sounds open and wants to resolve back.",
             "dim (°): two minor thirds. Tense and unstable, great as a passing chord. aug (+): two major thirds. Eerie, lifts upward.",
             "6, add9, 9: colour on top of a major chord. m7♭5 (half-diminished) and °7 are classic tension chords in minor keys.",
             "5 (power chord): just root and fifth. No third, so it fits major and minor and stays clean under distortion."]
        case .key:
            ["A key is a home note plus a family of seven notes (a scale) that sound good with it.",
             "In G major the family is G A B C D E F♯. Chords built only from these notes are \"in the key\" and always fit together.",
             "Chords that use notes outside the family get a red dot on the Song tab. They are not wrong. They add colour, but they pull the ear away from home.",
             "Transposing moves every chord by the same distance, so the song keeps its sound but sits higher or lower, for example to suit a singer."]
        case .modes:
            ["Major (Ionian): happy, resolved. Scale steps W W H W W W H.",
             "Minor (Aeolian): sad or serious. The ♭3, ♭6 and ♭7 make it darker.",
             "Dorian: minor with a raised 6th. Cool and soulful; think funk, jazz and \"Oye Como Va\".",
             "Mixolydian: major with a ♭7. Bluesy rock; the ♭VII chord (F in G) is its signature.",
             "Switching mode keeps the home note but changes which chords belong. Try the Scale card on the Key tab and watch the chord tiles change."]
        case .numerals:
            ["Roman numerals name a chord by its step in the key: I is built on the 1st note, IV on the 4th, V on the 5th.",
             "Uppercase = major (I, IV, V). Lowercase = minor (ii, iii, vi). ° = diminished (vii°).",
             "Numerals let you think in patterns: I–V–vi–IV is the same progression in any key. In C it's C–G–Am–F; in G it's G–D–Em–C.",
             "A ♭ or ♯ in front (♭VII, ♭VI) means the chord is borrowed from outside the key."]
        case .circle:
            ["The circle of fifths lines up the 12 keys so each is a fifth above the one before: C → G → D → A …",
             "Neighbours on the circle share six of their seven notes, so moving to a neighbour sounds smooth. Jumping across the circle sounds dramatic.",
             "The inner ring shows each major key's relative minor (C major ↔ A minor). They use exactly the same notes and just start from a different home.",
             "In any key the I, IV and V chords sit side by side on the circle. That's why they're the backbone of so many songs."]
        case .functions:
            ["Chords do jobs. Tonic (I, vi, iii) feels like home. Subdominant (IV, ii) moves away. Dominant (V, vii°) creates tension that wants to go home.",
             "The strongest pull in music is V → I (a cadence). Ending a section on V leaves the listener hanging; ending on I closes the door.",
             "\"Strong moves\" on the Next tab follow these jobs. The number of shared notes tells you how smooth the change will feel: more shared notes means a gentler move."]
        case .borrowed:
            ["Borrowed chords come from the parallel key: same home note, other mode. In C major you can borrow from C minor: A♭ (♭VI), B♭ (♭VII), Fm (iv).",
             "They give an instant emotional shift: ♭VII sounds anthemic, iv sounds nostalgic, ♭VI sounds cinematic.",
             "Secondary dominants (like E7 in C major, V of vi) briefly treat another chord as home, making the next chord land harder."]
        case .voicings:
            ["The same chord can be played in many places on the neck. Each is a voicing (or shape).",
             "Open shapes near the nut ring with open strings. Barre shapes use one finger across several strings and can slide anywhere.",
             "Higher positions sound thinner and brighter; low positions sound full. Pick a position that keeps your hand close to the next chord.",
             "× means don't play that string. ○ means play it open."]
        case .inversions:
            ["The bass is the lowest note you hear. Usually it's the root; when it isn't, the chord is inverted.",
             "1st inversion = third in the bass (C/E). 2nd inversion = fifth in the bass (C/G). With a seventh chord there's a 3rd inversion (C7/B♭).",
             "Inversions make bass lines walk smoothly: C – G/B – Am is a classic descending line.",
             "A slash chord can also put any note in the bass (D/C). The name reads chord / bass note."]
        case .tempo:
            ["Tempo is speed in beats per minute (BPM).",
             "Rough guide: 60–76 Adagio (slow ballad), 76–108 Andante/Moderato (walking pace), 108–132 Allegro (upbeat pop), 132+ Presto (punk, drum & bass).",
             "Tap tempo: tap along with a song you like and Chordflow averages your taps."]
        case .meter:
            ["The time signature tells you how beats are grouped. The top number is how many, the bottom is which note gets the beat (4 = quarter, 8 = eighth).",
             "4/4 counts 1-2-3-4. 3/4 counts 1-2-3 (waltz). 6/8 is six eighths felt as two big pulses: ONE-and-a TWO-and-a.",
             "Odd meters like 5/4 and 7/8 group beats unevenly (3+2, 2+2+3). The click accents the group starts so you can feel them."]
        case .bars:
            ["A bar (or measure) is one cycle of the time signature. In 4/4 a bar is four beats.",
             "Songs are built from phrases of 2, 4 or 8 bars. If a section feels too short or long, check that its chords add up to a round number of bars.",
             "Chords can last half a bar, one bar or several. Changing chords every bar feels busy; every two bars feels relaxed.",
             "Use − and + on a selected chord to change its length quickly, or open the chord for beat-by-beat control."]
        case .styles:
            ["Strum: one stroke per chord that rings out. Good for sketching.",
             "Pulse: down and up strums on every beat, like a rhythm guitarist.",
             "Arpeggio: the chord's notes picked one at a time. Soft and flowing.",
             "Block: all notes at once, like a piano. Every chord can override the song's style in its editor."]
        case .tab:
            ["Tablature shows where to put your fingers, not which note it is. Six lines = six strings, with the high E on top (the string closest to the floor).",
             "A number on a line is the fret to press: 0 means open string, 3 means third fret.",
             "Numbers stacked in the same column are played together: a double stop or a chord.",
             "Chordflow's tab also stores rhythm. Each column has a length (quarter, eighth …), and bar lines follow the song's time signature."]
        case .noteValues:
            ["Whole = 4 beats, half = 2, quarter = 1, eighth = ½, sixteenth = ¼ (in 4/4).",
             "A dot adds half the value again: a dotted quarter = 1½ beats.",
             "A triplet squeezes three notes into the time of two: three eighth-triplets fill one beat.",
             "A rest is silence with a length. Rests are as important as notes for groove."]
        case .keyFinding:
            ["Chordflow counts how long each note sounds in your tab (notes on the beat count a bit more) and compares that to a profile of every major and minor key.",
             "The profile says which notes a key uses most: its home note, then the fifth, then the third.",
             "The best match is a good guess, not a verdict. A short riff can fit two keys, often a major key and its relative minor."]
        case .chordFinder:
            ["Find mode names the chord your fingers make. Tap one fret per string; tap again to mute a string.",
             "Chordflow tries every note you play as the root and every chord type, and keeps names that explain all the notes. The fifth may be left out, as guitarists often do.",
             "When the lowest note isn't the root you get a slash chord, like C/E.",
             "For melodies in the tab, each bar gets the chord that explains most of its notes, weighted by how long they ring."]
        }
    }

    var related: [LearnTopic] {
        switch self {
        case .notes: [.intervals, .circle]
        case .intervals: [.chords, .notes]
        case .chords: [.qualities, .inversions, .intervals]
        case .qualities: [.chords, .functions]
        case .key: [.modes, .numerals, .circle]
        case .modes: [.key, .borrowed]
        case .numerals: [.functions, .key]
        case .circle: [.key, .functions]
        case .functions: [.numerals, .borrowed]
        case .borrowed: [.modes, .functions]
        case .voicings: [.inversions, .chordFinder]
        case .inversions: [.voicings, .chords]
        case .tempo: [.meter, .bars]
        case .meter: [.bars, .noteValues]
        case .bars: [.meter, .noteValues]
        case .styles: [.tempo]
        case .tab: [.noteValues, .keyFinding]
        case .noteValues: [.meter, .tab]
        case .keyFinding: [.key, .chordFinder]
        case .chordFinder: [.chords, .inversions]
        }
    }

    /// Chapters for the handbook.
    static let chapters: [(title: String, topics: [LearnTopic])] = [
        ("Sound", [.notes, .intervals]),
        ("Chords", [.chords, .qualities, .inversions, .voicings, .chordFinder]),
        ("Keys & harmony", [.key, .modes, .circle, .numerals, .functions, .borrowed]),
        ("Rhythm", [.tempo, .meter, .bars, .noteValues, .styles]),
        ("Writing tab", [.tab, .keyFinding]),
    ]
}

/// Explanations built from the actual song.
extension SongStore {
    /// "G major: root G, major 3rd B, 5th D. It's the I chord: home base."
    func explain(_ c: Chord) -> String {
        let tones = c.q.intervals.map { "\(c.q.degreeLabel($0)) \(name(c.root + $0))" }.joined(separator: ", ")
        let what = "\(chordName(c)) is built from \(tones)."
        let bassNote = c.slashBass.map { " \(name($0)) in the bass" + (c.pitchClasses.contains($0) ? " makes it an inversion." : ", a note outside the chord, colours it.") } ?? ""
        return what + bassNote + " " + role(c.root, c.q)
    }

    /// The chord's job in the current key.
    func role(_ root: Int, _ q: Quality) -> String {
        let off = m12(root - key)
        let num = numeral(root, q)
        guard let degree = mode.intervals.firstIndex(of: off) else {
            return "\(num) isn't in \(keyName): it's borrowed from outside the key, so it adds surprise."
        }
        let diatonic = Theory.diatonic(mode)[degree]
        let fits = q.intervals.allSatisfy { mode.intervals.contains(m12(off + $0)) }
        let job: String = switch degree {
        case 0: "the home chord. Songs usually start or end here."
        case 4: "the dominant. It builds tension that wants to resolve home to \(name(key))."
        case 3: "the subdominant. It steps away from home and sounds open and hopeful."
        case 5: "the relative \(mode == .major ? "minor" : "major"). It sounds like home, but bittersweet."
        case 1: "a pre-dominant. It loves to lead into the V chord."
        case 2: "a soft sideways step that shares two notes with the home chord."
        default: "a tense, unstable chord that leans back home."
        }
        let note = fits ? "" : " This \(q.label.lowercased()) version adds notes outside the key (the key's own chord here is \(chordName(root, diatonic.q)))."
        return "As \(num) in \(keyName), it's \(job)\(note)"
    }

    var modeBlurb: String {
        switch mode {
        case .major: "Major: bright and resolved. The chords I, IV and V are major; ii, iii and vi are minor."
        case .minor: "Natural minor: darker and more serious. i, iv and v are minor; ♭III, ♭VI and ♭VII are major."
        case .dorian: "Dorian: minor, but the major IV chord (raised 6th) keeps it hopeful. Funk and soul love it."
        case .mixolydian: "Mixolydian: major with a flat 7th, so ♭VII is major. Classic rock and blues sound."
        }
    }

    var tempoName: String {
        switch bpm {
        case ..<60: "Largo · very slow"
        case ..<76: "Adagio · slow"
        case ..<108: "Andante · walking pace"
        case ..<120: "Moderato · relaxed"
        case ..<156: "Allegro · lively"
        case ..<176: "Vivace · fast"
        default: "Presto · very fast"
        }
    }
}
