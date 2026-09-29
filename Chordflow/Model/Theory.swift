import Foundation

/// Music theory primitives: pitch classes, modes, chord qualities, roman numerals and guitar voicings.

@inline(__always) func m12(_ n: Int) -> Int { ((n % 12) + 12) % 12 }

enum Theory {
    static let sharp = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let flat = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    static let roman = ["I", "II", "III", "IV", "V", "VI", "VII"]
    /// Standard tuning, low E to high E, as MIDI notes.
    static let tuning = [40, 45, 50, 55, 59, 64]
    static let fifths = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]
    static let circleMajor = ["C", "G", "D", "A", "E", "B", "F♯", "D♭", "A♭", "E♭", "B♭", "F"]
    static let circleMinor = ["Am", "Em", "Bm", "F♯m", "C♯m", "G♯m", "D♯m", "B♭m", "Fm", "Cm", "Gm", "Dm"]
    /// Interval (semitones) to label.
    static let intervalLabel: [Int: String] = [0: "R", 1: "♭2", 2: "2", 3: "♭3", 4: "3", 5: "4", 6: "♭5", 7: "5", 8: "♯5", 9: "6", 10: "♭7", 11: "7"]
    /// Plain-English interval names by semitones.
    static let intervalName = ["unison", "minor 2nd", "major 2nd", "minor 3rd", "major 3rd", "perfect 4th",
                               "tritone", "perfect 5th", "minor 6th", "major 6th", "minor 7th", "major 7th"]
    /// For each scale degree, the diatonic degrees that make strong next moves.
    static let next: [[Int]] = [[3, 4, 5, 1], [4, 3, 0, 5], [5, 3, 1, 0], [4, 0, 1, 5], [0, 5, 3, 2], [3, 1, 4, 2], [0, 2, 5, 4]]
    static let reason = [
        "Resolves home. Feels like arriving.",
        "Sets up a lift into the V.",
        "A soft sideways step. Dreamy.",
        "Opens up. Bright and hopeful.",
        "Builds tension that wants to go home.",
        "The bittersweet turn.",
        "Edgy. Leans hard back home.",
    ]
    static let sectionNames = ["Pre-Chorus", "Chorus", "Verse 2", "Outro", "Intro"]
    private static let majorSteps = [0, 2, 4, 5, 7, 9, 11]

    /// Roman numeral for a chord `off` semitones above the key root.
    static func numeral(_ off: Int, _ q: Quality, _ mode: Mode) -> String {
        let iv = mode.intervals
        var d = iv.firstIndex(of: off) ?? -1
        var pre = ""
        if d < 0 {
            if let j = majorSteps.firstIndex(of: m12(off + 1)) {
                pre = "♭"; d = j
            } else {
                pre = "♯"; d = max(0, majorSteps.firstIndex(of: m12(off - 1)) ?? -1)
            }
        }
        var r = roman[d]
        if q.lowercaseNumeral { r = r.lowercased() }
        return pre + r + q.numeralSuffix
    }

    struct DiatonicChord { let off: Int; let degree: Int; let q: Quality }

    static func diatonic(_ mode: Mode) -> [DiatonicChord] {
        let iv = mode.intervals
        return iv.enumerated().map { d, r in
            let third = m12(iv[(d + 2) % 7] - r), fifth = m12(iv[(d + 4) % 7] - r)
            let q: Quality = third == 3 ? (fifth == 6 ? .dim : .min) : .maj
            return DiatonicChord(off: r, degree: d, q: q)
        }
    }

    // MARK: Voicings

    private static var voicingCache: [String: [[Int]]] = [:]

    /// Finds a playable six-string voicing (-1 = muted string) for the chord.
    /// Searches 4-fret windows up the neck and scores for low position, compactness and open strings.
    /// With `bass`, the lowest string played must sound that note (inversions and slash chords).
    static func voicing(_ root: Int, _ q: Quality, bass: Int? = nil) -> [Int] {
        let all = search(root, q, bass: bass)
        if let first = all.first { return first }
        if bass != nil { return voicing(root, q) }
        return [-1, -1, -1, -1, -1, -1]
    }

    /// Playable shapes up the neck, best first (one per neck position).
    static func voicings(_ root: Int, _ q: Quality, bass: Int? = nil) -> [[Int]] {
        search(root, q, bass: bass)
    }

    /// Lowest fretted fret of a shape, or 0 for open-position shapes.
    static func position(_ v: [Int]) -> Int {
        let fretted = v.filter { $0 > 0 }
        guard let mn = fretted.min() else { return 0 }
        return v.contains(0) || mn <= 1 ? 0 : mn
    }

    /// "x32010" style label.
    static func shapeString(_ v: [Int]) -> String {
        v.map { $0 < 0 ? "x" : ($0 > 9 ? "(\($0))" : "\($0)") }.joined()
    }

    private static func search(_ root: Int, _ q: Quality, bass: Int?) -> [[Int]] {
        let low = m12(bass ?? root)
        let key = "\(root)\(q.rawValue)/\(low)"
        if let v = voicingCache[key] { return v }
        let chordPcs = q.intervals.map { m12(root + $0) }
        let pcs = chordPcs.contains(low) ? chordPcs : chordPcs + [low]
        let fifth = m12(root + 7)
        var need = chordPcs.count >= 4 && chordPcs.contains(fifth) && low != fifth
            ? chordPcs.filter { $0 != fifth } : chordPcs
        if !need.contains(low) { need.append(low) }
        let topMuteOK = q == .power
        var found: [(score: Double, v: [Int])] = []
        var cur = [Int](repeating: -1, count: 6)

        for s in 0...9 {
            var win = [0]
            for f in max(1, s)...(s + 3) { win.append(f) }
            let cands = tuning.map { t in [-1] + win.filter { pcs.contains(m12(t + $0)) } }
            var best: [Int]?
            var bestScore = -1e9

            func evaluate() {
                guard let fs = cur.firstIndex(where: { $0 >= 0 }), fs <= 2 else { return }
                let ls = cur.lastIndex(where: { $0 >= 0 }) ?? fs
                for j in (fs + 1)..<6 where cur[j] < 0 {
                    if !(topMuteOK && j > ls) { return }
                }
                if topMuteOK && ls - fs < 1 { return }
                guard m12(tuning[fs] + cur[fs]) == low else { return }
                var got = Set<Int>()
                for j in fs...ls { got.insert(m12(tuning[j] + cur[j])) }
                guard need.allSatisfy(got.contains) else { return }
                let fretted = cur.filter { $0 > 0 }
                let mn = fretted.min() ?? 0, mx = fretted.max() ?? 0
                guard mx - mn <= 3 else { return }
                let fingers = fretted.filter { $0 > mn }.count + (fretted.isEmpty ? 0 : 1)
                guard fingers <= 4 else { return }
                let opens = Double(cur.filter { $0 == 0 }.count)
                let openBonus: Double = mn <= 3 ? opens * 2 : -opens * 8
                let reach: Double = Double(6 - fs) * 10 - Double(mn) * 2.5
                let score: Double = reach - Double(mx - mn) * 2 - Double(fingers) * 1.5 + openBonus
                if score > bestScore { bestScore = score; best = cur }
            }
            func rec(_ i: Int) {
                if i == 6 { evaluate(); return }
                for f in cands[i] { cur[i] = f; rec(i + 1) }
            }
            rec(0)
            if let best, !found.contains(where: { $0.v == best }) { found.append((bestScore, best)) }
        }
        // Best shape first, then the rest from the nut up the neck.
        var out: [[Int]] = []
        if let top = found.max(by: { $0.score < $1.score }) {
            out.append(top.v)
            out += found.filter { $0.v != top.v }.map(\.v).sorted { position($0) < position($1) }
        }
        voicingCache[key] = out
        return out
    }
}

enum Mode: String, CaseIterable, Codable, Identifiable {
    case major, minor, dorian, mixolydian
    var id: String { rawValue }

    var name: String {
        switch self {
        case .major: "Major"
        case .minor: "Minor"
        case .dorian: "Dorian"
        case .mixolydian: "Mixolydian"
        }
    }

    var intervals: [Int] {
        switch self {
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian: [0, 2, 4, 5, 7, 9, 10]
        }
    }

    /// Semitones from this mode's root to its relative major root (used for sharp/flat spelling).
    var relative: Int {
        switch self {
        case .major: 0
        case .minor: 3
        case .dorian: 10
        case .mixolydian: 5
        }
    }
}

enum Quality: String, CaseIterable, Codable, Identifiable {
    case maj, min
    case dom7 = "7"
    case maj7, m7, sus2, sus4, dim
    case aug
    case six = "6"
    case m6, add9
    case dom9 = "9"
    case sus47 = "7sus4"
    case m7b5, dim7
    case power = "5"
    var id: String { rawValue }

    var intervals: [Int] {
        switch self {
        case .maj: [0, 4, 7]
        case .min: [0, 3, 7]
        case .dom7: [0, 4, 7, 10]
        case .maj7: [0, 4, 7, 11]
        case .m7: [0, 3, 7, 10]
        case .sus2: [0, 2, 7]
        case .sus4: [0, 5, 7]
        case .dim: [0, 3, 6]
        case .aug: [0, 4, 8]
        case .six: [0, 4, 7, 9]
        case .m6: [0, 3, 7, 9]
        case .add9: [0, 4, 7, 2]
        case .dom9: [0, 4, 7, 10, 2]
        case .sus47: [0, 5, 7, 10]
        case .m7b5: [0, 3, 6, 10]
        case .dim7: [0, 3, 6, 9]
        case .power: [0, 7]
        }
    }

    /// Suffix appended to the root name, e.g. "m", "maj7".
    var suffix: String {
        switch self {
        case .maj: ""
        case .min: "m"
        case .dom7: "7"
        case .maj7: "maj7"
        case .m7: "m7"
        case .sus2: "sus2"
        case .sus4: "sus4"
        case .dim: "°"
        case .aug: "+"
        case .six: "6"
        case .m6: "m6"
        case .add9: "add9"
        case .dom9: "9"
        case .sus47: "7sus4"
        case .m7b5: "m7♭5"
        case .dim7: "°7"
        case .power: "5"
        }
    }

    /// Label on the quality picker.
    var label: String {
        switch self {
        case .maj: "Major"
        case .min: "Minor"
        case .dom7: "7"
        case .dim: "dim"
        case .aug: "aug"
        case .m7b5: "m7♭5"
        case .dim7: "dim7"
        case .power: "Power"
        default: rawValue
        }
    }

    var numeralSuffix: String {
        switch self {
        case .dom7: "7"
        case .maj7: "maj7"
        case .m7: "7"
        case .dim: "°"
        case .sus2: "sus2"
        case .sus4: "sus4"
        case .aug: "+"
        case .six, .m6: "6"
        case .add9: "add9"
        case .dom9: "9"
        case .sus47: "7sus4"
        case .m7b5: "ø7"
        case .dim7: "°7"
        case .power: "5"
        default: ""
        }
    }

    /// Minor-third chords get a lowercase numeral.
    var lowercaseNumeral: Bool { [.min, .m7, .dim, .m6, .m7b5, .dim7].contains(self) }

    var isMajorish: Bool { [.maj, .dom7, .maj7, .sus2, .sus4, .six, .add9, .dom9, .sus47, .power].contains(self) }
    var isMinorish: Bool { [.min, .m7, .m6].contains(self) }

    /// How the interval `i` above the root is named inside this chord ("R", "♭3", "9" …).
    func degreeLabel(_ i: Int) -> String {
        let i = m12(i)
        if i == 2 && (self == .add9 || self == .dom9) { return "9" }
        if i == 9 && self == .dim7 { return "♭♭7" }
        return Theory.intervalLabel[i] ?? "\(i)"
    }

    /// Rough "how fancy" rank, used to prefer simple names when several fit.
    var complexity: Double {
        switch self {
        case .maj, .min: 0
        case .power: 0.3
        case .dom7, .m7, .maj7, .sus4, .sus2, .dim: 0.6
        case .six, .m6, .aug, .add9: 0.9
        case .sus47, .m7b5, .dim7: 1.1
        case .dom9: 1.3
        }
    }
}

struct Chord: Identifiable, Equatable, Codable {
    var id: String
    var root: Int
    var q: Quality
    /// Length in bars (0.5, 1, 2, 4 …).
    var bars: Double = 1
    /// Bass note for inversions and slash chords (nil = the root).
    var bass: Int?
    /// A specific fingering chosen by the player (nil = best shape found automatically).
    var voicing: [Int]?
    /// Overrides the song's playing style for this chord.
    var style: PlayStyle?

    var pitchClasses: [Int] { q.intervals.map { m12(root + $0) } }

    /// The bass note if it differs from the root.
    var slashBass: Int? { bass.flatMap { m12($0) == m12(root) ? nil : m12($0) } }

    /// The shape to show and play.
    var shape: [Int] { voicing ?? Theory.voicing(root, q, bass: slashBass) }

    init(id: String, root: Int, q: Quality, bars: Double = 1) {
        self.id = id; self.root = root; self.q = q; self.bars = bars
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        root = try c.decode(Int.self, forKey: .root)
        q = try c.decode(Quality.self, forKey: .q)
        bars = try c.decodeIfPresent(Double.self, forKey: .bars) ?? 1
        bass = try c.decodeIfPresent(Int.self, forKey: .bass)
        voicing = try c.decodeIfPresent([Int].self, forKey: .voicing)
        style = try c.decodeIfPresent(PlayStyle.self, forKey: .style)
    }
}

struct SongSection: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var chords: [Chord]
    /// How many times the section plays in a row.
    var repeats: Int = 1

    init(id: String, name: String, chords: [Chord], repeats: Int = 1) {
        self.id = id; self.name = name; self.chords = chords; self.repeats = repeats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        chords = try c.decode([Chord].self, forKey: .chords)
        repeats = try c.decodeIfPresent(Int.self, forKey: .repeats) ?? 1
    }

    var bars: Double { chords.reduce(0) { $0 + $1.bars } }
}

/// A chord flattened out of its section, remembering where it lives.
struct PlacedChord: Identifiable, Equatable {
    var chord: Chord
    var sectionID: String
    var id: String { chord.id }
    var root: Int { chord.root }
    var q: Quality { chord.q }
}

enum TimeSignature: String, CaseIterable, Codable, Identifiable {
    case twoFour = "2/4", threeFour = "3/4", fourFour = "4/4", fiveFour = "5/4"
    case sixEight = "6/8", sevenEight = "7/8", twelveEight = "12/8"
    var id: String { rawValue }
    var beatsPerBar: Int {
        switch self {
        case .twoFour: 2
        case .threeFour: 3
        case .fourFour: 4
        case .fiveFour: 5
        case .sixEight: 6
        case .sevenEight: 7
        case .twelveEight: 12
        }
    }
    /// Eighth-note meters count (and click) in eighths.
    var eighthBased: Bool { [.sixEight, .sevenEight, .twelveEight].contains(self) }

    /// Beats that get a medium accent (compound meters pulse in groups of three, 7/8 as 2+2+3).
    func isSecondaryAccent(_ beat: Int) -> Bool {
        switch self {
        case .sixEight, .twelveEight: beat > 0 && beat % 3 == 0
        case .sevenEight: beat == 2 || beat == 4
        case .fiveFour: beat == 3
        case .fourFour: beat == 2
        default: false
        }
    }

    /// What the meter feels like, for the setup sheet.
    var detail: String {
        switch self {
        case .twoFour: "Two quarter-note beats per bar. Marches and polkas: left, right."
        case .threeFour: "Three beats per bar, ONE-two-three. The waltz feel."
        case .fourFour: "Four beats per bar. Most pop, rock and hip-hop lives here."
        case .fiveFour: "Five beats (3+2). Restless and unusual, like \"Take Five\"."
        case .sixEight: "Six eighths felt in two big pulses of three. Rolling, lilting."
        case .sevenEight: "Seven eighths grouped 2+2+3. Limps forward on purpose."
        case .twelveEight: "Twelve eighths in four pulses of three. Slow blues and soul ballads."
        }
    }
}

enum Sound: String, CaseIterable, Codable, Identifiable {
    case guitar, piano, pad
    var id: String { rawValue }
    var label: String {
        switch self {
        case .guitar: "Guitar"
        case .piano: "Keys"
        case .pad: "Pad"
        }
    }
}

enum PlayStyle: String, CaseIterable, Codable, Identifiable {
    case strum, pulse, arpeggio, block
    var id: String { rawValue }
    var label: String {
        switch self {
        case .strum: "Strum"
        case .pulse: "Pulse"
        case .arpeggio: "Arpeggio"
        case .block: "Block"
        }
    }
    var detail: String {
        switch self {
        case .strum: "One strum per chord, let it ring."
        case .pulse: "Down-up strums on every beat."
        case .arpeggio: "Picks the notes one by one."
        case .block: "All notes at once, like a pianist."
        }
    }
}

/// Everything that gets saved for one song.
struct Song: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var key: Int
    var mode: Mode
    var bpm: Int
    var timeSignature: TimeSignature = .fourFour
    var sound: Sound = .guitar
    var style: PlayStyle = .strum
    var sections: [SongSection]
    /// Written-out parts (riffs, solos, arrangements).
    var tabs: [Tab] = []
    /// Milliseconds between strings in a strum.
    var strumSpeed: Double = 24
    /// How long notes ring, as a multiple of their written length.
    var ring: Double = 1
    /// Delays every second eighth note (0 = straight, 1 = full triplet swing).
    var swing: Double = 0
    var updatedAt = Date()

    var totalBars: Double { sections.reduce(0) { $0 + $1.bars * Double($1.repeats) } }

    enum CodingKeys: String, CodingKey {
        case id, title, key, mode, bpm, timeSignature, sound, style, sections, tabs, strumSpeed, ring, swing, updatedAt
    }

    init(id: UUID = UUID(), title: String, key: Int, mode: Mode, bpm: Int, timeSignature: TimeSignature = .fourFour,
         sound: Sound = .guitar, style: PlayStyle = .strum, sections: [SongSection], tabs: [Tab] = [],
         strumSpeed: Double = 24, ring: Double = 1, swing: Double = 0, updatedAt: Date = Date()) {
        self.id = id; self.title = title; self.key = key; self.mode = mode; self.bpm = bpm
        self.timeSignature = timeSignature; self.sound = sound; self.style = style; self.sections = sections
        self.tabs = tabs; self.strumSpeed = strumSpeed; self.ring = ring; self.swing = swing; self.updatedAt = updatedAt
    }

    /// Older files miss newer fields; everything but the id and chords falls back to a default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        key = try c.decodeIfPresent(Int.self, forKey: .key) ?? 0
        mode = (try? c.decodeIfPresent(Mode.self, forKey: .mode)) ?? .major
        bpm = try c.decodeIfPresent(Int.self, forKey: .bpm) ?? 96
        timeSignature = (try? c.decodeIfPresent(TimeSignature.self, forKey: .timeSignature)) ?? .fourFour
        sound = (try? c.decodeIfPresent(Sound.self, forKey: .sound)) ?? .guitar
        style = (try? c.decodeIfPresent(PlayStyle.self, forKey: .style)) ?? .strum
        sections = try c.decode([SongSection].self, forKey: .sections)
        tabs = (try? c.decodeIfPresent([Tab].self, forKey: .tabs)) ?? []
        strumSpeed = try c.decodeIfPresent(Double.self, forKey: .strumSpeed) ?? 24
        ring = try c.decodeIfPresent(Double.self, forKey: .ring) ?? 1
        swing = try c.decodeIfPresent(Double.self, forKey: .swing) ?? 0
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

/// "½", "1", "2", "1½", "¾" …
func formatBars(_ b: Double) -> String {
    let whole = Int(b + 0.0001)
    let frac = b - Double(whole)
    let fracs: [(Double, String)] = [(0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾")]
    let part = fracs.first { abs($0.0 - frac) < 0.02 }?.1 ?? ""
    if whole == 0 { return part.isEmpty ? "0" : part }
    return "\(whole)" + part
}
