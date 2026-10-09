# ADR-0005: Il file system è la fonte di verità, l'indice è solo una cache
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
Le cartelle della libreria sono **cartelle reali**; i quaderni sono pacchetti `.noty` (ADR-0004). Preferiti, recenti, ordinamento manuale e posizione di lettura stanno in `.noty-library.json` alla radice della libreria. Un indice in memoria (eventualmente SwiftData come cache) serve solo a rendere la griglia veloce e si può ricostruire in qualsiasi momento.

## Conseguenze
+ La libreria si può sfogliare dall'app File, si può fare backup e usare un NAS (DAT-6) senza logica speciale.
− Le modifiche esterne vanno osservate (`NSFilePresenter` / `NSMetadataQuery`).
