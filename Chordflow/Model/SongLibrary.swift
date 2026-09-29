import Foundation

/// Songs are stored as one JSON file each in Application Support/Songs.
enum SongLibrary {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Songs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func url(_ id: UUID) -> URL { folder.appendingPathComponent("\(id.uuidString).json") }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// All saved songs, most recently edited first.
    static func all() -> [Song] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Song.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func load(_ id: UUID) -> Song? {
        try? decoder.decode(Song.self, from: Data(contentsOf: url(id)))
    }

    static func save(_ song: Song) {
        guard let data = try? encoder.encode(song) else { return }
        try? data.write(to: url(song.id), options: .atomic)
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(id))
    }

    static var lastOpenedID: UUID? {
        get { UserDefaults.standard.string(forKey: "lastSongID").flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "lastSongID") }
    }
}

// MARK: - Templates

struct SongTemplate: Identifiable {
    var id: String { name }
    var name: String
    var detail: String
    var make: () -> Song
}

extension SongTemplate {
    private static func c(_ root: Int, _ q: Quality, _ bars: Double = 1) -> Chord {
        Chord(id: "c" + UUID().uuidString.prefix(8), root: root, q: q, bars: bars)
    }

    private static func s(_ name: String, _ chords: [Chord], repeats: Int = 1) -> SongSection {
        SongSection(id: "s" + UUID().uuidString.prefix(8), name: name, chords: chords, repeats: repeats)
    }

    static let all: [SongTemplate] = [
        SongTemplate(name: "Blank", detail: "One chord, your call") {
            Song(title: "Untitled", key: 0, mode: .major, bpm: 96, sections: [s("Verse", [c(0, .maj)])])
        },
        SongTemplate(name: "Pop", detail: "I–V–vi–IV") {
            Song(title: "New pop song", key: 0, mode: .major, bpm: 104, style: .pulse, sections: [
                s("Verse", [c(0, .maj), c(7, .maj), c(9, .min), c(5, .maj)], repeats: 2),
                s("Chorus", [c(5, .maj), c(0, .maj), c(7, .maj), c(9, .min)], repeats: 2),
            ])
        },
        SongTemplate(name: "Ballad", detail: "Minor, picked") {
            Song(title: "New ballad", key: 9, mode: .minor, bpm: 72, style: .arpeggio, sections: [
                s("Verse", [c(9, .min), c(5, .maj), c(0, .maj), c(7, .maj)]),
                s("Chorus", [c(5, .maj7), c(0, .maj), c(7, .maj), c(9, .min, 2)]),
            ])
        },
        SongTemplate(name: "12-bar blues", detail: "Shuffle in A") {
            Song(title: "New blues", key: 9, mode: .mixolydian, bpm: 88, style: .pulse, sections: [
                s("Blues", [c(9, .dom7, 4), c(2, .dom7, 2), c(9, .dom7, 2),
                            c(4, .dom7), c(2, .dom7), c(9, .dom7), c(4, .dom7)], repeats: 2),
            ])
        },
        SongTemplate(name: "Waltz", detail: "3/4, gentle") {
            Song(title: "New waltz", key: 2, mode: .major, bpm: 120, timeSignature: .threeFour, style: .arpeggio, sections: [
                s("Verse", [c(2, .maj, 2), c(7, .maj, 2), c(9, .maj, 2), c(2, .maj, 2)]),
            ])
        },
    ]

    /// The song from the original design, used on first launch.
    static func demo() -> Song {
        Song(title: "Midnight Drive", key: 7, mode: .major, bpm: 92, sections: [
            s("Verse", [c(7, .maj), c(2, .maj), c(4, .min), c(0, .maj)]),
            s("Chorus", [c(0, .maj), c(7, .maj), c(2, .maj), c(4, .min)]),
            s("Bridge", [c(9, .m7), c(0, .maj7), c(2, .sus4), c(2, .maj)]),
        ])
    }
}
