# ADR-0008: Solo la Pencil disegna, le dita navigano
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
`drawingPolicy = .pencilOnly` per impostazione predefinita; con le dita si scorre e si zooma; tocco a 2 dita = annulla, a 3 dita = ripeti. Doppio tocco e squeeze sono gestiti con `UIPencilInteraction` e azioni configurabili. Interruttore "Le dita scrivono" nelle Impostazioni.

## Conseguenze
+ Niente segni accidentali col palmo. − Senza Pencil l'app va prima configurata.
