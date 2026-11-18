# Contribuire a Noty

Grazie! Prima di iniziare:

1. **Leggi** la [visione](docs/vision.md) e gli [ADR](docs/adr/README.md): una funzione che va contro i principi probabilmente non sarà accettata.
2. **Apri prima una issue** per le funzioni nuove ([proposta](https://github.com/Paluello/noty/issues/new?template=feature.md)); per i bug piccoli vai pure direttamente con una PR.
3. **Cambi una decisione architetturale?** Aggiungi un ADR (template in `docs/adr/0000-template.md`).

La [guida alla documentazione](docs/README.md) spiega com'è fatto il progetto.

## Setup
- macOS recente con **Xcode 26** (l'app richiede iPadOS 26, [ADR-0003](docs/adr/0003-ipados-minimo.md))
- `git clone https://github.com/Paluello/noty.git`, apri `Noty.xcodeproj`, scheme `Noty`, scegli un iPad o il simulatore e premi Run
- Codice: `Packages/NotyKit` (`NotyCore` dati e formato, `NotyCanvas` editor) e `Noty/` (interfaccia SwiftUI)
- Le stringhe dell'interfaccia stanno in `Noty/Localizable.xcstrings`

## Test
```sh
cd Packages/NotyKit
xcodebuild test -scheme NotyKit-Package -destination 'platform=iOS Simulator,name=<iPad>'
```
La CI (`.github/workflows/tests.yml`) compila l'app ed esegue i test a ogni push e a ogni PR.

## Regole
- Codice, commenti, issue e commit in inglese; stile Swift API Design Guidelines, `swift-format`
- Test per tutto ciò che riguarda `NotyCore` (soprattutto il formato dei file: **mai perdere dati**)
- Le stringhe UI vanno nel String Catalog, sempre con la traduzione italiana
- Nell'interfaccia si usa solo il Liquid Glass di sistema (`glassEffect`, `GlassEffectContainer`, stili `.glass`): niente imitazioni con materiali, sfocature o riempimenti dipinti ([ADR-0023](docs/adr/0023-barra-in-vetro-flottante.md))
- Commit firmati DCO: `git commit -s`. Contribuendo accetti che il tuo codice sia distribuito sotto GPL-3.0-or-later con il permesso aggiuntivo per l'App Store ([LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md), [ADR-0022](docs/adr/0022-eccezione-app-store.md))
- Una PR = una modifica; screenshot o video per le modifiche UI

## Pubblicare una release (manutentori)
1. Aggiorna `MARKETING_VERSION` nel progetto e la [roadmap](docs/roadmap.md).
2. Crea e invia il tag: `git tag -a v0.6.0 -m "Noty 0.6" && git push origin v0.6.0`.
3. La Action `Release` compila l'`.ipa` non firmato con il flag `ALTSTORE` e prepara una release in bozza con `Noty.ipa` allegato.
4. Scrivi le note e pubblica la release. Il sito [noty.paluello.me](https://noty.paluello.me) e la sorgente `altstore.json` la mostrano al deploy successivo.

## Codice di condotta
Il progetto adotta il [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
