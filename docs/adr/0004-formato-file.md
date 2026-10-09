# ADR-0004: Formato del quaderno: pacchetto aperto su file system
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
Requisiti DAT-1, DAT-5, AUD-3, DAT-2 e la risposta "le note devono essere leggibili anche fuori dall'app". Abbiamo centinaia di pagine: non si può riscrivere tutto il quaderno a ogni tratto.

## Decisione
Ogni quaderno è una **cartella-pacchetto** `NomeQuaderno.noty`:
```
Analisi 1.noty/
├── notebook.json        # versione formato, id, titolo, copertina, sfondo, orientamento, ordine pagine, date
├── pages/
│   ├── <uuid>.drawing   # PKDrawing.dataRepresentation() — una pagina, un file
│   └── <uuid>.json      # elementi sovrapposti (testo, immagini) — ADR-0014
├── assets/<uuid>.heic   # immagini inserite (e cover.heic se la copertina è una foto)
├── audio/<uuid>.m4a     # registrazioni + <uuid>.json con i marcatori temporali
├── thumbnails/<uuid>.png
└── snapshot.pdf         # PDF rigenerato in background alla chiusura; attivo di base, disattivabile
```
- Salvataggio **per pagina**, atomico (scrittura su un file temporaneo, poi sostituzione), con debounce di circa 1 s dopo l'ultimo tratto e alla chiusura o messa in background.
- Si usa `NSFileCoordinator` per non entrare in conflitto con iCloud.
- `notebook.json` contiene `formatVersion`; le migrazioni sono gestite in `NotyCore`.
- Il formato è documentato in `docs/file-format.md` (da scrivere con la v0.1).

## Alternative considerate
- **Core Data / SwiftData con blob**: niente file leggibili, sync opaco, export più difficile.
- **Un solo file per quaderno**: riscritture enormi e conflitti iCloud su tutto il quaderno.
- **Formato tratti proprio (JSON/SVG)**: più aperto, ma con perdita di fedeltà e lento da convertire avanti e indietro. Si potrà aggiungere un export SVG in futuro.

## Conseguenze
+ Gli errori restano limitati alla singola pagina; sync granulare; `snapshot.pdf` è leggibile ovunque.
− Lo spazio occupato raddoppia con lo snapshot PDF (accettabile; c'è l'interruttore).
