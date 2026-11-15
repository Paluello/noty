# ADR-0008: Solo la Pencil disegna, le dita navigano
- **Stato**: Accettato · **Data**: 2026-10-09

## Decisione
`drawingPolicy = .pencilOnly` per impostazione predefinita; con le dita si scorre e si zooma; tocco a 2 dita = annulla, a 3 dita = ripeti. Doppio tocco e squeeze sono gestiti con `UIPencilInteraction` e azioni configurabili. Interruttore "Le dita scrivono" nelle Impostazioni.

## Conseguenze
+ Niente segni accidentali col palmo. − Senza Pencil l'app va prima configurata.

## Nota di implementazione (0.6)
Con la tela unica (ADR-0020) lo scorrimento è quello nativo di `PKCanvasView`: con "solo Pencil" un dito scorre, quando anche le dita scrivono si scorre con due. La nota qui sotto descrive il vecchio contenitore.

## Nota di implementazione (0.4)
Lo scorrimento delle pagine accetta solo tocchi delle dita (`allowedTouchTypes = [.direct]`), quindi la Pencil scrive e basta. Quando anche le dita scrivono, si scorre con **due** dita. Con lo strumento Testo o durante l'ascolto di una registrazione, si scorre con un dito. Prima di questa correzione, un tratto con una componente verticale poteva diventare uno scorrimento.
