# ADR-0021: Barra dell'editor fissa in alto, su due righe
- **Stato**: Accettato · **Data**: 2026-11-15
- **Sostituisce in parte**: ADR-0007 (resta valido: barra nostra invece di `PKToolPicker`)

## Contesto
La barra in vetro flottante, spostabile in quattro posizioni, aveva bersagli piccoli (colori da 24 pt a 3 pt l'uno dall'altro), copriva la pagina e nascondeva spessori e tipo di gomma dietro un secondo tocco sullo strumento già selezionato.

## Decisione
Una barra **fissa in alto**, sopra la pagina e non sovrapposta, su due righe:
1. **Comandi e strumenti**: indietro, titolo e pagina (apre le pagine), strumenti, annulla/ripeti, registra, menu "⋯".
2. **Opzioni dello strumento attivo**, sempre visibili: 3 spessori + 8 colori + righello per penna, matita ed evidenziatore; tipo di gomma; colori e inserimento immagini per il testo.

Ogni bersaglio è almeno 44×44 pt; lo strumento attivo ha lo sfondo pieno. Toccando lo spessore già selezionato si apre il cursore per regolarlo. Nelle finestre strette sparisce prima il titolo, poi gli strumenti scorrono in orizzontale.

Le posizioni sinistra / destra / flottante (UI-1) sono **rimosse**: quattro disposizioni rendevano ognuna peggiore. La modalità concentrazione resta.

## Conseguenze
+ Ogni azione frequente è a un tocco; la pagina non è mai coperta e non si sposta.
− La barra occupa circa 100 pt in alto (in modalità concentrazione sparisce).
