# Noty

App per prendere appunti a mano su iPad, **semplice, gratuita, senza pubblicità e open source**.
Sito: **[noty.paluello.me](https://noty.paluello.me)**
È pensata per lo studio: quaderni organizzati in cartelle, pagine stampabili e scrittura con Apple Pencil.

## Principi
- **Semplice prima di tutto**: poche funzioni, fatte bene.
- **Niente pubblicità, abbonamenti o limiti artificiali.**
- **I tuoi dati sono tuoi**: file aperti e documentati, esportabili in PDF in qualsiasi momento.
- **Nativa Apple**: SwiftUI + PencilKit, aspetto minimal coerente con iPadOS.

## Stato
Versione 0.6 in sviluppo: libreria, scrittura, forme, testo e immagini, registrazione delle lezioni, ricerca nella scrittura, esportazione. Mancano le prove complete su iPad vero. Vedi [roadmap](docs/roadmap.md).

## Documentazione
| Documento | Contenuto |
|---|---|
| [Visione](docs/vision.md) | Per chi è, cosa fa e cosa non farà |
| [Requisiti](docs/requirements.md) | Funzioni per versione, con priorità |
| [UX: schermate](docs/ux/screens.md) | Struttura delle schermate |
| [UX: flussi](docs/ux/flows.md) | Percorsi principali dell'utente |
| [UX: gesti e input](docs/ux/gestures.md) | Pencil, dita, scorciatoie |
| [Architettura](docs/architecture.md) | Moduli, dati, formato dei file |
| [ADR](docs/adr/README.md) | Registro delle decisioni |
| [Roadmap](docs/roadmap.md) | Milestone |
| [Formato dei file](docs/file-format.md) | Com'è fatto un quaderno `.noty` |
| [Domande aperte](docs/open-questions.md) | Cose ancora da decidere |

## Installazione
- **AltStore / SideStore**: aggiungi la sorgente `https://noty.paluello.me/altstore.json` e ricevi gli aggiornamenti, oppure scarica l'`.ipa` allegato a ogni [release](https://github.com/paluello/noty/releases).
- **App Store**: arriverà quando le donazioni ricorrenti copriranno i 99 € annui dell'Apple Developer Program ([ADR-0022](docs/adr/0022-eccezione-app-store.md)).
- **Da sorgente**: apri `Noty.xcodeproj` con Xcode 26, scegli un iPad (o il simulatore) e premi Run. Test: `cd Packages/NotyKit && xcodebuild test -scheme NotyKit-Package -destination 'platform=iOS Simulator,name=<iPad>'`.

## Release
Un tag `v*` (es. `git tag -a v0.6.0 -m "Noty 0.6" && git push origin v0.6.0`) avvia la Action `Release`: compila l'`.ipa` non firmato con il flag `ALTSTORE` e prepara una release in bozza. Scrivi le note e pubblicala; il sito la mostra al deploy successivo.

## Sostieni
Noty resterà sempre gratuita. Se vuoi contribuire alle spese (Apple Developer Program, dominio, server): [Open Collective](https://opencollective.com/paluello). Entrate e spese sono pubbliche.

## Contribuire
Leggi [CONTRIBUTING.md](CONTRIBUTING.md).

## Licenza
GPL-3.0-or-later con un [permesso aggiuntivo per l'App Store](LICENSE-EXCEPTION.md). Vedi [ADR-0011](docs/adr/0011-licenza-gpl.md) e [ADR-0022](docs/adr/0022-eccezione-app-store.md).
