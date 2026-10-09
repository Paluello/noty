# ADR-0017: Preferiti e recenti riferiti all'id del quaderno
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
ORG-5 chiede Preferiti e Recenti. Secondo ADR-0005 la libreria è fatta di cartelle vere, che l'utente può rinominare o spostare anche dall'app File.

## Decisione
I preferiti e i recenti (al massimo 20) sono salvati in `.noty-library.json`, nella cartella principale della libreria, e fanno riferimento al campo `id` di `notebook.json`, non al percorso del file. Per trovare i quaderni, Noty scorre tutta la libreria, che è un'operazione veloce anche con centinaia di quaderni.

## Conseguenze
+ Rinominare o spostare un quaderno, anche dall'app File, non lo toglie dai preferiti.
+ Un quaderno duplicato riceve un nuovo id e non eredita lo stato di preferito.
− Ogni apertura dei Preferiti legge tutti i `notebook.json`. Se diventasse lento, si potrà aggiungere un indice in cache (ADR-0005 lo prevede).
