# Chordflow: stanje projekta i sljedeći koraci

Sažetak za nastavak rada u novom chatu.

## Projekt

Chordflow je nativna iOS aplikacija za pisanje pjesama na gitari (SwiftUI).

**Repo:** https://github.com/tonikopilas/iosapp (javni, grana `main`)

## Stack

- SwiftUI, iOS 17+, samo iPhone, portrait
- Xcode projekt `Chordflow.xcodeproj` (objectVersion 77, folder-synchronized grupa `Chordflow/`)
- Swift 5 language mode
- Nema vanjskih ovisnosti
- Fontovi Onest i JetBrains Mono su u `Chordflow/Resources/Fonts`
- Dizajn: tamna pozadina s blur mrljama, svijetle "paper" kartice (`#F4F1EE`), naglasak `#FF3B5C`, boje nota u OKLCH po krugu kvinti
- Original dizajna je u `project/Chordflow.dc.html`, a razgovor o dizajnu u `chats/`

## Build i instalacija

- `.github/workflows/build.yml` se pokreće na svaki push na `main` i ima dva joba:
  - simulator build (provjera da se kod kompajlira)
  - nepotpisani IPA za iPhone, objavljen na releaseu `latest`: https://github.com/tonikopilas/iosapp/releases/download/latest/Chordflow.ipa
- Ako build padne, greške kompajlera se prikazuju kao anotacije na runu. Status i anotacije mogu se čitati preko javnog GitHub API-ja bez logina (logovi traže login).
- U cloud okruženju nema Swift kompajlera. Kod se provjerava samo kroz CI.
- Instalacija na iPhone: besplatni Apple ID + SideStore, IPA se instalira preko postojeće aplikacije.

## Struktura koda

- **`Model/Theory.swift`:**
  - teorija: modusi, 17 vrsta akorda (uklj. aug, 6, m6, add9, 9, 7sus4, m7♭5, dim7, power), rimski brojevi
  - pretraga voicinga: `voicing(root, q, bass:)` i `voicings(...)` (sve pozicije na vratu, najbolja prva)
  - modeli: `Chord` (`bars`, `bass` za inverzije/slash akorde, `voicing` za odabrani oblik, `style` override), `SongSection` (`repeats`), `Song` (+ `tabs`, `strumSpeed`, `ring`, `swing`; tolerantno dekodiranje starih JSON-a)
  - `TimeSignature` (2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 12/8), `Sound`, `PlayStyle`
- **`Model/Tab.swift`:** tabulatura: `TabNote` (žica + prag), `TabEvent` (note koje počinju zajedno, prazno = pauza, trajanje u tickovima, četvrtinka = 24), `Tab` (dio/aranžman), `NoteValue`/`NoteLength` (točka, triola). `ChordFinder` (imenovanje akorda iz tonova i najbolji akord za takt melodije), `KeyFinder` (Krumhansl–Kessler), `Tab.analyze` (ključ, akordi po taktu, provjere smislenosti).
- **`Model/SongStore.swift`:** `@Observable`, stanje i akcije; playback, autosave, uređivanje akorda i sekcija, Undo za brisanje (snapshot sekcija), postavke (click volume, count-in taktovi, theory tips).
- **`Model/SongStore+Tab.swift`:** pisanje taba (tap na vrat, Chord/stack način, pauze, trajanja, pomak kursora, transpozicija nota), playback taba (Timer po eventu, klik po dobama, loop), analiza i akcije (sekcija iz taba, hint tonova na vratu, prijedlozi što dalje).
- **`Model/Learn.swift`:** `LearnTopic` (20 lekcija teorije) + dinamička objašnjenja (`explain(chord)`, `role`, `modeBlurb`, `tempoName`).
- **`Model/SongLibrary.swift`**, **`Model/Suggestions.swift`**, **`Model/Palette.swift`:** kao prije. Demo pjesma se stvara samo pri prvom pokretanju.
- **`Audio/GuitarSynth.swift`:** synth; `strum(notes:)` svira zadane MIDI note (za odabrane voicinge), klik ima glasnoću i srednji naglasak.
- **`Views/`:**
  - `RootView`: 5 panela (Song, Neck, Key, Next, Tab), toast s Undo, sheetovi (uklj. `HandbookSheet`)
  - `SongPanel`: prazno stanje, "Add section" (tap = auto ime, drži = izbor imena), footer sekcije (repeat −/+, vidljivi Delete s Undo), −/+ trajanja na odabranom akordu
  - `NeckPanel`: fretboard (Shape / Scale / Find), izbor pozicije, oznake Notes/Intervals, Find način prepoznaje akord
  - `TabPanel`: dijelovi, staff s taktovima, toolbar trajanja, horizontalni vrat za tapkanje, kartice analize
  - `LearnViews`: `InfoButton` (ⓘ → lekcija), `TipCard` (žarulja), `LessonSheet`, `HandbookSheet`, `FlowRow`
  - `ChordEditorSheet`: root, tip, trajanje (+ fino po dobama), bas/inverzije, oblik (s mini dijagramom), stil sviranja, objašnjenje
  - `SongSetupSheet`: tempo (+ naziv tempa), mjera (+ objašnjenje), tonalitet, zvuk, stil, Feel (strum speed, let ring, swing), metronom
  - ostalo: `KeyPanel`, `NextPanel`, `MiniPlayer`, `HeaderView` (gumb za handbook), `LibrarySheet` (prazno stanje), `SheetKit`, `Theme`

## Već napravljeno

- **Song:** sekcije s akordima; tap svira, drugi tap otvara editor; drag & drop; trajanje −/+ direktno na odabranom akordu; vidljivo brisanje sekcije s Undo; repeat stepper; prazna stanja (nema sekcija / prazna sekcija / prazna biblioteka).
- **Akordi:** 17 vrsta, inverzije i slash akordi, odabir pozicije na vratu, stil po akordu, trajanje po dobama.
- **Neck:** novi izgled vrata, Find način (tapkaš tonove, aplikacija imenuje akord, dodaje ga u pjesmu ili tab), prikaz intervala.
- **Tab:** pisanje tabulature tapkanjem po vratu, trajanja (1, ½, ¼, ⅛, 1/16, točka, triola), pauze, akordi/dvoglasi (Chord način), reprodukcija s klikom i loopom, uređivanje (odabir, brisanje, pomak za polutan/oktavu), analiza: tonalitet, akordi po taktu (→ nova sekcija), provjere (nepotpun takt, nota preko taktne crte, velik raspon prstiju, veliki skokovi, note izvan tonaliteta, završetak), prijedlozi što dalje s označenim tonovima na vratu.
- **Poučnost:** handbook s 20 lekcija, ⓘ gumbi po cijeloj aplikaciji, žarulja-savjeti (mogu se isključiti), objašnjenje uloge svakog akorda u tonalitetu.
- **Song setup:** tempo, mjera (7 vrsta), tonalitet i modus, zvuk, stil, strum speed, let ring, swing, klik (glasnoća), count-in (1–2 takta), boje nota, theory tips.
- **Biblioteka:** autosave, predlošci, otvaranje, dupliciranje, brisanje.

## Mogući sljedeći koraci

- Tehnike u tabu (hammer-on, pull-off, slide, bend) i tie preko taktne crte.
- Export taba (tekst / PDF) i dijeljenje pjesme.
- Alternativni ugađaji (Drop D, DADGAD) i capo.
- Više modusa (lydian, phrygian, harmonic minor) i u detekciji tonaliteta.

## Napomene za rad

- Commitaj kao "Toni Kopilas" <tonykopilas11@gmail.com> i pushaj na `main`.
- Nakon pusha provjeri CI run i release `latest`.
- Odgovaraj na hrvatskom.
