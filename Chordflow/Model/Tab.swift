import Foundation

/// Written-out guitar parts: positions on the neck placed in time.

/// Durations are counted in ticks: a quarter note is 24, so dotted notes and triplets stay whole numbers.
enum Ticks {
    static let quarter = 24
    static let whole = 96
}

/// One fretted (or open) string.
struct TabNote: Codable, Equatable, Hashable {
    /// 0 = low E … 5 = high E.
    var string: Int
    var fret: Int

    var midi: Int { Theory.tuning[string] + fret }
    var pc: Int { m12(midi) }
}

/// Everything that starts at the same moment: one note, a double stop, a full chord, or a rest (no notes).
struct TabEvent: Identifiable, Codable, Equatable {
    var id: String
    var notes: [TabNote]
    var ticks: Int

    var isRest: Bool { notes.isEmpty }

    /// Notes low string to high string.
    var sorted: [TabNote] { notes.sorted { $0.string < $1.string } }

    /// Fret span of the fretted notes, open strings don't count.
    var stretch: Int {
        let fr = notes.map(\.fret).filter { $0 > 0 }
        guard let mn = fr.min(), let mx = fr.max() else { return 0 }
        return mx - mn
    }
}

struct Tab: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var events: [TabEvent]

    var totalTicks: Int { events.reduce(0) { $0 + $1.ticks } }
}

/// The note lengths offered in the editor.
enum NoteValue: Int, CaseIterable, Identifiable {
    case whole = 96, half = 48, quarter = 24, eighth = 12, sixteenth = 6
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .whole: "1"
        case .half: "½"
        case .quarter: "¼"
        case .eighth: "⅛"
        case .sixteenth: "1/16"
        }
    }

    var name: String {
        switch self {
        case .whole: "Whole"
        case .half: "Half"
        case .quarter: "Quarter"
        case .eighth: "Eighth"
        case .sixteenth: "16th"
        }
    }

    /// SF Symbol-free glyph drawn as text.
    var glyph: String {
        switch self {
        case .whole: "𝅝"
        case .half: "𝅗𝅥"
        case .quarter: "♩"
        case .eighth: "♪"
        case .sixteenth: "𝅘𝅥𝅯"
        }
    }
}

/// A length split back into base value + dot + triplet, for display.
struct NoteLength: Equatable {
    var value: NoteValue
    var dotted = false
    var triplet = false

    var ticks: Int {
        var t = value.rawValue
        if dotted { t = t * 3 / 2 }
        if triplet { t = t * 2 / 3 }
        return max(1, t)
    }

    var label: String { value.label + (dotted ? "." : "") + (triplet ? "³" : "") }

    static func from(_ ticks: Int) -> NoteLength? {
        for v in NoteValue.allCases {
            for d in [false, true] {
                for t in [false, true] where !(d && t) {
                    let l = NoteLength(value: v, dotted: d, triplet: t)
                    if l.ticks == ticks { return l }
                }
            }
        }
        return nil
    }

    /// "Quarter", "Dotted eighth", "Eighth triplet" or "5 sixteenths".
    static func describe(_ ticks: Int) -> String {
        if let l = from(ticks) {
            return (l.dotted ? "Dotted " + l.value.name.lowercased() : l.value.name) + (l.triplet ? " triplet" : "")
        }
        let six = Double(ticks) / 6
        return six == six.rounded() ? "\(Int(six)) sixteenths" : "\(ticks) ticks"
    }
}

extension TimeSignature {
    /// Ticks per counted beat (quarters, or eighths in eighth-based meters).
    var ticksPerBeat: Int { eighthBased ? Ticks.quarter / 2 : Ticks.quarter }
    var barTicks: Int { beatsPerBar * ticksPerBeat }
}

/// Where an event sits in time.
struct PlacedEvent: Identifiable {
    var index: Int
    var event: TabEvent
    var start: Int
    var bar: Int
    var id: String { event.id }
    var end: Int { start + event.ticks }
}

extension Tab {
    func placed(_ ts: TimeSignature) -> [PlacedEvent] {
        var t = 0
        return events.enumerated().map { i, e in
            defer { t += e.ticks }
            return PlacedEvent(index: i, event: e, start: t, bar: t / ts.barTicks)
        }
    }

    /// Events grouped by the bar they start in.
    func bars(_ ts: TimeSignature) -> [[PlacedEvent]] {
        let p = placed(ts)
        guard let last = p.last else { return [] }
        var out = Array(repeating: [PlacedEvent](), count: last.bar + 1)
        for e in p { out[e.bar].append(e) }
        return out
    }
}

// MARK: - Chord finder

/// A name for a set of notes.
struct ChordMatch: Identifiable, Equatable {
    var root: Int
    var q: Quality
    /// Lowest note, if it isn't the root.
    var bass: Int?
    /// Chord tones not played (usually the fifth).
    var missing: [Int]
    var score: Double
    var id: String { "\(root)\(q.rawValue)/\(bass ?? -1)" }
}

enum ChordFinder {
    /// Names for exactly these notes (MIDI). Every note played must belong to the chord;
    /// only the fifth may be left out. Best match first.
    static func identify(_ midi: [Int]) -> [ChordMatch] {
        guard let lowest = midi.min() else { return [] }
        let pcs = Set(midi.map(m12))
        guard pcs.count >= 2 else { return [] }
        let bass = m12(lowest)
        var out: [ChordMatch] = []
        for root in pcs {
            for q in Quality.allCases {
                let tones = Set(q.intervals.map { m12(root + $0) })
                guard pcs.isSubset(of: tones) else { continue }
                let missing = tones.subtracting(pcs)
                // Only the perfect fifth may be implied, and a power chord needs both notes.
                guard missing.allSatisfy({ $0 == m12(root + 7) }), !(q == .power && !missing.isEmpty) else { continue }
                if missing.count == 1 && tones.count <= 3 && q != .maj && q != .min { continue }
                var score = Double(tones.count - missing.count) * 2 - Double(missing.count) * 1.5 - q.complexity
                if bass == root { score += 2.5 }
                out.append(ChordMatch(root: root, q: q, bass: bass == root ? nil : bass,
                                      missing: Array(missing), score: score))
            }
        }
        return out.sorted { $0.score > $1.score }
    }

    /// Best-fitting chord for a bar of melody: weighted by how long each note sounds.
    /// Notes outside the chord count against it, so passing tones don't flip the answer.
    static func bestFit(weights: [Int: Double], bass: Int?, key: Int, mode: Mode) -> ChordMatch? {
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return nil }
        let scale = Set(mode.intervals.map { m12(key + $0) })
        let pool: [Quality] = [.maj, .min, .dom7, .m7, .maj7, .dim, .sus4, .sus2]
        var best: ChordMatch?
        for root in 0..<12 {
            for q in pool {
                let tones = q.intervals.map { m12(root + $0) }
                let toneSet = Set(tones)
                let inside = weights.filter { toneSet.contains($0.key) }.values.reduce(0, +)
                let outside = total - inside
                // A seventh or sus note must actually be heard to earn the fancier name.
                let colour = tones.count > 3 ? tones[3] : (q == .sus2 || q == .sus4 ? tones[1] : nil)
                if let colour, (weights[colour] ?? 0) < total * 0.15 { continue }
                guard weights[root] != nil || bass == root else { continue }
                let heard = tones.filter { weights[$0] != nil }.count
                var score = inside / total * 3 - outside / total * 2.2 + Double(heard) * 0.25 - q.complexity * 0.5
                if bass == root { score += 0.6 }
                if toneSet.isSubset(of: scale) { score += 0.35 }
                if best == nil || score > best!.score {
                    best = ChordMatch(root: root, q: q, bass: nil, missing: [], score: score)
                }
            }
        }
        return best
    }

    /// "major third", "perfect fifth" … for two notes.
    static func intervalName(_ a: Int, _ b: Int) -> String {
        let d = abs(b - a)
        if d == 12 { return "octave" }
        if d > 12 { return Theory.intervalName[d % 12] + " + octave" }
        return Theory.intervalName[d]
    }
}

// MARK: - Key detection

struct KeyGuess: Identifiable, Equatable {
    var key: Int
    var mode: Mode
    var score: Double
    var id: String { "\(key)\(mode.rawValue)" }
}

enum KeyFinder {
    // Krumhansl–Kessler key profiles.
    private static let major = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minor = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// Correlates how long each pitch class sounds with every major and minor key profile.
    static func guess(_ weights: [Double]) -> [KeyGuess] {
        guard weights.filter({ $0 > 0 }).count >= 3 else { return [] }
        var out: [KeyGuess] = []
        for k in 0..<12 {
            for (mode, profile) in [(Mode.major, major), (Mode.minor, minor)] {
                let rotated = (0..<12).map { profile[m12($0 - k)] }
                out.append(KeyGuess(key: k, mode: mode, score: pearson(weights, rotated)))
            }
        }
        return out.sorted { $0.score > $1.score }
    }

    private static func pearson(_ a: [Double], _ b: [Double]) -> Double {
        let n = Double(a.count)
        let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
        var num = 0.0, da = 0.0, db = 0.0
        for i in a.indices {
            let x = a[i] - ma, y = b[i] - mb
            num += x * y; da += x * x; db += y * y
        }
        return da == 0 || db == 0 ? 0 : num / (da * db).squareRoot()
    }
}

// MARK: - Tab analysis

struct TabHint: Identifiable {
    enum Kind { case good, info, warn }
    var kind: Kind
    var text: String
    var id: String { text }
}

struct TabBar: Identifiable {
    var index: Int
    var chord: ChordMatch?
    var filled: Int
    var id: Int { index }
}

struct TabAnalysis {
    var guesses: [KeyGuess]
    var bars: [TabBar]
    /// Pitch classes played that are outside the song's key, with the first bar they appear in.
    var outside: [(pc: Int, bar: Int)]
    var hints: [TabHint]
    var noteCount: Int
    var lastPcs: [Int]
}

extension Tab {
    func analyze(ts: TimeSignature, key: Int, mode: Mode, spell: (Int) -> String) -> TabAnalysis {
        let placed = placed(ts)
        let barTicks = ts.barTicks
        var weights = [Double](repeating: 0, count: 12)
        var barWeights: [[Int: Double]] = []
        var barBass: [Int?] = []
        var filled: [Int] = []
        var hints: [TabHint] = []
        let scale = Set(mode.intervals.map { m12(key + $0) })
        var outside: [(Int, Int)] = []
        var noteCount = 0

        for p in placed {
            while barWeights.count <= p.bar { barWeights.append([:]); barBass.append(nil); filled.append(0) }
            filled[p.bar] += min(p.event.ticks, barTicks * (p.bar + 1) - p.start)
            // Spill-over into following bars still counts as time filled.
            var spill = p.end - barTicks * (p.bar + 1)
            var b = p.bar + 1
            while spill > 0 {
                while barWeights.count <= b { barWeights.append([:]); barBass.append(nil); filled.append(0) }
                filled[b] += min(spill, barTicks)
                spill -= barTicks; b += 1
            }
            for n in p.event.notes {
                noteCount += 1
                // Notes on the beat and in the bass weigh a bit more.
                var w = Double(p.event.ticks)
                if p.start % ts.ticksPerBeat == 0 { w *= 1.25 }
                weights[n.pc] += w
                barWeights[p.bar][n.pc, default: 0] += w
                if !scale.contains(n.pc) && !outside.contains(where: { $0.0 == n.pc }) { outside.append((n.pc, p.bar)) }
            }
            if let low = p.event.notes.min(by: { $0.midi < $1.midi }) {
                if barBass[p.bar].map({ low.midi < $0 }) ?? true { barBass[p.bar] = low.midi }
            }
        }

        let bars: [TabBar] = barWeights.indices.map { i in
            TabBar(index: i,
                   chord: ChordFinder.bestFit(weights: barWeights[i], bass: barBass[i].map(m12), key: key, mode: mode),
                   filled: filled[i])
        }

        let guesses = Array(KeyFinder.guess(weights).prefix(3))

        // Sense checks.
        if noteCount == 0 {
            hints.append(TabHint(kind: .info, text: "Tap the fretboard to write your first note. Each tap lands after the cursor."))
        }
        if let last = bars.last, last.filled < barTicks {
            let missing = Double(barTicks - last.filled) / Double(ts.ticksPerBeat)
            let beats = missing == missing.rounded() ? "\(Int(missing))" : String(format: "%.1f", missing)
            hints.append(TabHint(kind: .info, text: "The last bar is \(beats) beat\(missing == 1 ? "" : "s") short of a full \(ts.rawValue) bar. Add notes or a rest to finish it."))
        }
        if let cross = placed.first(where: { $0.end > barTicks * ($0.bar + 1) }) {
            hints.append(TabHint(kind: .warn, text: "A note in bar \(cross.bar + 1) rings over the bar line. Shorten it, or split it into two notes."))
        }
        if let wide = placed.first(where: { $0.event.stretch > 4 }) {
            hints.append(TabHint(kind: .warn, text: "The shape in bar \(wide.bar + 1) stretches \(wide.event.stretch) frets. That's a big reach; try moving a note to another string."))
        }
        let singles = placed.filter { $0.event.notes.count == 1 }
        for (a, b) in zip(singles, singles.dropFirst()) where b.index == a.index + 1 {
            let leap = abs(b.event.notes[0].midi - a.event.notes[0].midi)
            if leap > 12 {
                hints.append(TabHint(kind: .info, text: "Big jump of \(leap) semitones in bar \(b.bar + 1). Fine as an effect, but melodies that move in small steps are easier to sing."))
                break
            }
        }
        if !outside.isEmpty {
            let list = outside.prefix(4).map { "\(spell($0.0)) (bar \($0.1 + 1))" }.joined(separator: ", ")
            hints.append(TabHint(kind: .info, text: "Outside \(spell(key)) \(mode.name.lowercased()): \(list). Used briefly between scale notes they add spice (passing or blue notes). On strong beats they sound like a key change."))
        } else if noteCount >= 4 {
            hints.append(TabHint(kind: .good, text: "Every note fits \(spell(key)) \(mode.name.lowercased()). Safe and consonant."))
        }
        let lengths = Set(placed.filter { !$0.event.isRest }.map(\.event.ticks))
        if placed.count >= 8 && lengths.count == 1 {
            hints.append(TabHint(kind: .info, text: "Every note has the same length. Mixing long and short notes, or adding a rest, gives a riff its groove."))
        }
        let lastPcs = placed.last(where: { !$0.event.isRest })?.event.notes.map(\.pc) ?? []
        if noteCount >= 4, !lastPcs.isEmpty {
            if lastPcs.contains(m12(key)) {
                hints.append(TabHint(kind: .good, text: "It ends on \(spell(key)), the home note. That sounds finished."))
            } else {
                hints.append(TabHint(kind: .info, text: "It ends away from home (on \(lastPcs.map(spell).joined(separator: "/"))), so it wants to keep going. Great for a riff that loops; end on \(spell(key)) to close."))
            }
        }

        return TabAnalysis(guesses: guesses, bars: bars, outside: outside.map { (pc: $0.0, bar: $0.1) },
                           hints: hints, noteCount: noteCount, lastPcs: lastPcs)
    }
}
