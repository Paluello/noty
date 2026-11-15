# Schermate

## 1. Libreria (schermata iniziale)
Come Apple Music su iPadOS 26: una **barra delle sezioni in vetro**, in alto al centro, che con un pulsante diventa una **barra laterale** e torna indietro.
```
 ⚙︎        ╭──────────────────────────────────────────╮      ⇅  ＋
          │ ▯  Libreria   Preferiti   Recenti   🔍 │
          ╰──────────────────────────────────────────╯
 Libreria
 ┌────┐ ┌────┐ ┌────┐ ┌────┐
 │ 📁 │ │ 📁 │ │▤▤▤│ │▦▦▦│
 └────┘ └────┘ └────┘ └────┘
 Lingue  Uni…  Analisi Fisica
```
- **Barra in alto:** Libreria, Preferiti, Recenti e Cerca (la ricerca sta nella barra, come in Music).
- **Barra laterale** (pulsante ▯): in più le **Cartelle** di primo livello e il **Cestino**, con **Impostazioni** in fondo.
- La **griglia** mostra prima le cartelle e poi i quaderni; ogni quaderno mostra la sua copertina (colore o immagine) con il titolo.
- **Pressione prolungata** su un elemento: Apri in una nuova finestra, Preferito, Blocca, Rinomina, Copertina, Sposta, Duplica, Esporta PDF, Elimina.
- **Trascina e rilascia** un quaderno su una cartella della griglia per spostarlo.

## 2. Nuovo quaderno (foglio modale)
- Nome (proposto in automatico: "Senza titolo – 9 ott")
- Sfondo: Bianco · Righe · Quadretti · Puntini (anteprime grandi)
- Spaziatura: stretta / media / larga
- Orientamento: verticale / orizzontale (formato sempre A4)
- Copertina: uno tra 12 colori allegri (scelto a caso, si può cambiare), oppure "Foto…" / "File…"
- Pulsante **Crea** → il quaderno si apre direttamente sulla pagina 1

## 3. Editor del quaderno
```
┌──────────────────────────────────────────────────────────┐
│ ‹ Libreria  Analisi 1   ✎ ✏ ▮ ⌫ ◌ 📏 T 🖼 │●●●●●●●●│ ↶ ↷ ⋯ │
├──────────────────────────────────────────────────────────┤
│                 ┌────────────────────┐                    │
│                 │  pagina 3          │                    │
│                 │                    │          3 / 12    │
│                 └────────────────────┘                    │
└──────────────────────────────────────────────────────────┘
```
- **Barra fissa in alto, su due righe** (ADR-0021). Riga 1: indietro, titolo e pagina "3 / 12" (apre le pagine), strumenti, annulla/ripeti, registra, menu "⋯". Riga 2: le opzioni dello strumento attivo, sempre visibili (3 spessori, 8 colori, righello; tipo di gomma; immagini per il testo).
- Tocca lo spessore già selezionato per regolarlo; tieni premuto sui colori per cambiare palette.
- Le pagine scorrono **in verticale**, attaccate una all'altra e larghe quanto lo schermo, separate da una riga sottile; zoom con due dita, sempre nitido (ADR-0020).
- In fondo all'ultima pagina c'è "＋ Nuova pagina"; quando scrivi nella parte bassa dell'ultima pagina, ne viene aggiunta una nuova in automatico (si può disattivare nelle impostazioni).
- Menu ⋯: Vista pagine (miniature), Registra audio, Esporta PDF, Modalità concentrazione, Impostazioni del quaderno.

## 4. Vista pagine (miniature)
Griglia di pagine: riordina trascinando, seleziona più pagine, poi Duplica / Elimina / Esporta.

## 5. Barra audio (dalla v0.4)
Striscia sotto la barra strumenti: ● REC 12:34 · pausa · stop. In riproduzione: play, velocità, timeline; i tratti si "accendono" in sincrono.

## 6. Impostazioni
- **Scrittura**: le dita scrivono (sì/no), azione del doppio tocco/squeeze, tipo di gomma predefinito, riconoscimento forme sì/no, nuova pagina automatica
- **Palette**: gestione delle palette da 8 colori
- **Aspetto**: tema chiaro / scuro / di sistema
- **Archiviazione**: iCloud sì/no, posizione della libreria, Esporta tutto
- **Privacy**: blocco Face ID dell'app
- **Info**: versione, licenza GPL, link al codice sorgente
