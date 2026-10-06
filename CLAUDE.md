# Timetracker

- Po každej zmene kódu spusti `make install` (build, podpis, kópia do /Applications, reštart appky). Nepoužívaj `make run`.
- Pred prvým buildom na novom stroji `make cert`.
- Slovník pojmov je v `CONTEXT.md`, rozhodnutia v `docs/adr/`. Nové pojmy pridávaj tam, nie do kódu ako komentáre.
- Swift 6.4 + SwiftPM bez Xcode. Namiesto `@State` používaj `@Local` (`Views/Local.swift`), makro plugin v Command Line Tools chýba.
- Testy: `make test` (swift-testing, nie XCTest). Spúšťaj mimo sandboxu; ak zlyhá načítanie `TestingMacros` pluginu, spusti znova.
- Jeden súbor = jedna zodpovednosť, cieľ do ~150 riadkov. Store rozširuj cez `Store+<Oblasť>.swift`, nie do `Store.swift`.
- Každé rozhodnutie trackera (priradenie, task, idle, meeting, hook, summary) loguj cez `Log.write`, aby sa dalo spätne ladiť.
- UI farby, písmo a šrafovanie ber z `Views/Theme.swift` (`Theme.*`, `.figure()`, `Hatch`), nie systémové `.secondary`/`.blue`. Ručný čas = šrafovanie, AI draft = čiarkovaný obrys.
- Po zmene UI over výsledok cez `snapshot.txt` (viď README → Debugging) a pozri PNG.
