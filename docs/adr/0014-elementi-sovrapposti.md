# ADR-0014: Testo e immagini come elementi separati dal disegno
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
Caselle di testo e immagini sono **elementi** (`id`, `kind`, `frame`, `rotation`, `z`, contenuto) salvati in `pages/<uuid>.json` e disegnati con SwiftUI **sotto** la tela PencilKit, così si può scrivere sopra le immagini. Si modificano con uno strumento "Selezione elementi"; il lazo di PencilKit agisce solo sui tratti.

## Conseguenze
+ Testo modificabile e immagini a piena risoluzione. − Due sistemi di selezione da rendere coerenti nella UX.

## Nota di implementazione (0.3)
Lo strumento si chiama **Testo e immagini** ("Aa"). Quando è attivo, l'inchiostro lascia passare i tocchi: un tocco sulla carta crea una casella, un tocco su un elemento lo seleziona, trascinandolo lo sposti, la maniglia lo ridimensiona (le immagini mantengono le proporzioni) e la ✕ lo elimina. Le immagini vengono ridotte a massimo 2000 px. **Le modifiche agli elementi non hanno ancora l'annulla.**
