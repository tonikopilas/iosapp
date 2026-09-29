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
  - teorija: modusi, vrste akorda, rimski brojevi, pretraga gitarskih voicinga
  - modeli: `Chord` (sa `bars`), `SongSection` (sa `repeats`), `Song`
  - postavke pjesme: `TimeSignature`, `Sound` (guitar/piano/pad), `PlayStyle` (strum/pulse/arpeggio/block)
- **`Model/SongStore.swift`:**
  - `@Observable`, sve stanje i akcije
  - playback: `Timer` po udarcu, count-in, klik metronoma
  - autosave svakih 1,2 s i kad aplikacija ode u pozadinu
  - uređivanje akorda i sekcija
  - biblioteka pjesama
- **`Model/SongLibrary.swift`:** JSON datoteke u Application Support/Songs, zadnje otvorena pjesma, predlošci (Blank, Pop, Ballad, 12-bar blues, Waltz), demo pjesma "Midnight Drive".
- **`Model/Suggestions.swift`:** logika "što ide sljedeće".
- **`Model/Palette.swift`:** pretvorba OKLCH → Display P3 i boje dizajna.
- **`Audio/GuitarSynth.swift`:** `AVAudioEngine` synth (saw + triangle, low-pass filter, echo), tri zvuka, zaseban kanal za klik.
- **`Views/`:**
  - `RootView`: pozadina, zaglavlje, tabovi, pager s 4 panela, toast, mini-player, sheetovi
  - četiri panela: `SongPanel`, `NeckPanel`, `KeyPanel`, `NextPanel`
  - ostali ekrani: `MiniPlayer`, `HeaderView` (gumbi za biblioteku i postavke pjesme), `ChordEditorSheet`, `SongSetupSheet`, `LibrarySheet`
  - dijeljene komponente: `SheetKit` (`SettingCard`, `PaperSegmented`, `NoteGrid`), `Theme` (fontovi, glass, `PaperCard`, ikone)

## Već napravljeno

- **Song:**
  - sekcije s akordima; tap na akord ga svira, drugi tap otvara editor
  - sistemski drag & drop pomiče akorde, i u druge sekcije
  - svaki akord ima trajanje ½, 1, 2, 3 ili 4 takta
  - izbornik sekcije: preimenuj, ponovi, dupliciraj, pomakni, obriši
- **Song setup:** tempo (slider i tap tempo), mjera, tonalitet i modus, zvuk, stil sviranja, klik, count-in, boje nota.
- **Biblioteka:** autosave, predlošci, otvaranje, dupliciranje, brisanje.
- **Popravci:** layout je bio širi od ekrana, scrollanje je bilo trzavo (sjena na svakom slovu), tipkovnica se zatvara tapom, tekst pjesme je uklonjen.

## Sljedeći zahtjevi (još nisu početi)

1. **Još više mogućnosti podešavanja i poučnosti:** da se može namjestiti svaka sitnica i trajanje svega, uz objašnjenja teorije kroz cijelu aplikaciju.
2. **Brisanje sekcija i prazna stanja:** brisanje sekcija postoji u izborniku •••, ali treba ga učiniti očitijim. Treba dodati prazno stanje kad nema pjesama ili sekcija.
3. **Lakše namještanje taktova:** npr. brzi +/- ili drag direktno na akordu, bez ulaska u editor.
4. **Bolji dizajn fretboarda i prepoznavanje akorda:** korisnik tapka tonove na fretboardu, a aplikacija prepozna koji akord daju.
5. **Pisanje tabulature preko fretboarda (aranžmani):** ništa se ne snima mikrofonom. Korisnik ručno upisuje tabulaturu, npr. aranžman:
   - tapka pozicije (žica + prag) na fretboardu, redom kako se sviraju
   - note idu u tab po vremenu i taktovima, s trajanjem nota i više nota odjednom (akordi, dvoglasi)
   - tab se može reproducirati i urediti
   - aplikacija analizira napisano: tonalitet, akordi koje note čine, ima li smisla, prijedlozi kako dalje

## Napomene za rad

- Commitaj kao "Toni Kopilas" <tonykopilas11@gmail.com> i pushaj na `main`.
- Nakon pusha provjeri CI run i release `latest`.
- Odgovaraj na hrvatskom.
