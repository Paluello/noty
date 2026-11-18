# Architettura

```
NotyApp (target iPad)          ── SwiftUI: Libreria, Impostazioni, routing, finestre multiple
 ├── NotyCanvas (package)      ── Editor: tela PencilKit unica (ADR-0020), barra strumenti, lazo, forme, elementi, audio UI
 └── NotyCore   (package)      ── Modello, formato .noty, libreria su file system, export PDF, audio engine
                                    (nessuna dipendenza UI → riusabile dal viewer iPhone, ADR-0016)
```

## Modello (NotyCore)
- `Library`: radice in una cartella scelta dall'utente: sull'iPad, iCloud Drive o NAS (ADR-0018), albero di `Folder` e `NotebookRef`, metadati di `.noty-library.json`
- `Notebook`: `id`, `title`, `paper` (stile, spaziatura, colore), `cover` (colore o immagine), `orientation`, `pages: [PageRef]`, `locked`, `formatVersion`
- `Page`: `id`, `drawing: PKDrawing` (caricato su richiesta), `elements: [Element]`
- `Recording`: `id`, `startDate`, `segments`, `markers`
- `Palette`: 8 `Color`; `ToolState`: strumento, colore e spessore per ciascuno strumento

## Persistenza
- `NotebookStore` (actor): carica e salva le pagine in modo lazy, con debounce, scritture atomiche e `NSFileCoordinator`
- `ThumbnailRenderer`: in background, al salvataggio della pagina 1 o di quella visibile
- `PDFExporter`: `PKDrawing.image(from:scale:)` + sfondo vettoriale + elementi → `UIGraphicsPDFRenderer`

## Prestazioni (obiettivi)
| Metrica | Obiettivo |
|---|---|
| Apertura di un quaderno da 200 pagine | < 1 s |
| Memoria nell'editor | < 300 MB |
| Libreria con 100 quaderni: prima griglia | < 0,5 s |
| Audio: dati persi in caso di crash | ≤ 60 s |

## Test
- `NotyCore`: unit test (formato, migrazioni, conflitti, export)
- `NotyCanvas`: test del riconoscimento forme sui tratti registrati
- UI test sui flussi F1, F2, F7
- CI: GitHub Actions su macOS (build + test)
