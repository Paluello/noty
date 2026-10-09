# ADR-0002: App nativa con SwiftUI + PencilKit
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
La scrittura con la Pencil (STR-1..3) deve avere latenza minima e predizione dei tratti. L'aspetto deve essere minimal "stile Apple".

## Decisione
- UI in **SwiftUI**; `PKCanvasView` (UIKit) incapsulato con `UIViewRepresentable`.
- Inchiostro e tratti con **PencilKit** (`PKDrawing`, `PKInkingTool`, `PKEraserTool`, `PKLassoTool`).
- Codice diviso in Swift Package locali: `NotyCore` (modello, formato file, nessuna UI), `NotyCanvas` (editor), `NotyApp` (target dell'app).

## Alternative considerate
- **Motore di disegno custom (Metal)**: massimo controllo, ma mesi di lavoro per eguagliare PencilKit. Si potrà riconsiderare solo se PencilKit si rivelasse limitante.
- **Flutter / React Native / web**: latenza peggiore della Pencil e aspetto meno nativo.

## Conseguenze
+ Latenza, predizione, gomma, lazo e righello già pronti.
− Il formato dei tratti `PKDrawing` è binario e proprietario di Apple: lo mitighiamo con l'export PDF (vedi ADR-0004).
− Nessun supporto Android/Windows.
