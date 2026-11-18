# Guida alla documentazione

- Aggiornato: 2026-11-18
- Risponde a: a che punto è Noty, com'è fatta e dove trovare ogni documento

Per installare Noty basta il [README](../README.md). Questa guida è per chi vuole capire il
progetto o lavorarci.

> **Stato: versione 0.6.0**, prima release per AltStore e SideStore. Libreria, scrittura,
> forme, testo e immagini, registrazione delle lezioni, ricerca nella scrittura ed
> esportazione sono implementate. L'editor della 0.6 (tela unica, barra in Liquid Glass)
> è stato provato su iPad il 18 novembre 2026; restano da verificare su iPad vero alcuni
> casi elencati nella [roadmap](roadmap.md).

## Come è fatta
L'app è `Noty.xcodeproj` (interfaccia SwiftUI in `Noty/`). La logica sta nel pacchetto
`Packages/NotyKit`: `NotyCore` (modello, formato `.noty`, libreria, PDF, audio) e
`NotyCanvas` (editor PencilKit). Dettagli in [architettura](architecture.md).

## Documenti
| Documento | Contenuto |
|---|---|
| [Visione](vision.md) | Per chi è, cosa fa e cosa non farà |
| [Requisiti](requirements.md) | Funzioni per versione, con priorità |
| [Roadmap](roadmap.md) | Milestone e stato di ogni versione |
| [Architettura](architecture.md) | Moduli, dati, prestazioni, test |
| [Formato dei file](file-format.md) | Com'è fatto un quaderno `.noty` |
| [UX: schermate](ux/screens.md) | Struttura delle schermate |
| [UX: flussi](ux/flows.md) | Percorsi principali dell'utente |
| [UX: gesti e input](ux/gestures.md) | Pencil, dita, tastiera |
| [Identità visiva](brand.md) | Icone e colori |
| [ADR](adr/README.md) | Registro delle decisioni |
| [Domande aperte](open-questions.md) | Cose ancora da decidere |

## Lingua
L'app è in inglese e italiano. Questa documentazione è in italiano e sarà tradotta in
inglese prima della 1.0; codice, issue e commit sono in inglese
([ADR-0015](adr/0015-localizzazione-e-lingua-docs.md)).
