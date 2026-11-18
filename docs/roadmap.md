# Roadmap

| Versione | Tema | Contenuto (ID requisiti) |
|---|---|---|
| **0.1 — "Scrivo"** | MVP usabile | ORG-1,2,3,6,9 · PAG-1,2,4 · STR-1,2,3,5,6,10,12 · UI-3,5 · DAT-1,3,5 |
| **0.2 — "Mi organizzo"** | Comfort | ORG-4,5,7 · PAG-6 · STR-4,11 · UI-1,2,4,6 · DAT-4 |
| **0.3 — "Arricchisco"** | Contenuti | STR-7,8,9 · PAG-3,5 · DAT-2 (iCloud), DAT-7 (Face ID) |
| **0.4 — "Ascolto"** | Audio | AUD-1,2,3 |
| **0.5** | Ricerca | ORG-8 (OCR con Vision, on-device) |
| **0.6** | Editor rifatto | Tela unica (ADR-0020), barra in Liquid Glass (ADR-0023); DAT-6 anticipato alla 0.3 (ADR-0018) |
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

## Stato della 0.4 e della 0.5
Implementato: registrazione audio a blocchi da un minuto, che continua anche in background; pausa e ripresa; riproduzione con velocità variabile; inchiostro sbiadito dopo il punto che si ascolta; tocca un tratto per sentire cosa si diceva in quel momento (ADR-0010). Ricerca nella scrittura a mano e nel testo delle pagine, sul dispositivo, con apertura sulla pagina trovata (ADR-0019).

Provato nel simulatore: registrazione (file su disco, barra con tempo, stop), riproduzione (barra, avanzamento), ricerca nel contenuto ("digitato" → Spike, pagina 1). Coperto dai test: linea del tempo con pause, millesimi nelle date, indice (anche con Vision vero), esclusione dei quaderni bloccati.

Corretti durante le prove:
- lo scorrimento poteva trasformare i tratti in scorrimenti (anche con la Pencil);
- il riconoscimento delle forme rielaborava l'ultimo tratto vecchio quando un gesto non aggiungeva nulla;
- le date delle registrazioni erano arrotondate al secondo.

Da verificare su iPad vero: registrazione con iPad bloccato, telefonate durante la registrazione, inchiostro sbiadito e salto toccando un tratto, riconoscimento di grafie vere.

## Stato della 0.6: editor rifatto
Motivo: su iPad vero la penna era in ritardo, il tratto sfarfallava, la scrittura era sfocata con lo zoom e i comandi erano scomodi da toccare.

Implementato: una sola tela PencilKit per tutto il quaderno, che scorre e zooma in modo nativo (ADR-0020); carta a tasselli, nitida a ogni zoom; salvataggio che non parte mai a metà tratto; barra fissa in alto su due righe con le opzioni dello strumento sempre visibili (ADR-0021). Rimosse le posizioni sinistra / destra / flottante della barra.

Da verificare su iPad vero: latenza e nitidezza con la Pencil, zoom, strumento Testo sopra la tela unica, ascolto con inchiostro sbiadito, apertura di quaderni lunghi (tempo e memoria), barra in Split View.

Aggiunto il 18 novembre 2026, prima della release: barra in capsule di Liquid Glass di sistema (ADR-0023); zoom fino al 30% con la pagina centrata; quattro grandezze del testo ed elenchi puntati e numerati; pulsante Inserisci separato per foto, file e scansioni; distanza di righe, quadretti e pallini per quaderno, con il valore predefinito nelle Impostazioni; eliminazione delle palette con conferma. Provato da Mattia su iPad il 18 novembre 2026.
