# ADR-0011: Licenza GPL-3.0-or-later e distribuzione tramite AltStore
- **Stato**: Sostituito in parte da [ADR-0022](0022-eccezione-app-store.md) (App Store) · **Data**: 2026-10-09

## Contesto
Progetto pubblico con contributi; vogliamo garantire che il codice e i fork restino aperti.

## Decisione
- Licenza **GPL-3.0-or-later**, senza eccezioni.
- Contributi con **DCO** (`Signed-off-by` nei commit), senza CLA.
- Distribuzione: release su GitHub con un `.ipa` per **AltStore / SideStore** (gratis, con Apple ID personale e rinnovo ogni 7 giorni). Niente App Store.

## Alternative considerate
- GPL + eccezione App Store: scartata, perché l'App Store non è un obiettivo.
- MPL-2.0 / MIT: meno protettive verso i fork chiusi.

## Conseguenze
+ Nessun costo, codice sempre libero.
− La FSF considera i termini dell'App Store incompatibili con la GPL. Se in futuro si volesse pubblicare sull'App Store, servirebbe il consenso di **tutti** i contributori per aggiungere un'eccezione: va deciso con un nuovo ADR, sapendo che diventa più difficile man mano che i contributori aumentano.
