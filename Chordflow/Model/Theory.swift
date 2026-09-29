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
    static let intervalLabel: [Int: String] = [0: "R", 2: "2", 3: "♭3", 4: "3", 5: "4", 6: "♭5", 7: "5", 10: "♭7", 11: "7"]
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
        if [.min, .m7, .dim].contains(q) { r = r.lowercased() }
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

    private static var voicingCache: [String: [Int]] = [:]

    /// Finds a playable six-string voicing (-1 = muted string) for the chord.
    /// Searches 4-fret windows up the neck and scores for low position, compactness and open strings.
    static func voicing(_ root: Int, _ q: Quality) -> [Int] {
        let key = "\(root)\(q.rawValue)"
        if let v = voicingCache[key] { return v }
        let pcs = q.intervals.map { m12(root + $0) }
        let need = pcs.count == 4 ? pcs.enumerated().filter { $0.offset != 2 }.map(\.element) : pcs
        var best: [Int]?
        var bestScore = -1e9
        var cur = [Int](repeating: -1, count: 6)

        for s in 0...9 {
            var win = [0]
            for f in max(1, s)...(s + 3) { win.append(f) }
            let cands = tuning.map { t in [-1] + win.filter { pcs.contains(m12(t + $0)) } }

            func evaluate() {
                guard let fs = cur.firstIndex(where: { $0 >= 0 }), fs <= 2 else { return }
                for j in (fs + 1)..<6 where cur[j] < 0 { return }
                guard m12(tuning[fs] + cur[fs]) == root else { return }
                var got = Set<Int>()
                for j in fs..<6 { got.insert(m12(tuning[j] + cur[j])) }
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
        }
        let v = best ?? [-1, -1, -1, -1, -1, -1]
        voicingCache[key] = v
        return v
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
        }
    }

    /// Label on the quality picker.
    var label: String {
        switch self {
        case .maj: "Major"
        case .min: "Minor"
        case .dom7: "7"
        case .dim: "dim"
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
        default: ""
        }
    }

    var isMajorish: Bool { [.maj, .dom7, .maj7, .sus2, .sus4].contains(self) }
    var isMinorish: Bool { [.min, .m7].contains(self) }
}

struct Chord: Identifiable, Equatable, Codable {
    var id: String
    var root: Int
    var q: Quality
    var lyric: String = ""

    var pitchClasses: [Int] { q.intervals.map { m12(root + $0) } }
}

struct SongSection: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var chords: [Chord]
}

/// A chord flattened out of its section, remembering where it lives.
struct PlacedChord: Identifiable, Equatable {
    var chord: Chord
    var sectionID: String
    var id: String { chord.id }
    var root: Int { chord.root }
    var q: Quality { chord.q }
}
