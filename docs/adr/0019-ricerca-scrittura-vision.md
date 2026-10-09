# ADR-0019: Ricerca nella scrittura a mano con Vision, sul dispositivo
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
ORG-8: cercare anche dentro gli appunti scritti a mano. Requisiti: niente server (vision.md), e niente dati personali fuori dal dispositivo.

## Decisione
- Ogni pagina viene disegnata come immagine (1240 px di larghezza: carta, testo, immagini, inchiostro) e letta con `RecognizeTextRequest` di Vision, in modalità *accurate*, in italiano e inglese. Tutto avviene **sul dispositivo**.
- Il testo trovato viene salvato in `text-index.json` dentro il quaderno, una voce per pagina con la data di modifica della pagina: si rielaborano solo le pagine cambiate.
- L'indice si aggiorna quando chiudi un quaderno e, in background, all'avvio dell'app.
- La ricerca della libreria mostra, sotto i risultati per nome, la sezione **"Nella scrittura a mano"** con i numeri di pagina; toccando un risultato il quaderno si apre su quella pagina.
- I quaderni bloccati non hanno indice (ADR-0012): bloccandone uno, il suo indice viene cancellato.

## Conseguenze
+ Funziona offline e protegge la privacy; l'indice si può leggere anche fuori da Noty.
− La qualità del riconoscimento dipende dalla grafia; da verificare su appunti veri.
− La prima indicizzazione di molti quaderni richiede tempo (circa mezzo secondo per pagina nel simulatore).
