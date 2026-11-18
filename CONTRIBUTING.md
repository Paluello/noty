# Contribuire a Noty

Grazie! Prima di iniziare:

1. **Leggi** la [visione](docs/vision.md) e gli [ADR](docs/adr/README.md): una funzione che va contro i principi probabilmente non sarà accettata.
2. **Apri prima una issue** per le funzioni nuove; per i bug piccoli, vai pure direttamente con una PR.
3. **Cambi una decisione architetturale?** Aggiungi un ADR (template in `docs/adr/0000-template.md`).

## Setup
- Xcode (ultima versione stabile), macOS recente
- `git clone https://github.com/paluello/noty.git` → apri `Noty.xcodeproj` → scheme `Noty` → simulatore iPad
- Codice: `Packages/NotyKit` (`NotyCore` dati e formato, `NotyCanvas` editor) e `Noty/` (interfaccia SwiftUI)
- Le stringhe dell'interfaccia stanno in `Noty/Localizable.xcstrings`

## Regole
- Codice e commit in inglese; stile Swift API Design Guidelines, `swift-format`
- Test per tutto ciò che riguarda `NotyCore` (soprattutto il formato dei file: **mai perdere dati**)
- Le stringhe UI vanno nel String Catalog, sempre con la traduzione italiana
- Commit firmati DCO: `git commit -s`. Contribuendo accetti che il tuo codice sia distribuito sotto GPL-3.0-or-later con il permesso aggiuntivo per l'App Store ([LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md), [ADR-0022](docs/adr/0022-eccezione-app-store.md))
- Una PR = una modifica; screenshot o video per le modifiche UI

## Codice di condotta
Il progetto adotta il [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) (file `CODE_OF_CONDUCT.md` da aggiungere alla creazione del repository).
