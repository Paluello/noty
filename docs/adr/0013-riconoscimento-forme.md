# ADR-0013: Riconoscimento forme implementato in casa
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
PencilKit non offre un'API pubblica per riconoscere le forme (STR-7).

## Decisione
Rileviamo quando la Pencil resta ferma per circa 0,5 s a fine tratto; classifichiamo i punti del tratto (linea, cerchio/ellisse, rettangolo, triangolo, freccia) con un algoritmo geometrico semplice (stile $1 recognizer, più fitting); poi sostituiamo il `PKStroke` con uno generato, mantenendo inchiostro e colore. Modulo isolato e testabile in `NotyCanvas/ShapeRecognition`.

## Conseguenze
+ Nessuna dipendenza esterna. − Va calibrato con test reali; si può disattivare.
