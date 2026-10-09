# ADR-0014: Testo e immagini come elementi separati dal disegno
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
Caselle di testo e immagini sono **elementi** (`id`, `kind`, `frame`, `rotation`, `z`, contenuto) salvati in `pages/<uuid>.json` e disegnati con SwiftUI **sotto** la tela PencilKit, così si può scrivere sopra le immagini. Si modificano con uno strumento "Selezione elementi"; il lazo di PencilKit agisce solo sui tratti.

## Conseguenze
+ Testo modificabile e immagini a piena risoluzione. − Due sistemi di selezione da rendere coerenti nella UX.
