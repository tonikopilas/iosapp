import Foundation

struct Suggestion: Identifiable {
    var root: Int
    var q: Quality
    var why: String
    /// Pitch classes shared with the chord being followed.
    var shared: Int
    var id: String { "\(root)\(q.rawValue)" }
}

struct Suggestions {
    /// The chord we are suggesting a follow-up for.
    var base: (root: Int, q: Quality)
    var sectionName: String?
    var strong: [Suggestion]
    var color: [Suggestion]
}

extension SongStore {
    var suggestions: Suggestions {
        let tg = insertTarget
        let dia = diatonic
        let placed = allChords.first { $0.id == tg.afterID }
        let base = placed.map { ($0.root, $0.q) } ?? (key, dia[0].q)
        let basePcs = base.1.intervals.map { m12(base.0 + $0) }
        let bd = mode.intervals.firstIndex(of: m12(base.0 - key)) ?? 0
        var seen: Set<String> = ["\(base.0)\(base.1.rawValue)"]

        func make(_ root: Int, _ q: Quality, _ why: String) -> Suggestion? {
            let r = m12(root)
            let k = "\(r)\(q.rawValue)"
            guard !seen.contains(k) else { return nil }
            seen.insert(k)
            let shared = q.intervals.map { m12(r + $0) }.filter(basePcs.contains).count
            return Suggestion(root: r, q: q, why: why, shared: shared)
        }

        let strong = Theory.next[bd].compactMap { d in
            make(key + dia[d].off, dia[d].q, Theory.reason[d])
        }.prefix(4)

        let k = key
        let raw: [(Int, Quality, String)] = (mode == .major || mode == .mixolydian)
            ? [(k + 10, .maj, "Borrowed ♭VII. Big rock-anthem lift."),
               (k + 5, .min, "Minor four. Instant nostalgia."),
               (k + 8, .maj, "♭VI. Cinematic, wide open."),
               (k + 4, .dom7, "Pulls hard toward the vi."),
               (base.0, .sus4, "Suspend it. Tension, same chord.")]
            : [(k + 7, .maj, "Major V. Strong pull back home."),
               (k + 5, .maj, "Brighter IV. A ray of light."),
               (k + 1, .maj, "♭II. Dark, dramatic."),
               (base.0, .sus2, "Open it up. Airy, unresolved.")]
        let color = raw.compactMap { make($0.0, $0.1, $0.2) }.prefix(4)

        return Suggestions(base: base,
                           sectionName: sections.first { $0.id == tg.sectionID }?.name,
                           strong: Array(strong), color: Array(color))
    }
}
