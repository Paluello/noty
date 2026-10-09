# ADR-0016: iPhone solo in consultazione, nello stesso progetto
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
Non serve "un'altra app": un progetto Xcode può produrre un'app universale (iPad + iPhone) oppure un secondo target che condivide il codice.

## Decisione
Dopo la 1.0 aggiungiamo un **target iPhone in sola lettura** che riusa `NotyCore` (formato e libreria) e legge da iCloud Drive: griglia, sfoglia le pagine, riproduce l'audio, esporta in PDF. Niente editing.

## Conseguenze
+ Grazie all'architettura a pacchetti, il costo è basso. Fino ad allora l'app dichiara solo il supporto a iPad.
