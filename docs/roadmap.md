# Roadmap

| Versione | Tema | Contenuto (ID requisiti) |
|---|---|---|
| **0.1 — "Scrivo"** | MVP usabile | ORG-1,2,3,6,9 · PAG-1,2,4 · STR-1,2,3,5,6,10,12 · UI-3,5 · DAT-1,3,5 |
| **0.2 — "Mi organizzo"** | Comfort | ORG-4,5,7 · PAG-6 · STR-4,11 · UI-1,2,4,6 · DAT-4 |
| **0.3 — "Arricchisco"** | Contenuti | STR-7,8,9 · PAG-3,5 · DAT-2 (iCloud), DAT-7 (Face ID) |
| **0.4 — "Ascolto"** | Audio | AUD-1,2,3 |
| **0.5** | Ricerca | ORG-8 (OCR con Vision, on-device) |
| **0.6** | Libertà | DAT-6 (cartella esterna/NAS) |
| **1.0** | Stabile | Bug fix, accessibilità, docs in inglese, release AltStore stabile |
| **dopo la 1.0** | | Viewer iPhone (ADR-0016), annotazione PDF, cifratura |

## Prima di scrivere codice (milestone 0)
- [x] Rispondere alle [domande aperte](open-questions.md)
- [x] Accettare o modificare gli ADR proposti
- [x] Repository git locale, licenza GPL, template
- [x] Repository privato su GitHub
- [x] CI (GitHub Actions): test e compilazione a ogni push
- [x] Prototipo "spike": 50 pagine A4 con PencilKit (ADR-0006). Funziona nel simulatore; resta da provare su un iPad vero con la Pencil

## Stato della 0.1 (9 ottobre 2026)
Implementata e provata nel simulatore: libreria con cartelle e sottocartelle, griglia con copertine, nuovo quaderno (carta, orientamento, copertina a colori, foto o file), rinomina/sposta/duplica/elimina con Cestino, editor con barra Liquid Glass, 5 strumenti, palette da 8 colori personalizzabili, 3 spessori per strumento, gomma parziale o a tratto intero, annulla/ripeti, gestione pagine, nuova pagina automatica, esportazione PDF, impostazioni, tema chiaro/scuro, italiano e inglese.

Da fare prima di chiudere la 0.1:
- [ ] Prova su iPad vero con Apple Pencil (fluidità, nitidezza dello zoom, gesti a due/tre dita)
- [x] Icona dell'app (provvisoria: proposta A in `docs/icon-proposals/`)
- [x] CI con test automatici

## Stato della 0.2
Implementato: Preferiti e Recenti nella barra laterale, ricerca in tutta la libreria (anche nelle sottocartelle, senza badare a maiuscole e accenti), ordinamento, righello, doppio tocco e squeeze della Pencil configurabili, barra degli strumenti in alto / a sinistra / a destra / flottante, modalità concentrazione, quaderni in finestre separate (Split View, Stage Manager), "Esporta tutto" in zip, etichette per VoiceOver.

Da verificare su iPad vero: gesti della Pencil, righello, barra laterale in orizzontale, finestre multiple.

## Stato della 0.3
Implementato: caselle di testo e immagini (da Foto, File o scansione di documenti), riconoscimento delle forme, colore della carta e cambio della carta di un quaderno esistente, blocco con Face ID (dell'app intera o del singolo quaderno), libreria in una cartella a scelta: iCloud Drive, NAS… (ADR-0018, sostituisce ADR-0009).

Provato nel simulatore: casella di testo, linea storta raddrizzata. Coperto dai test: forme, formato degli elementi, compatibilità con i quaderni vecchi.
Da verificare su iPad vero: cerchi e rettangoli con la Pencil, Face ID, scansione documenti, sincronizzazione con iCloud Drive e NAS.
Limiti noti: niente annulla per testo e immagini; nessuna unione di modifiche fatte in contemporanea su due dispositivi.
