# ADR-0012: Blocco Face ID: protezione dell'accesso, non cifratura (v1)
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
`LocalAuthentication` per bloccare l'app intera e/o singoli quaderni (flag in `notebook.json`). La miniatura e lo snapshot PDF dei quaderni bloccati **non vengono generati**. Va detto chiaramente nella UI: *"il blocco impedisce l'apertura nell'app; i file restano leggibili da File"*. La cifratura vera (chiave nel Keychain) potrà arrivare con un ADR successivo.

## Conseguenze
+ Semplice e affidabile. − Non è una protezione forte: va comunicato in modo onesto.

## Nota di implementazione (0.3)
- Il blocco usa `.deviceOwnerAuthentication`: Face ID o Touch ID, con il codice come alternativa.
- **Se sull'iPad non c'è nessun codice impostato, non c'è niente da verificare: il quaderno si apre.** Nelle Impostazioni Noty lo segnala.
- Bloccando un quaderno si cancella il suo `snapshot.pdf`, che non viene più rigenerato finché resta bloccato.
