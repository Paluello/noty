# ADR-0023: Barra dell'editor in capsule di vetro, flottanti sopra la pagina
- **Stato**: Accettato · **Data**: 2026-11-15
- **Sostituisce in parte**: ADR-0021 (resta valido: posizione unica in alto, due righe, opzioni sempre visibili, bersagli da 44 pt)

## Contesto
La barra fissa e opaca di ADR-0021 funziona, ma stona con il resto dell'app: la libreria usa il Liquid Glass di iPadOS 26, l'editor una fascia bianca piena con divisori. La vecchia barra flottante era stata tolta per tre difetti (bersagli piccoli, pagina coperta, opzioni dietro un secondo tocco), non perché fosse di vetro.

## Decisione
La barra resta in alto e su due righe, ma diventa **capsule di vetro flottanti** sopra la tela:
1. tre capsule: indietro + titolo e pagina · strumenti · annulla, ripeti, registra, "⋯";
2. una capsula centrata con le opzioni dello strumento attivo, che cambia forma con lo strumento.

- La tela occupa tutto lo schermo e ha un **margine superiore** pari all'altezza della barra: in cima al quaderno la prima pagina parte sotto le capsule. Scorrendo, le pagine passano sotto il vetro.
- Lo strumento attivo ha lo sfondo pieno del colore d'accento; ogni bersaglio resta di almeno 44 pt.
- Dietro la tela c'è lo stesso sfondo sfumato della libreria. Solo Liquid Glass di sistema (`glassEffect` interattivo dentro un `GlassEffectContainer`): niente materiali, sfocature o riempimenti dipinti; lo strumento attivo è vetro colorato con l'accento.
- Un indicatore di pagina in vetro, non toccabile, sta in basso a destra.
- In modalità concentrazione il margine si azzera insieme alla barra.

## Alternative considerate
- Barra fissa a tutta larghezza in materiale traslucido: meno lavoro, ma resta una fascia e non usa le forme della libreria.
- Capsule spostabili o laterali: già scartate in ADR-0021.

## Conseguenze
+ Editor coerente con la libreria; la pagina si vede attorno e sotto la barra.
− Scorrendo, l'inchiostro vicino al bordo alto passa sotto il vetro (in cima al quaderno no).
− Su carta scura o tratti fitti le icone vanno verificate su iPad vero.
