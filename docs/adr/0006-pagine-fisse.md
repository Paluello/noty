# ADR-0006: Pagine a dimensione fissa con sfondo separato
- **Stato**: Accettato, in parte sostituito da ADR-0020 (una sola tela per tutto il quaderno) · **Data**: 2026-10-09

## Decisione
- Pagine **solo A4** (595×842 pt), verticali o orizzontali. Un `PKCanvasView` **per pagina visibile**, riciclato durante lo scorrimento verticale (come le celle di una lista), con zoom gestito dal contenitore.
- Lo sfondo (righe, quadretti, puntini) è **disegnato a parte**, in vettoriale, e non fa parte del `PKDrawing`: la gomma non lo cancella e nel PDF resta nitido.

## Alternative considerate
- Un'unica tela infinita: non è stampabile e diventa lenta con centinaia di pagine.

## Conseguenze
− Un tratto non può attraversare due pagine (comportamento normale, come su carta).
− Va gestita con cura la memoria: solo 3–5 tele attive alla volta.
