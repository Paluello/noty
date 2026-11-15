# ADR-0020: Un'unica tela PencilKit che scorre e zooma da sola
- **Stato**: Accettato · **Data**: 2026-11-15
- **Sostituisce in parte**: ADR-0006 (resta valido: pagine A4, sfondo separato dal disegno)

## Contesto
Con ADR-0006 l'editor usava un `PKCanvasView` per pagina visibile dentro uno `UIScrollView` nostro, che faceva lo zoom applicando una trasformazione al contenitore. Su iPad vero questo dava tre difetti gravi:
- **scrittura sfocata con lo zoom**: PencilKit rasterizza l'inchiostro alla scala del *proprio* zoom; se a ingrandire è un contenitore esterno, i pixel vengono solo stirati. Forzare `contentScaleFactor` sulle sue viste interne non è supportato;
- **sfarfallio e tratto che sparisce**: lo stesso trucco, più il riassegnare `tool` a ogni aggiornamento di SwiftUI e il salvataggio che partiva a metà tratto, disturbavano il livello su cui PencilKit disegna il tratto in corso;
- **ritardo della penna**: i tocchi passavano prima dai gesti dello scroll esterno.

## Decisione
- **Un solo `PKCanvasView`** contiene l'inchiostro di tutto il quaderno ed è lui lo scroll view: scorrimento e zoom sono quelli nativi di PencilKit, che ridisegna i tratti nitidi a ogni livello di zoom.
- Le pagine sono **impilate senza spazi**, larghe quanto lo schermo, separate da una riga sottile (come in Notability).
- La carta e gli elementi (testo, immagini) stanno in un **sottofondo** dentro la tela, che segue lo zoom. La carta è disegnata con un `CATiledLayer`: solo i tasselli visibili, alla risoluzione dello zoom corrente.
- **Il formato su disco non cambia** (ADR-0004): un file per pagina. All'apertura i disegni vengono impilati; al salvataggio i tratti vengono divisi per pagina (in base al centro del tratto) e si scrivono solo le pagine cambiate.
- Lo strumento viene riassegnato solo quando cambia davvero; non si salva mai mentre la Pencil è appoggiata.

## Alternative considerate
- Tenere una tela per pagina e sincronizzare lo zoom di ognuna: fragile, e il ritardo dei gesti resta.
- Motore di disegno nostro (Metal): controllo totale, ma mesi di lavoro per eguagliare la latenza di PencilKit.

## Conseguenze
+ Latenza, nitidezza e gesti sono quelli di sistema (come Note di Apple).
+ Annulla/ripeti ha una sola cronologia per tutto il quaderno; un tratto può attraversare il bordo tra due pagine (viene salvato nella pagina che ne contiene il centro).
− All'apertura si leggono tutte le pagine: da misurare su quaderni molto lunghi (obiettivo: 200 pagine in meno di 1 s).
− Riordinare, duplicare o eliminare pagine ricarica la tela e azzera la cronologia di annullamento.
