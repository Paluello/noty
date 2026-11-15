# ADR-0007: Barra strumenti personalizzata invece di PKToolPicker
- **Stato**: Accettato, in parte sostituito da ADR-0021 (barra fissa in alto, niente posizioni) · **Data**: 2026-10-09

## Contesto
UI-1 (barra spostabile, in alto per impostazione predefinita), STR-5 (palette da 8 colori), STR-6 (spessori preferiti). `PKToolPicker` di sistema non permette palette fisse né di decidere la posizione.

## Decisione
Barra in SwiftUI fatta da noi, che imposta `canvasView.tool`. Stato degli strumenti in `ToolState` (Observable), salvato tra una sessione e l'altra. Posizioni: alto (predefinita), sinistra, destra, flottante.

## Conseguenze
+ Controllo totale dell'esperienza, simile a Notability.
− Dobbiamo reimplementare cose che `PKToolPicker` offre gratis (accessibilità, ecc.).
