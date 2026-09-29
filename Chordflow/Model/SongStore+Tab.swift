import SwiftUI

/// Writing, editing and playing tabs.
extension SongStore {
    var currentTab: Tab? { tabs.first { $0.id == tabID } ?? tabs.first }

    var cursorEvent: TabEvent? { currentTab?.events.first { $0.id == tabCursor } }

    private func tabIndex() -> Int? {
        guard let id = currentTab?.id else { return nil }
        return tabs.firstIndex { $0.id == id }
    }

    private func newTabID(_ prefix: String) -> String { prefix + UUID().uuidString.prefix(8) }

    // MARK: Parts

    func addTab(named: String? = nil) {
        let n = tabs.count + 1
        let t = Tab(id: newTabID("t"), name: named ?? (tabs.isEmpty ? "Riff" : "Part \(n)"), events: [])
        tabs.append(t)
        tabID = t.id
        tabCursor = nil
        tabHint = []
    }

    func selectTab(_ id: String) {
        stopTab()
        tabID = id
        tabCursor = tabs.first { $0.id == id }?.events.last?.id
        tabHint = []
    }

    func renameTab(_ id: String, _ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].name = trimmed
    }

    func duplicateTab(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        var copy = tabs[i]
        copy.id = newTabID("t")
        copy.name += " copy"
        copy.events = copy.events.map { var e = $0; e.id = newTabID("e"); return e }
        tabs.insert(copy, at: i + 1)
        selectTab(copy.id)
    }

    func deleteTab(_ id: String) {
        stopTab()
        tabs.removeAll { $0.id == id }
        if tabID == id {
            tabID = tabs.first?.id
            tabCursor = tabs.first?.events.last?.id
        }
    }

    // MARK: Writing

    /// A tap on the fretboard: stacks onto the selected event, or writes a new one after it.
    func tabTap(string: Int, fret: Int) {
        let note = TabNote(string: string, fret: fret)
        synth.note(midi: note.midi)
        if tabs.isEmpty { addTab() }
        guard let ti = tabIndex() else { return }
        if tabStack, let ci = tabs[ti].events.firstIndex(where: { $0.id == tabCursor }) {
            var e = tabs[ti].events[ci]
            if let same = e.notes.firstIndex(where: { $0.string == string }) {
                // Tapping the same spot again removes it; another fret on that string replaces it.
                if e.notes[same].fret == fret { e.notes.remove(at: same) } else { e.notes[same] = note }
            } else {
                e.notes.append(note)
            }
            tabs[ti].events[ci] = e
            return
        }
        insertEvent(TabEvent(id: newTabID("e"), notes: [note], ticks: tabLength.ticks), in: ti)
    }

    func addRest() {
        if tabs.isEmpty { addTab() }
        guard let ti = tabIndex() else { return }
        insertEvent(TabEvent(id: newTabID("e"), notes: [], ticks: tabLength.ticks), in: ti)
    }

    /// Writes a whole chord shape as one event (from the chord finder or a song chord).
    func addShapeToTab(_ frets: [Int]) {
        if tabs.isEmpty { addTab() }
        guard let ti = tabIndex() else { return }
        let notes = frets.enumerated().compactMap { i, f in f >= 0 ? TabNote(string: i, fret: f) : nil }
        guard !notes.isEmpty else { return }
        insertEvent(TabEvent(id: newTabID("e"), notes: notes, ticks: tabLength.ticks), in: ti)
        hear(frets: frets)
    }

    private func insertEvent(_ e: TabEvent, in ti: Int) {
        let at = tabs[ti].events.firstIndex { $0.id == tabCursor }.map { $0 + 1 } ?? tabs[ti].events.count
        tabs[ti].events.insert(e, at: at)
        tabCursor = e.id
    }

    /// Picks a note length; it also applies to the selected event.
    func setTabLength(_ l: NoteLength) {
        tabLength = l
        guard let ti = tabIndex(), let ci = tabs[ti].events.firstIndex(where: { $0.id == tabCursor }) else { return }
        tabs[ti].events[ci].ticks = l.ticks
    }

    func selectEvent(_ id: String?) {
        tabCursor = id
        guard let e = cursorEvent else { return }
        if let l = NoteLength.from(e.ticks) { tabLength = l }
        if !tabPlaying { playEvent(e) }
    }

    func moveCursor(_ delta: Int) {
        guard let t = currentTab, !t.events.isEmpty else { return }
        let i = t.events.firstIndex { $0.id == tabCursor } ?? (delta > 0 ? -1 : t.events.count)
        let j = max(0, min(t.events.count - 1, i + delta))
        selectEvent(t.events[j].id)
    }

    /// Deletes the selected event and selects the one before it.
    func deleteEvent() {
        guard let ti = tabIndex(), let ci = tabs[ti].events.firstIndex(where: { $0.id == tabCursor }) else { return }
        tabs[ti].events.remove(at: ci)
        tabCursor = ci > 0 ? tabs[ti].events[ci - 1].id : tabs[ti].events.first?.id
    }

    /// Moves every note of the selected event up or down one string, keeping pitch where possible.
    func shiftEvent(semitones: Int) {
        guard let ti = tabIndex(), let ci = tabs[ti].events.firstIndex(where: { $0.id == tabCursor }) else { return }
        var e = tabs[ti].events[ci]
        guard e.notes.allSatisfy({ $0.fret + semitones >= 0 && $0.fret + semitones <= 22 }) else { return }
        for n in e.notes.indices { e.notes[n].fret += semitones }
        tabs[ti].events[ci] = e
        playEvent(e)
    }

    func clearTab() {
        guard let ti = tabIndex() else { return }
        stopTab()
        tabs[ti].events.removeAll()
        tabCursor = nil
    }

    // MARK: Playback

    func toggleTabPlay() { tabPlaying ? stopTab() : playTab() }

    func playTab() {
        guard let t = currentTab, !t.events.isEmpty, synth.ensureRunning() else { return }
        stop()
        let start = t.events.firstIndex { $0.id == tabCursor }.flatMap { $0 == t.events.count - 1 ? nil : $0 } ?? 0
        tabPlaying = true
        tabStep(start)
    }

    func stopTab() {
        tabTimer?.invalidate()
        tabTimer = nil
        tabPlaying = false
        tabPlayID = nil
    }

    private func secondsPerTick() -> Double { 60 / Double(bpm) / Double(timeSignature.ticksPerBeat) }

    private func playEvent(_ e: TabEvent) {
        let dur = max(0.25, Double(e.ticks) * secondsPerTick() * 1.15 * ring)
        for (k, n) in e.sorted.enumerated() {
            synth.pluck(midi: n.midi, delay: 0.01 + Double(k) * min(0.012, strumSpeed / 2000), duration: dur, velocity: 0.2)
        }
    }

    private func tabStep(_ i: Int) {
        guard tabPlaying, let t = currentTab else { return }
        guard i < t.events.count else {
            if tabLoop { tabStep(0) } else { stopTab() }
            return
        }
        let placed = t.placed(timeSignature)
        let p = placed[i]
        let spt = secondsPerTick()
        playEvent(p.event)
        if click {
            // Clicks for every beat that starts inside this event.
            let tpb = timeSignature.ticksPerBeat
            var beat = (p.start + tpb - 1) / tpb * tpb
            while beat < p.end {
                let inBar = (beat % timeSignature.barTicks) / tpb
                synth.click(accent: inBar == 0, medium: timeSignature.isSecondaryAccent(inBar),
                            delay: 0.005 + Double(beat - p.start) * spt)
                beat += tpb
            }
        }
        if p.event.notes.count > 0 { flash() }
        tabPlayID = p.event.id
        let tm = Timer(timeInterval: Double(p.event.ticks) * spt, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tabStep(i + 1) }
        }
        RunLoop.main.add(tm, forMode: .common)
        tabTimer = tm
    }

    // MARK: Analysis actions

    var tabAnalysis: TabAnalysis? {
        currentTab.map { t in t.analyze(ts: timeSignature, key: key, mode: mode, spell: { self.name($0) }) }
    }

    /// Turns the chord heard in each bar of the tab into a new song section.
    func sectionFromTab() {
        guard let t = currentTab, let a = tabAnalysis else { return }
        let chords = a.bars.compactMap { $0.chord }
        guard !chords.isEmpty else { return }
        addSection(named: t.name, withChord: false)
        guard let si = sections.indices.last else { return }
        var merged: [Chord] = []
        for m in chords {
            if let last = merged.last, last.root == m.root, last.q == m.q {
                merged[merged.count - 1].bars += 1
            } else {
                merged.append(Chord(id: newTabID("c"), root: m.root, q: m.q))
            }
        }
        sections[si].chords = merged
        sel = Selection(sectionID: sections[si].id, chordID: merged.first?.id)
        target = nil
        showToast(Toast(text: "Added \(t.name) chords to the song", dot: palette.col(merged[0].root)))
    }

    /// Highlights a chord's notes on the tab fretboard and plays it.
    func hint(_ root: Int, _ q: Quality) {
        let pcs = q.intervals.map { m12(root + $0) }
        tabHint = tabHint == pcs ? [] : pcs
        hear(root, q)
    }

    /// Chords that could follow the last bar, in the song's key.
    func tabNextIdeas(_ a: TabAnalysis) -> [Suggestion] {
        let dia = diatonic
        guard let last = a.bars.last(where: { $0.chord != nil })?.chord else {
            return [0, 3, 4, 5].map { d in
                Suggestion(root: m12(key + dia[d].off), q: dia[d].q, why: Theory.reason[d], shared: 0)
            }
        }
        let degree = mode.intervals.firstIndex(of: m12(last.root - key)) ?? 0
        let lastPcs = Set(last.q.intervals.map { m12(last.root + $0) })
        return Theory.next[degree].prefix(3).map { d in
            let root = m12(key + dia[d].off)
            let shared = dia[d].q.intervals.map { m12(root + $0) }.filter(lastPcs.contains).count
            return Suggestion(root: root, q: dia[d].q, why: Theory.reason[d], shared: shared)
        }
    }
}
