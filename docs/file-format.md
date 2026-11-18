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
├── pages/<uuid>.json            (caselle di testo e immagini della pagina, se ci sono)
├── assets/cover-xxxxxxxx.jpg    (solo se la copertina è un'immagine)
├── assets/image-<uuid>.jpg      (immagini inserite nelle pagine)
├── audio/<uuid>/recording.json  (una cartella per registrazione)
├── audio/<uuid>/000.m4a, 001.m4a…  (AAC mono, un file per minuto)
├── text-index.json              (testo riconosciuto nelle pagine, per la ricerca)
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
  "paperColor" : "white",
  "paperSpacing" : 20,
  "orientation" : "portrait",
  "isLocked" : false,
  "pageIDs" : [ "A1B2…", "C3D4…" ],
  "createdAt" : "2026-10-09T10:15:00Z",
  "modifiedAt" : "2026-10-09T11:02:41Z"
}
```
| Campo | Valori |
|---|---|
| `cover` | `{"color": {"index": 0…11}}` oppure `{"image": {"fileName": "cover-….jpg"}}` |
| `paper` | `blank`, `lined`, `grid`, `dotted` |
| `paperColor` | `white`, `ivory`, `gray`; se manca (quaderni della 0.1/0.2) vale `white` |
| `paperSpacing` | distanza tra righe, quadretti o pallini, in punti della pagina (8,5–42,5, cioè 3–15 mm); se manca vale quella standard dello stile (righe 24, quadretti e pallini 20). Aggiunto nella 0.6 |
| `isLocked` | `true` se il quaderno si apre solo con Face ID o il codice; se manca vale `false` |
| `orientation` | `portrait`, `landscape`; le pagine sono sempre A4 (595 × 842 pt) |
| `pageIDs` | ordine delle pagine; ogni id corrisponde a `pages/<id>.drawing` |
| date | ISO 8601, precisione al secondo |

Un'app che legge un `formatVersion` più alto di quello che conosce deve rifiutarsi di modificare il quaderno.

### `pages/<uuid>.drawing`
I tratti della pagina, nel formato `PKDrawing.dataRepresentation()` di Apple PencilKit. Se il file manca, la pagina è vuota.
Lo sfondo (righe, quadretti, puntini) **non** è nel disegno: viene disegnato da Noty in base a `paper`.

### `pages/<uuid>.json`
Caselle di testo e immagini della pagina, disegnate **sotto** l'inchiostro (ADR-0014). Le coordinate sono in punti della pagina A4; `frame` è `[[x, y], [larghezza, altezza]]`.
```json
[
  { "id" : "CC09…", "frame" : [[395, 60], [184, 44]],
    "content" : { "text" : { "string" : "Ciao", "fontSize" : 18, "colorHex" : "#000000" } } },
  { "id" : "A7F2…", "frame" : [[120, 300], [357, 238]],
    "content" : { "image" : { "fileName" : "image-1B2C….jpg" } } }
]
```

### `audio/<uuid>/recording.json`
```json
{ "id" : "749B…", "startDate" : "2026-10-09T13:39:16.250Z",
  "segments" : [ { "fileName" : "000.m4a", "startDate" : "2026-10-09T13:39:24.012Z", "duration" : 33.247 } ] }
```
Ogni segmento è un file audio; tra un segmento e l'altro può esserci una pausa. Il momento in cui è stato scritto un tratto (`PKStroke.path.creationDate`) si confronta con questi orari per sincronizzare audio e appunti.

### `text-index.json`
```json
{ "pages" : { "2C00BA40-…" : { "text" : "Appunti di prova…", "pageModifiedAt" : "2026-10-09T13:22:23Z" } } }
```
Testo riconosciuto da Vision per ogni pagina non vuota (ADR-0019). Non esiste per i quaderni bloccati.

### `snapshot.pdf`
Un PDF A4 con tutte le pagine (sfondo, testo, immagini e tratti), rigenerato quando chiudi il quaderno. Non esiste per i quaderni bloccati. Serve a leggere le note ovunque, anche senza Noty.

## Scritture sicure
Ogni file viene scritto in modo atomico: prima su un file temporaneo, poi con una sostituzione. Una pagina viene salvata circa 1 secondo dopo l'ultimo tratto, quando la pagina esce dallo schermo, quando chiudi il quaderno e quando l'app va in background.
