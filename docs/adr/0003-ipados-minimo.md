# ADR-0003: Supporto solo per l'ultima versione maggiore di iPadOS
- **Stato**: Sostituito da [ADR-0024](0024-ipados-18.md) · **Data**: 2026-10-09

## Decisione
Il deployment target è l'**ultima versione maggiore di iPadOS** al momento dell'1.0 (oggi iPadOS 26). Lo alziamo al massimo una volta l'anno, con un nuovo ADR.

## Conseguenze
+ API SwiftUI/PencilKit recenti (Observation, nuovi inchiostri, squeeze della Pencil Pro) senza `#available`.
− Escluse le persone con iPad molto vecchi.
