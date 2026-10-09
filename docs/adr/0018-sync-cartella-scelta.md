# ADR-0018: Sincronizzazione tramite una cartella scelta dall'utente
- **Stato**: Accettato · **Data**: 2026-10-09 · **Sostituisce**: ADR-0009

## Contesto
ADR-0009 prevedeva il container iCloud dell'app. Questo richiede l'entitlement iCloud, disponibile solo con l'Apple Developer Program a pagamento. Noty invece si installa con AltStore e un Apple ID gratuito (ADR-0011). In più si voleva poter usare anche un NAS (DAT-6).

## Decisione
- Per impostazione predefinita la libreria sta nella cartella Documenti dell'app (**Su iPad › Noty**).
- In Impostazioni › Sincronizzazione l'utente può scegliere **qualsiasi cartella dell'app File**: iCloud Drive, un NAS via SMB, Dropbox, Nextcloud… Noty salva un *security-scoped bookmark* e la riapre a ogni avvio.
- Quando cambia cartella, Noty chiede se copiarci i quaderni attuali. Non li sposta mai: l'originale resta dov'è.
- I file non ancora scaricati da iCloud (segnaposto `.Nome.icloud`) vengono richiesti con `startDownloadingUbiquitousItem` e compaiono all'aggiornamento successivo. Prima di aprire un quaderno, una lettura coordinata (`NSFileCoordinator`) aspetta che tutti i suoi file siano scaricati.
- La libreria si aggiorna quando l'app torna in primo piano.

## Conseguenze
+ Funziona con l'Apple ID gratuito e risolve insieme DAT-2 (sync) e DAT-6 (NAS).
+ I file restano normali file, leggibili ovunque (ADR-0005).
− Non c'è unione delle modifiche: se lo stesso quaderno viene modificato su due dispositivi senza connessione, vince l'ultima copia salvata da iCloud Drive (che di solito conserva l'altra come "conflitto"). La gestione dei conflitti per pagina (ADR-0009) resta da fare.
− Le modifiche fatte da un altro dispositivo mentre il quaderno è aperto non compaiono finché non lo si riapre.
− Da verificare su dispositivi veri: nel simulatore non c'è iCloud Drive.
