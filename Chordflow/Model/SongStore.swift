import SwiftUI
import Observation

enum FretMode { case shape, scale, find }
enum FretLabels { case notes, degrees }
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

enum ToastAction: Equatable { case view, undo }

struct Toast: Equatable {
    var text: String
    var dot: Color
    var action: ToastAction = .view
}

@MainActor
@Observable
final class SongStore {
    // MARK: Song (saved)
    var songID = UUID()
    var title = ""
    var key = 7
    var mode: Mode = .major
    var bpm = 92
    var timeSignature: TimeSignature = .fourFour
    var sound: Sound = .guitar
    var style: PlayStyle = .strum
    var sections: [SongSection] = []
    var tabs: [Tab] = []
    var strumSpeed: Double = 24
    var ring: Double = 1
    var swing: Double = 0

    // MARK: UI / playback state
    var sel = Selection(sectionID: "", chordID: nil)
    var playing = false
    var pos = 0
    /// Beat within the current chord.
    var beat = 0
    /// Beat within the current bar (drives the metronome accent and the mini-player pills).
    var barBeat = 0
    /// Count-in beats still to go before the first chord.
    var countdown = 0
    var loop: LoopMode = .song
    var fretMode: FretMode = .shape
    var fretLabels: FretLabels = .notes
    /// Find mode: fret per string (-1 = muted), low E first.
    var finderFrets = [-1, -1, -1, -1, -1, -1]
    var lit = false
    var dragID: String?
    var target: InsertTarget?
    var toast: Toast?
    var previewKey: String?
    var panel = 0
    /// Set to request the pager to scroll to a panel.
    var panelRequest: Int?

    // Sheets
    var editingChordID: String?
    var showSetup = false
    var showLibrary = false
    var library: [Song] = []
    var showHandbook = false

    // MARK: Tab editor
    var tabID: String?
    /// The selected event; new notes land after it.
    var tabCursor: String?
    var tabLength = NoteLength(value: .eighth)
    /// When on, taps add notes to the selected event (chords, double stops) instead of starting a new one.
    var tabStack = false
    var tabPlaying = false
    var tabPlayID: String?
    var tabLoop = false
    /// Pitch classes to highlight on the tab fretboard (from an analysis idea).
    var tabHint: [Int] = []
    @ObservationIgnored var tabTimer: Timer?

    // MARK: Preferences (app-wide)
    var click = true
    var countIn = false
    var countInBars = 1
    var clickVolume = 0.7
    var colorNotes = true
    var showTips = true

    var palette: Palette { Palette(mono: !colorNotes) }
    var beatsPerBar: Int { timeSignature.beatsPerBar }

    @ObservationIgnored private var jump: Int?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var flashTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var lastSaved: Song?
    @ObservationIgnored private var taps: [Date] = []
    /// Sections before the last destructive edit, for Undo.
    @ObservationIgnored private var undoSections: [SongSection]?
    let synth = GuitarSynth.shared

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [Prefs.click: true, Prefs.countIn: false, Prefs.colorNotes: true,
                              Prefs.countInBars: 1, Prefs.clickVolume: 0.7, Prefs.showTips: true])
        click = d.bool(forKey: Prefs.click)
        countIn = d.bool(forKey: Prefs.countIn)
        colorNotes = d.bool(forKey: Prefs.colorNotes)
        countInBars = max(1, min(2, d.integer(forKey: Prefs.countInBars)))
        clickVolume = d.double(forKey: Prefs.clickVolume)
        showTips = d.bool(forKey: Prefs.showTips)
        synth.clickVolume = clickVolume

        // The demo song only appears on the very first launch; after that an empty library stays empty.
        let song = SongLibrary.lastOpenedID.flatMap(SongLibrary.load) ?? SongLibrary.all().first ?? {
            if d.bool(forKey: Prefs.seeded) { return SongTemplate.all[0].make() }
            d.set(true, forKey: Prefs.seeded)
            let demo = SongTemplate.demo()
            SongLibrary.save(demo)
            return demo
        }()
        apply(song)

        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                self?.saveIfNeeded()
            }
        }
    }

    private enum Prefs {
        static let click = "click"
        static let countIn = "countIn"
        static let colorNotes = "colorNotes"
        static let countInBars = "countInBars"
        static let clickVolume = "clickVolume"
        static let showTips = "showTips"
        static let seeded = "seededDemo"
    }

    func setClick(_ on: Bool) { click = on; UserDefaults.standard.set(on, forKey: Prefs.click) }
    func setCountIn(_ on: Bool) { countIn = on; UserDefaults.standard.set(on, forKey: Prefs.countIn) }
    func setColorNotes(_ on: Bool) { colorNotes = on; UserDefaults.standard.set(on, forKey: Prefs.colorNotes) }
    func setShowTips(_ on: Bool) { showTips = on; UserDefaults.standard.set(on, forKey: Prefs.showTips) }
    func setCountInBars(_ n: Int) { countInBars = n; UserDefaults.standard.set(n, forKey: Prefs.countInBars) }
    func setClickVolume(_ v: Double) {
        clickVolume = v
        synth.clickVolume = v
        UserDefaults.standard.set(v, forKey: Prefs.clickVolume)
    }

    // MARK: Songs & saving

    private func snapshot(date: Date = Date()) -> Song {
        Song(id: songID, title: title, key: key, mode: mode, bpm: bpm, timeSignature: timeSignature,
             sound: sound, style: style, sections: sections, tabs: tabs,
             strumSpeed: strumSpeed, ring: ring, swing: swing, updatedAt: date)
    }

    private func apply(_ s: Song) {
        songID = s.id
        title = s.title
        key = s.key
        mode = s.mode
        bpm = s.bpm
        timeSignature = s.timeSignature
        sound = s.sound
        synth.sound = s.sound
        style = s.style
        sections = s.sections
        tabs = s.tabs
        strumSpeed = s.strumSpeed
        ring = s.ring
        swing = s.swing
        tabID = tabs.first?.id
        tabCursor = tabs.first?.events.last?.id
        tabHint = []
        undoSections = nil
        let first = sections.first
        sel = Selection(sectionID: first?.id ?? "", chordID: first?.chords.first?.id)
        target = nil
        editingChordID = nil
        pos = 0; beat = 0; barBeat = 0
        lastSaved = snapshot(date: .distantPast)
        SongLibrary.lastOpenedID = s.id
    }

    /// Writes the song to disk if anything changed since the last save.
    func saveIfNeeded() {
        let content = snapshot(date: .distantPast)
        guard content != lastSaved else { return }
        lastSaved = content
        SongLibrary.save(snapshot())
    }

    func refreshLibrary() {
        saveIfNeeded()
        library = SongLibrary.all()
    }

    func open(_ song: Song) {
        saveIfNeeded()
        stop()
        stopTab()
        apply(SongLibrary.load(song.id) ?? song)
        showLibrary = false
        goPanel(0)
    }

    func create(from template: SongTemplate) {
        saveIfNeeded()
        let s = template.make()
        SongLibrary.save(s)
        stop()
        stopTab()
        apply(s)
        showLibrary = false
        goPanel(0)
    }

    func duplicate(_ song: Song) {
        saveIfNeeded()
        var copy = SongLibrary.load(song.id) ?? song
        copy.id = UUID()
        copy.title += " copy"
        copy.updatedAt = Date()
        SongLibrary.save(copy)
        refreshLibrary()
    }

    func deleteSong(_ song: Song) {
        SongLibrary.delete(song.id)
        if song.id == songID {
            stop()
            stopTab()
            // With nothing left, a fresh blank song opens; it is only saved once you edit it.
            apply(SongLibrary.all().first ?? SongTemplate.all[0].make())
        }
        refreshLibrary()
    }

    // MARK: Derived

    var allChords: [PlacedChord] {
        sections.flatMap { s in s.chords.map { PlacedChord(chord: $0, sectionID: s.id) } }
    }

    /// The chords playback walks through: the whole song with section repeats, or the selected section on loop.
    var sequence: [PlacedChord] {
        if loop == .section {
            guard let s = sections.first(where: { $0.id == sel.sectionID }) ?? sections.first else { return [] }
            return s.chords.map { PlacedChord(chord: $0, sectionID: s.id) }
        }
        return sections.flatMap { s in
            (0..<max(1, s.repeats)).flatMap { _ in s.chords.map { PlacedChord(chord: $0, sectionID: s.id) } }
        }
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
        let ci = (playing && pos < seq.count && seq[pos].id == cur.id) ? pos : (seq.firstIndex { $0.id == cur.id } ?? -1)
        return seq[(ci + 1) % seq.count]
    }

    var currentSection: SongSection? { sections.first { $0.id == current.sectionID } }

    var keyName: String { "\(name(key)) \(mode.name.lowercased())" }

    /// Spells a pitch class with sharps or flats depending on the key.
    func name(_ pc: Int) -> String {
        let r = m12(key + mode.relative)
        return ([5, 10, 3, 8, 1, 6].contains(r) ? Theory.flat : Theory.sharp)[m12(pc)]
    }

    func chordName(_ root: Int, _ q: Quality, bass: Int? = nil) -> String {
        name(root) + q.suffix + (bass.map { m12($0) == m12(root) ? "" : "/" + name($0) } ?? "")
    }
    func chordName(_ c: Chord) -> String { chordName(c.root, c.q, bass: c.bass) }
    func chordName(_ c: PlacedChord) -> String { chordName(c.chord) }
    func chordName(_ m: ChordMatch) -> String { chordName(m.root, m.q, bass: m.bass) }

    func numeral(_ root: Int, _ q: Quality) -> String { Theory.numeral(m12(root - key), q, mode) }

    func inKey(_ c: Chord) -> Bool {
        let scale = scalePitchClasses
        return c.pitchClasses.allSatisfy(scale.contains)
    }

    /// How many beats a chord lasts in the current time signature.
    func beats(of c: Chord) -> Int { max(1, Int((c.bars * Double(beatsPerBar)).rounded())) }

    /// "2 BARS", or "5 BEATS" when the length isn't a tidy fraction of a bar.
    func lengthLabel(_ c: Chord) -> String {
        let b = beats(of: c)
        let asBars = Double(b) / Double(beatsPerBar)
        if (2 * b) % beatsPerBar == 0 {
            return "\(formatBars(asBars)) BAR\(asBars <= 1 ? "" : "S")"
        }
        return "\(b) BEAT\(b == 1 ? "" : "S")"
    }

    var insertTarget: InsertTarget {
        target ?? InsertTarget(sectionID: sel.sectionID.isEmpty ? (sections.first?.id ?? "") : sel.sectionID,
                               afterID: sel.chordID)
    }

    func chord(_ id: String?) -> PlacedChord? { allChords.first { $0.id == id } }

    private func newID(_ prefix: String) -> String { prefix + UUID().uuidString.prefix(8) }

    // MARK: Sound

    func flash() {
        flashTask?.cancel()
        lit = true
        flashTask = after(0.19) { $0.lit = false }
    }

    func hear(_ root: Int, _ q: Quality) {
        synth.strum(notes: synth.notes((m12(root), q)), spacing: style == .block ? 0.004 : strumSpeed / 1000)
        flash()
    }

    /// Plays a chord the way it's written: its own shape and bass.
    func hear(_ c: Chord) {
        synth.strum(notes: midiNotes(c), spacing: (c.style ?? style) == .block ? 0.004 : strumSpeed / 1000)
        flash()
    }

    /// MIDI notes of a chord's shape, low to high.
    func midiNotes(_ c: Chord) -> [Int] {
        c.shape.enumerated().compactMap { i, f in f >= 0 ? Theory.tuning[i] + f : nil }
    }

    func hear(frets: [Int]) {
        let ns = frets.enumerated().compactMap { i, f in f >= 0 ? Theory.tuning[i] + f : nil }
        synth.strum(notes: ns, spacing: strumSpeed / 1000)
        flash()
    }

    func note(_ midi: Int) { synth.note(midi: midi) }

    // MARK: Playback

    func togglePlay() { playing ? stop() : play() }

    func play() {
        guard synth.ensureRunning(), !sequence.isEmpty else { return }
        stopTab()
        let i = sequence.firstIndex { $0.id == sel.chordID }
        jump = i ?? 0
        timer?.invalidate()
        countdown = countIn ? beatsPerBar * countInBars : 0
        playing = true
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        playing = false
        beat = 0
        barBeat = 0
        countdown = 0
    }

    private func tick() {
        let spb = 60 / Double(bpm)
        if countdown > 0 {
            synth.click(accent: countdown % beatsPerBar == 0)
            countdown -= 1
            schedule(spb)
            return
        }
        let seq = sequence
        guard !seq.isEmpty else { stop(); return }
        var p = pos, b = beat
        if let j = jump {
            p = j; b = 0; jump = nil
            barBeat = 0
        } else {
            b += 1
            if p >= seq.count || b >= beats(of: seq[p].chord) { b = 0; p = (p + 1) % seq.count }
            barBeat = (barBeat + 1) % beatsPerBar
        }
        if p >= seq.count || p < 0 { p = 0 }
        let c = seq[p]
        perform(c.chord, beat: b, spb: spb)
        if click { synth.click(accent: barBeat == 0, medium: timeSignature.isSecondaryAccent(barBeat)) }
        pos = p
        beat = b
        sel = Selection(sectionID: c.sectionID, chordID: c.id)
        schedule(spb)
    }

    private func schedule(_ spb: Double) {
        let t = Timer(timeInterval: spb, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.playing else { return }
                self.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Plays one beat of a chord in its style.
    private func perform(_ c: Chord, beat b: Int, spb: Double) {
        let total = beats(of: c)
        let ns = midiNotes(c)
        guard !ns.isEmpty else { return }
        let spacing = strumSpeed / 1000
        // Swing pushes the off-beat eighth late: 0 = straight, 1 = triplet feel.
        let offbeat = spb * (0.5 + swing / 6)
        switch c.style ?? style {
        case .strum:
            if b == 0 { synth.strum(notes: ns, duration: (Double(total) * spb + 0.4) * ring, spacing: spacing) }
        case .block:
            if b == 0 { synth.strum(notes: ns, duration: (Double(total) * spb + 0.3) * ring, spacing: 0.003, velocity: 0.16) }
        case .pulse:
            let up = b % 2 == 1
            synth.strum(notes: up ? Array(ns.reversed()) : ns, duration: spb * 0.95 * ring, spacing: spacing / 2,
                        velocity: b == 0 ? 0.22 : (up ? 0.12 : 0.17))
        case .arpeggio:
            let pattern = ns + ns.dropFirst().dropLast().reversed()
            for k in 0..<2 {
                let n = pattern[(b * 2 + k) % pattern.count]
                synth.pluck(midi: n, delay: 0.01 + (k == 0 ? 0 : offbeat), duration: spb * 3 * ring, velocity: 0.2)
            }
        }
        if b == 0 { flash() }
    }

    // MARK: Chord editing

    func tap(sectionID: String, chordID: String) {
        dragID = nil
        if playing {
            if let i = sequence.firstIndex(where: { $0.id == chordID }) {
                jump = i
            } else {
                loop = .song
                jump = sequence.firstIndex { $0.id == chordID }
            }
            sel = Selection(sectionID: sectionID, chordID: chordID)
            target = nil
        } else if sel.chordID == chordID {
            // Tapping the selected chord opens its editor.
            editingChordID = chordID
        } else {
            sel = Selection(sectionID: sectionID, chordID: chordID)
            target = nil
            if let c = chord(chordID) { hear(c.chord) }
        }
    }

    func updateChord(_ id: String, _ patch: (inout Chord) -> Void) {
        for s in sections.indices {
            if let i = sections[s].chords.firstIndex(where: { $0.id == id }) {
                patch(&sections[s].chords[i])
            }
        }
    }

    func setQuality(_ q: Quality) {
        guard hasCurrent else { return }
        setQuality(current.id, q)
    }

    func setQuality(_ id: String, _ q: Quality) {
        updateChord(id) { $0.q = q; $0.voicing = nil }
        if let c = chord(id) { hear(c.chord) }
    }

    func setRoot(_ id: String, _ root: Int) {
        updateChord(id) { c in
            // An inversion follows the root; a free slash bass stays put.
            if let b = c.bass, c.pitchClasses.contains(m12(b)) { c.bass = m12(b + root - c.root) }
            c.root = m12(root)
            c.voicing = nil
        }
        if let c = chord(id) { hear(c.chord) }
    }

    func setBass(_ id: String, _ bass: Int?) {
        updateChord(id) { $0.bass = bass.map(m12); $0.voicing = nil }
        if let c = chord(id) { hear(c.chord) }
    }

    func setVoicing(_ id: String, _ v: [Int]?) {
        updateChord(id) { $0.voicing = v }
        if let c = chord(id) { hear(c.chord) }
    }

    func setChordStyle(_ id: String, _ s: PlayStyle?) {
        updateChord(id) { $0.style = s }
    }

    func setBars(_ id: String, _ bars: Double) {
        updateChord(id) { $0.bars = max(0.25, min(16, bars)) }
    }

    /// Sets the length in beats (for odd lengths like 3 beats in 4/4).
    func setBeats(_ id: String, _ beats: Int) {
        let b = max(1, min(16 * beatsPerBar, beats))
        updateChord(id) { $0.bars = Double(b) / Double(beatsPerBar) }
    }

    /// Quick − / + on a chip: ½ → 1 → 2 → 3 … bars, snapping odd lengths to whole bars.
    func stepBars(_ id: String, up: Bool) {
        guard let c = chord(id)?.chord else { return }
        let b = c.bars
        let next: Double = up ? (b < 1 ? 1 : (b + 0.001).rounded(.down) + 1)
                              : (b > 1 ? (b - 0.001).rounded(.up) - 1 : 0.5)
        guard next != b else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        setBars(id, next)
    }

    /// Gives every chord in a section the same length.
    func setAllBars(_ sectionID: String, _ bars: Double) {
        guard let i = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        for c in sections[i].chords.indices { sections[i].chords[c].bars = bars }
    }

    func duplicateChord(_ id: String) {
        guard let s = sections.firstIndex(where: { $0.chords.contains { $0.id == id } }),
              let i = sections[s].chords.firstIndex(where: { $0.id == id }) else { return }
        var copy = sections[s].chords[i]
        copy.id = newID("c")
        sections[s].chords.insert(copy, at: i + 1)
        sel = Selection(sectionID: sections[s].id, chordID: copy.id)
        editingChordID = copy.id
    }

    /// Moves a chord onto another chord's slot (possibly in another section).
    func move(_ chordID: String, onto targetID: String) {
        guard chordID != targetID,
              let fromS = sections.firstIndex(where: { $0.chords.contains { $0.id == chordID } }),
              let toS = sections.firstIndex(where: { $0.chords.contains { $0.id == targetID } }),
              let from = sections[fromS].chords.firstIndex(where: { $0.id == chordID }),
              let to = sections[toS].chords.firstIndex(where: { $0.id == targetID }) else { return }
        let c = sections[fromS].chords.remove(at: from)
        sections[toS].chords.insert(c, at: min(to, sections[toS].chords.count))
        if sel.chordID == chordID { sel.sectionID = sections[toS].id }
    }

    /// Moves a chord to the end of a section.
    func move(_ chordID: String, toEndOf sectionID: String) {
        guard let fromS = sections.firstIndex(where: { $0.chords.contains { $0.id == chordID } }),
              let toS = sections.firstIndex(where: { $0.id == sectionID }),
              let from = sections[fromS].chords.firstIndex(where: { $0.id == chordID }) else { return }
        if fromS == toS && from == sections[toS].chords.count - 1 { return }
        let c = sections[fromS].chords.remove(at: from)
        sections[toS].chords.append(c)
        if sel.chordID == chordID { sel.sectionID = sectionID }
    }

    func delete(chordID: String) {
        let all = allChords
        guard let i = all.firstIndex(where: { $0.id == chordID }) else { return }
        let neighbour = i + 1 < all.count ? all[i + 1] : (i > 0 ? all[i - 1] : nil)
        let sid = all[i].sectionID
        undoSections = sections
        let removed = all[i].chord
        for s in sections.indices { sections[s].chords.removeAll { $0.id == chordID } }
        showToast(Toast(text: "Removed \(chordName(removed))", dot: palette.col(removed.root), action: .undo))
        sel = neighbour.map { Selection(sectionID: $0.sectionID, chordID: $0.id) }
            ?? Selection(sectionID: sid, chordID: nil)
        if editingChordID == chordID { editingChordID = nil }
    }

    func addChord(_ root: Int, _ q: Quality, bass: Int? = nil, voicing: [Int]? = nil) {
        if sections.isEmpty { addSection(withChord: false) }
        let tg = insertTarget
        let si = sections.firstIndex { $0.id == tg.sectionID } ?? 0
        var nc = Chord(id: newID("c"), root: m12(root), q: q)
        nc.bass = bass.flatMap { m12($0) == m12(root) ? nil : m12($0) }
        nc.voicing = voicing
        let sec = sections[si]
        let i = sec.chords.firstIndex { $0.id == tg.afterID }
        sections[si].chords.insert(nc, at: i.map { $0 + 1 } ?? sec.chords.count)
        sel = Selection(sectionID: sec.id, chordID: nc.id)
        target = InsertTarget(sectionID: sec.id, afterID: nc.id)
        showToast(Toast(text: "Added \(chordName(nc)) to \(sec.name)", dot: palette.col(nc.root)))
        hear(nc)
    }

    // MARK: Section editing

    /// Adds a section, named automatically unless `name` is given. It starts on the home chord.
    func addSection(named: String? = nil, withChord: Bool = true) {
        let id = newID("s"), cid = newID("c")
        let n = Theory.sectionNames.count
        let used = Set(sections.map(\.name))
        let name = named ?? Theory.sectionNames.first { !used.contains($0) }
            ?? Theory.sectionNames[((sections.count - 3) % n + n) % n]
        let chords = withChord ? [Chord(id: cid, root: key, q: diatonic[0].q)] : []
        sections.append(SongSection(id: id, name: name, chords: chords))
        sel = Selection(sectionID: id, chordID: withChord ? cid : nil)
        target = InsertTarget(sectionID: id, afterID: withChord ? cid : nil)
    }

    /// Brings back the sections as they were before the last delete.
    func undo() {
        guard let saved = undoSections else { return }
        sections = saved
        undoSections = nil
        toast = nil
        if chord(sel.chordID) == nil {
            let first = sections.first
            sel = Selection(sectionID: first?.id ?? "", chordID: first?.chords.first?.id)
        }
    }

    func renameSection(_ id: String, _ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = sections.firstIndex(where: { $0.id == id }) else { return }
        sections[i].name = trimmed
    }

    func setRepeats(_ id: String, _ n: Int) {
        guard let i = sections.firstIndex(where: { $0.id == id }) else { return }
        sections[i].repeats = max(1, min(8, n))
    }

    func duplicateSection(_ id: String) {
        guard let i = sections.firstIndex(where: { $0.id == id }) else { return }
        var copy = sections[i]
        copy.id = newID("s")
        copy.chords = copy.chords.map { var c = $0; c.id = newID("c"); return c }
        sections.insert(copy, at: i + 1)
    }

    func moveSection(_ id: String, by delta: Int) {
        guard let i = sections.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard sections.indices.contains(j) else { return }
        sections.swapAt(i, j)
    }

    func deleteSection(_ id: String) {
        guard let s = sections.first(where: { $0.id == id }) else { return }
        undoSections = sections
        sections.removeAll { $0.id == id }
        showToast(Toast(text: "Deleted \(s.name)", dot: Color.accent, action: .undo))
        if sel.sectionID == id {
            let first = sections.first
            sel = Selection(sectionID: first?.id ?? "", chordID: first?.chords.first?.id)
        }
        if target?.sectionID == id { target = nil }
        if sections.isEmpty { stop() }
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
        if playing { jump = sequence.firstIndex { $0.id == first.id } } else { play() }
    }

    func preview(_ root: Int, _ q: Quality, bass: Int? = nil) {
        if let bass {
            var c = Chord(id: "", root: root, q: q)
            c.bass = bass
            hear(c)
        } else {
            hear(root, q)
        }
        previewKey = "\(m12(root))\(q.rawValue)"
        previewTask?.cancel()
        previewTask = after(0.22) { $0.previewKey = nil }
    }

    func showToast(_ t: Toast) {
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

    func toastAction() {
        if toast?.action == .undo { undo(); return }
        toast = nil
        goPanel(0)
    }

    // MARK: Key, tempo & setup

    private func shiftAll(_ n: Int) {
        for s in sections.indices {
            for c in sections[s].chords.indices {
                sections[s].chords[c].root = m12(sections[s].chords[c].root + n)
                sections[s].chords[c].bass = sections[s].chords[c].bass.map { m12($0 + n) }
                sections[s].chords[c].voicing = nil
            }
        }
    }

    func transpose(_ n: Int) {
        let k = m12(key + n)
        shiftAll(n)
        key = k
        hear(k, diatonic[0].q)
    }

    /// Moves the whole song so the key root becomes `pc`.
    func setKeyRoot(_ pc: Int) {
        let delta = m12(pc - key)
        guard delta != 0 else { return }
        transpose(delta > 6 ? delta - 12 : delta)
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

    /// Sets the key without moving any chords (e.g. to match what a tab was written in).
    func setKeyOnly(_ pc: Int, _ m: Mode) {
        key = m12(pc)
        mode = m
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
            hear(c.chord)
        }
    }

    func goPanel(_ i: Int) { panelRequest = i }

    func setBPM(_ v: Int) { bpm = max(40, min(220, v)) }
    func bpmDown() { setBPM(bpm - 4) }
    func bpmUp() { setBPM(bpm + 4) }

    /// Tap tempo: averages the last few taps.
    func tapTempo() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        if taps.count > 5 { taps.removeFirst(taps.count - 5) }
        synth.click(accent: true)
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        setBPM(Int((60 / (gaps.reduce(0, +) / Double(gaps.count))).rounded()))
    }

    func setTimeSignature(_ t: TimeSignature) {
        timeSignature = t
        barBeat = 0
    }

    func setSound(_ s: Sound) {
        sound = s
        synth.sound = s
        hear(current.chord)
    }

    func setStrumSpeed(_ v: Double) { strumSpeed = max(2, min(80, v)) }
    func setRing(_ v: Double) { ring = max(0.25, min(2, v)) }
    func setSwing(_ v: Double) { swing = max(0, min(1, v)) }

    func setStyle(_ s: PlayStyle) { style = s }

    func toggleLoop() { loop = loop == .song ? .section : .song }
}
