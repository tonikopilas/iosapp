import SwiftUI
import Observation

enum FretMode { case shape, scale }
enum LoopMode { case song, section }

struct Selection: Equatable {
    var sectionID: String
    var chordID: String?
}

/// Where the next added chord goes: after `afterID` in section `sectionID` (or at the end).
struct InsertTarget: Equatable {
    var sectionID: String
    var afterID: String?
}

struct Toast: Equatable {
    var text: String
    var dot: Color
}

@MainActor
@Observable
final class SongStore {
    // Song
    var title = "Midnight Drive"
    var key = 7
    var mode: Mode = .major
    var bpm = 92
    var sections: [SongSection] = [
        SongSection(id: "s1", name: "Verse", chords: [
            Chord(id: "c1", root: 7, q: .maj, lyric: "City lights are"),
            Chord(id: "c2", root: 2, q: .maj, lyric: "fading slow"),
            Chord(id: "c3", root: 4, q: .min, lyric: "I keep driving"),
            Chord(id: "c4", root: 0, q: .maj, lyric: "nowhere to go"),
        ]),
        SongSection(id: "s2", name: "Chorus", chords: [
            Chord(id: "c5", root: 0, q: .maj, lyric: "Stay"),
            Chord(id: "c6", root: 7, q: .maj, lyric: "with me"),
            Chord(id: "c7", root: 2, q: .maj, lyric: "under the"),
            Chord(id: "c8", root: 4, q: .min, lyric: "neon glow"),
        ]),
        SongSection(id: "s3", name: "Bridge", chords: [
            Chord(id: "c9", root: 9, q: .m7, lyric: "If the night"),
            Chord(id: "c10", root: 0, q: .maj7, lyric: "won't let go"),
            Chord(id: "c11", root: 2, q: .sus4, lyric: "hold on"),
            Chord(id: "c12", root: 2, q: .maj, lyric: "tonight"),
        ]),
    ]

    // UI / playback state
    var sel = Selection(sectionID: "s1", chordID: "c1")
    var playing = false
    var pos = 0
    var beat = 0
    var loop: LoopMode = .song
    var fretMode: FretMode = .shape
    var lit = false
    var dragID: String?
    var target: InsertTarget?
    var toast: Toast?
    var previewKey: String?
    var click = true
    var panel = 0
    /// Set to request the pager to scroll to a panel.
    var panelRequest: Int?

    // Settings (from the Settings app)
    var beatsPerChord = 8
    var colorNotes = true

    var palette: Palette { Palette(mono: !colorNotes) }

    @ObservationIgnored private var nid = 100
    @ObservationIgnored private var jump: Int?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var flashTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    private let synth = GuitarSynth.shared

    init() {
        UserDefaults.standard.register(defaults: [Settings.beatsPerChord: "8", Settings.colorNotes: true])
        loadSettings()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadSettings() }
        }
    }

    enum Settings {
        static let beatsPerChord = "beatsPerChord"
        static let colorNotes = "colorNotes"
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        let b = Int(d.string(forKey: Settings.beatsPerChord) ?? "") ?? 4
        let c = d.bool(forKey: Settings.colorNotes)
        if b != beatsPerChord { beatsPerChord = b > 0 ? b : 4 }
        if c != colorNotes { colorNotes = c }
    }

    // MARK: Derived

    var allChords: [PlacedChord] {
        sections.flatMap { s in s.chords.map { PlacedChord(chord: $0, sectionID: s.id) } }
    }

    /// The chords that playback walks through (the whole song, or just the selected section when looping it).
    var sequence: [PlacedChord] {
        if loop == .section {
            guard let s = sections.first(where: { $0.id == sel.sectionID }) ?? sections.first else { return [] }
            return s.chords.map { PlacedChord(chord: $0, sectionID: s.id) }
        }
        return allChords
    }

    var scalePitchClasses: [Int] { mode.intervals.map { m12(key + $0) } }
    var diatonic: [Theory.DiatonicChord] { Theory.diatonic(mode) }

    /// The selected chord, or a stand-in tonic when the song is empty.
    var current: PlacedChord {
        let all = allChords
        if let c = all.first(where: { $0.id == sel.chordID }) ?? all.first { return c }
        return PlacedChord(chord: Chord(id: "", root: key, q: diatonic[0].q), sectionID: sections.first?.id ?? "")
    }

    var hasCurrent: Bool { !current.id.isEmpty }

    var nextChord: PlacedChord {
        let seq = sequence, cur = current
        guard !seq.isEmpty else { return cur }
        let ci = seq.firstIndex { $0.id == cur.id } ?? -1
        return seq[(ci + 1) % seq.count]
    }

    var currentSection: SongSection? { sections.first { $0.id == current.sectionID } }

    var keyName: String { "\(name(key)) \(mode.name.lowercased())" }

    /// Spells a pitch class with sharps or flats depending on the key.
    func name(_ pc: Int) -> String {
        let r = m12(key + mode.relative)
        return ([5, 10, 3, 8, 1, 6].contains(r) ? Theory.flat : Theory.sharp)[m12(pc)]
    }

    func chordName(_ root: Int, _ q: Quality) -> String { name(root) + q.suffix }
    func chordName(_ c: Chord) -> String { chordName(c.root, c.q) }
    func chordName(_ c: PlacedChord) -> String { chordName(c.root, c.q) }

    func numeral(_ root: Int, _ q: Quality) -> String { Theory.numeral(m12(root - key), q, mode) }

    func inKey(_ c: Chord) -> Bool {
        let scale = scalePitchClasses
        return c.pitchClasses.allSatisfy(scale.contains)
    }

    var insertTarget: InsertTarget {
        target ?? InsertTarget(sectionID: sel.sectionID.isEmpty ? (sections.first?.id ?? "") : sel.sectionID,
                               afterID: sel.chordID)
    }

    // MARK: Sound

    func flash() {
        flashTask?.cancel()
        lit = true
        flashTask = after(0.19) { $0.lit = false }
    }

    func hear(_ root: Int, _ q: Quality) {
        synth.strum((m12(root), q))
        flash()
    }

    func note(_ midi: Int) { synth.note(midi: midi) }

    // MARK: Playback

    func togglePlay() { playing ? stop() : play() }

    func play() {
        guard synth.ensureRunning() else { return }
        let i = sequence.firstIndex { $0.id == sel.chordID }
        jump = i ?? 0
        timer?.invalidate()
        playing = true
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        playing = false
        beat = 0
    }

    private func tick() {
        let seq = sequence
        guard !seq.isEmpty else { stop(); return }
        let beats = beatsPerChord
        var p = pos, b = beat
        if let j = jump {
            p = j; b = 0; jump = nil
        } else {
            b += 1
            if b >= beats { b = 0; p = (p + 1) % seq.count }
        }
        if p >= seq.count || p < 0 { p = 0 }
        let c = seq[p]
        if b == 0 {
            synth.strum((c.root, c.q), duration: Double(beats) * 60 / Double(bpm) + 0.4)
            flash()
        }
        if click { synth.click(accent: b == 0) }
        pos = p
        beat = b
        sel = Selection(sectionID: c.sectionID, chordID: c.id)

        let t = Timer(timeInterval: 60 / Double(bpm), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.playing else { return }
                self.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Editing

    func tap(sectionID: String, chordID: String) {
        if playing {
            if let i = sequence.firstIndex(where: { $0.id == chordID }) {
                jump = i
                sel = Selection(sectionID: sectionID, chordID: chordID)
                target = nil
            } else {
                loop = .song
                sel = Selection(sectionID: sectionID, chordID: chordID)
                target = nil
                jump = sequence.firstIndex { $0.id == chordID }
            }
        } else {
            sel = Selection(sectionID: sectionID, chordID: chordID)
            target = nil
            if let c = allChords.first(where: { $0.id == chordID }) { hear(c.root, c.q) }
        }
    }

    func updateChord(_ id: String, _ patch: (inout Chord) -> Void) {
        for s in sections.indices {
            if let i = sections[s].chords.firstIndex(where: { $0.id == id }) {
                patch(&sections[s].chords[i])
            }
        }
    }

    func setLyric(_ id: String, _ text: String) { updateChord(id) { $0.lyric = text } }

    func setQuality(_ q: Quality) {
        let cur = current
        guard hasCurrent else { return }
        updateChord(cur.id) { $0.q = q }
        hear(cur.root, q)
    }

    func reorder(sectionID: String, chordID: String, to index: Int) {
        guard let s = sections.firstIndex(where: { $0.id == sectionID }),
              let from = sections[s].chords.firstIndex(where: { $0.id == chordID }) else { return }
        let c = sections[s].chords.remove(at: from)
        sections[s].chords.insert(c, at: min(index, sections[s].chords.count))
    }

    func delete(sectionID: String, chordID: String) {
        let all = allChords
        guard let i = all.firstIndex(where: { $0.id == chordID }) else { return }
        let neighbour = i + 1 < all.count ? all[i + 1] : (i > 0 ? all[i - 1] : nil)
        if let s = sections.firstIndex(where: { $0.id == sectionID }) {
            sections[s].chords.removeAll { $0.id == chordID }
        }
        sel = neighbour.map { Selection(sectionID: $0.sectionID, chordID: $0.id) }
            ?? Selection(sectionID: sectionID, chordID: nil)
    }

    func addChord(_ root: Int, _ q: Quality) {
        let tg = insertTarget
        guard let si = sections.firstIndex(where: { $0.id == tg.sectionID }) ?? (sections.isEmpty ? nil : 0) else { return }
        nid += 1
        let nc = Chord(id: "c\(nid)", root: m12(root), q: q)
        let sec = sections[si]
        let i = sec.chords.firstIndex { $0.id == tg.afterID }
        sections[si].chords.insert(nc, at: i.map { $0 + 1 } ?? sec.chords.count)
        sel = Selection(sectionID: sec.id, chordID: nc.id)
        target = InsertTarget(sectionID: sec.id, afterID: nc.id)
        showToast(Toast(text: "Added \(chordName(nc)) to \(sec.name)", dot: palette.col(nc.root)))
        hear(nc.root, nc.q)
    }

    func addSection() {
        nid += 1; let id = "s\(nid)"
        nid += 1; let cid = "c\(nid)"
        let n = Theory.sectionNames.count
        let name = Theory.sectionNames[((sections.count - 3) % n + n) % n]
        sections.append(SongSection(id: id, name: name, chords: [Chord(id: cid, root: key, q: diatonic[0].q)]))
        sel = Selection(sectionID: id, chordID: cid)
        target = InsertTarget(sectionID: id, afterID: cid)
    }

    func suggest(for sectionID: String) {
        let last = sections.first { $0.id == sectionID }?.chords.last
        target = InsertTarget(sectionID: sectionID, afterID: last?.id)
        goPanel(3)
    }

    func playSection(_ s: SongSection) {
        guard let first = s.chords.first else { return }
        sel = Selection(sectionID: s.id, chordID: first.id)
        target = nil
        play()
    }

    func preview(_ root: Int, _ q: Quality) {
        hear(root, q)
        previewKey = "\(m12(root))\(q.rawValue)"
        previewTask?.cancel()
        previewTask = after(0.22) { $0.previewKey = nil }
    }

    private func showToast(_ t: Toast) {
        toast = t
        toastTask?.cancel()
        toastTask = after(2.4) { $0.toast = nil }
    }

    /// Runs `body` on the main actor after `seconds`, unless the returned task is cancelled first.
    private func after(_ seconds: Double, _ body: @escaping (SongStore) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            body(self)
        }
    }

    func dismissToastAndView() {
        toast = nil
        goPanel(0)
    }

    private func shiftAll(_ n: Int) {
        for s in sections.indices {
            for c in sections[s].chords.indices {
                sections[s].chords[c].root = m12(sections[s].chords[c].root + n)
            }
        }
    }

    func transpose(_ n: Int) {
        let k = m12(key + n)
        shiftAll(n)
        key = k
        hear(k, diatonic[0].q)
    }

    /// Moves the song into the key tapped on the circle of fifths.
    func circleKey(_ pc: Int, minor: Bool) {
        let newMode: Mode = minor ? .minor : .major
        let delta = m12(m12(pc + newMode.relative) - m12(key + mode.relative))
        shiftAll(delta)
        key = m12(pc)
        mode = newMode
        hear(pc, minor ? .min : .maj)
    }

    func setMode(_ m: Mode) {
        mode = m
        hear(key, Theory.diatonic(m)[0].q)
    }

    func step(_ n: Int) {
        let all = allChords
        guard !all.isEmpty else { return }
        let i = all.firstIndex { $0.id == sel.chordID } ?? 0
        let c = all[((i + n) % all.count + all.count) % all.count]
        sel = Selection(sectionID: c.sectionID, chordID: c.id)
        target = nil
        if playing {
            if let j = sequence.firstIndex(where: { $0.id == c.id }) { jump = j }
        } else {
            hear(c.root, c.q)
        }
    }

    func goPanel(_ i: Int) { panelRequest = i }

    func bpmDown() { bpm = max(50, bpm - 4) }
    func bpmUp() { bpm = min(200, bpm + 4) }
    func toggleLoop() { loop = loop == .song ? .section : .song }
}
