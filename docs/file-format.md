# Formato dei file di Noty (versione 1)

I dati di Noty sono **file normali**, leggibili anche senza l'app (ADR-0004, ADR-0005).

## La libreria
La libreria è la cartella *Documenti* dell'app, visibile nell'app File in **Su iPad › Noty**.
- Ogni **cartella** della libreria è una cartella vera.
- Ogni **quaderno** è una cartella con estensione `.noty`.
- `.noty-library.json` (nascosto): preferiti e quaderni recenti, riferiti all'`id` dei quaderni (ADR-0017).
- `.Trash/` (nascosta) contiene gli elementi eliminati: una sottocartella per elemento, con `info.json` (`originalRelativePath`, `deletedAt`). Dopo 30 giorni vengono cancellati.

## Un quaderno: `Nome.noty/`
```
Nome.noty/
├── notebook.json
├── pages/<uuid>.drawing
├── assets/cover-xxxxxxxx.jpg   (solo se la copertina è un'immagine)
└── snapshot.pdf                 (copia PDF, rigenerata alla chiusura)
```

### `notebook.json`
```json
{
  "formatVersion" : 1,
  "id" : "6F1C…",
  "title" : "Analisi 1",
  "cover" : { "color" : { "index" : 3 } },
  "paper" : "lined",
  "orientation" : "portrait",
  "pageIDs" : [ "A1B2…", "C3D4…" ],
  "createdAt" : "2026-10-09T10:15:00Z",
  "modifiedAt" : "2026-10-09T11:02:41Z"
}
```
| Campo | Valori |
|---|---|
| `cover` | `{"color": {"index": 0…11}}` oppure `{"image": {"fileName": "cover-….jpg"}}` |
| `paper` | `blank`, `lined`, `grid`, `dotted` |
| `orientation` | `portrait`, `landscape`; le pagine sono sempre A4 (595 × 842 pt) |
| `pageIDs` | ordine delle pagine; ogni id corrisponde a `pages/<id>.drawing` |
| date | ISO 8601, precisione al secondo |

Un'app che legge un `formatVersion` più alto di quello che conosce deve rifiutarsi di modificare il quaderno.

### `pages/<uuid>.drawing`
I tratti della pagina, nel formato `PKDrawing.dataRepresentation()` di Apple PencilKit. Se il file manca, la pagina è vuota.
Lo sfondo (righe, quadretti, puntini) **non** è nel disegno: viene disegnato da Noty in base a `paper`.

### `snapshot.pdf`
Un PDF A4 con tutte le pagine (sfondo e tratti), rigenerato quando chiudi il quaderno. Serve a leggere le note ovunque, anche senza Noty.

## Scritture sicure
Ogni file viene scritto in modo atomico: prima su un file temporaneo, poi con una sostituzione. Una pagina viene salvata circa 1 secondo dopo l'ultimo tratto, quando la pagina esce dallo schermo, quando chiudi il quaderno e quando l'app va in background.
