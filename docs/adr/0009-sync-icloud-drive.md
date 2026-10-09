# ADR-0009: Sync tramite iCloud Drive, nessun server
- **Stato**: Sostituito da [ADR-0018](0018-sync-cartella-scelta.md) · **Data**: 2026-10-09

## Decisione
- La libreria sta nel **container iCloud Drive dell'app** (visibile in File → iCloud Drive → Noty). Se iCloud è disattivato, sta in locale (In questo iPad → Noty).
- I conflitti vengono risolti **per pagina**: se due versioni di una pagina divergono, teniamo entrambe ("Pagina 4 (conflitto)") e non perdiamo mai dati.
- **NAS (DAT-6, futuro)**: possibilità di scegliere una cartella esterna tramite il document picker e un security-scoped bookmark; funziona con qualsiasi provider supportato dall'app File (SMB, Synology Drive, Nextcloud…). "Esporta tutto" copre già il backup verso il NAS.

## Alternative considerate
- CloudKit con database strutturato: non c'è file system leggibile e ci si lega di più ad Apple.
- Server nostro: costi, privacy, manutenzione. No.

## Conseguenze
+ Gratuito, nessun account. − Il sync di iCloud non è istantaneo; il funzionamento delle cartelle esterne via SMB va testato bene.
