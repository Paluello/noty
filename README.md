# Noty


App per prendere appunti a mano su iPad, **semplice, gratuita, senza pubblicità e open source**.
È pensata per lo studio: quaderni organizzati in cartelle, pagine stampabili e scrittura con Apple Pencil.

## Principi
- **Semplice prima di tutto**: poche funzioni, fatte bene.
- **Niente pubblicità, abbonamenti o limiti artificiali.**
- **I tuoi dati sono tuoi**: file aperti e documentati, esportabili in PDF in qualsiasi momento.
- **Nativa Apple**: SwiftUI + PencilKit, aspetto minimal coerente con iPadOS.

## Stato
Versione 0.1 in sviluppo: le funzioni base ci sono, mancano le prove su iPad vero. Vedi [roadmap](docs/roadmap.md).

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

## Installazione (quando ci sarà una build)
- **Da sorgente**: apri `Noty.xcodeproj` con Xcode 26, scegli un iPad (o il simulatore) e premi Run. Test: `cd Packages/NotyKit && xcodebuild test -scheme NotyKit-Package -destination 'platform=iOS Simulator,name=<iPad>'`.
- **AltStore**: file `.ipa` allegato a ogni release su GitHub.

## Contribuire
Leggi [CONTRIBUTING.md](CONTRIBUTING.md).

## Licenza
GPL-3.0-or-later. Distribuzione tramite AltStore; vedi [ADR-0011](docs/adr/0011-licenza-gpl.md).
