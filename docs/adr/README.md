# Architecture Decision Records

Ogni decisione importante è registrata in un ADR (formato [Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)).
Un ADR accettato non si modifica: se la decisione cambia, si scrive un nuovo ADR che lo **sostituisce**.

Stati: `Proposto` · `Accettato` · `Sostituito da ADR-XXXX` · `Respinto`

| # | Titolo | Stato |
|---|---|---|
| [0000](0000-template.md) | Template | — |
| [0001](0001-registrare-le-decisioni.md) | Registrare le decisioni architetturali | Accettato |
| [0002](0002-swiftui-pencilkit.md) | App nativa con SwiftUI + PencilKit | Accettato |
| [0003](0003-ipados-minimo.md) | Supporto solo per l'ultima versione maggiore di iPadOS | Accettato |
| [0004](0004-formato-file.md) | Formato del quaderno: pacchetto aperto su file system | Accettato |
| [0005](0005-filesystem-fonte-di-verita.md) | Il file system è la fonte di verità, l'indice è solo una cache | Accettato |
| [0006](0006-pagine-fisse.md) | Pagine a dimensione fissa con sfondo separato | Accettato |
| [0007](0007-toolbar-personalizzata.md) | Barra strumenti personalizzata invece di PKToolPicker | Accettato |
| [0008](0008-input-pencil-dita.md) | Solo la Pencil disegna, le dita navigano | Accettato |
| [0009](0009-sync-icloud-drive.md) | Sync tramite iCloud Drive, nessun server | Sostituito da ADR-0018 |
| [0010](0010-audio.md) | Registrazione audio in background con sincronizzazione dei tratti | Accettato |
| [0011](0011-licenza-gpl.md) | Licenza GPL-3.0-or-later e distribuzione tramite AltStore | Sostituito in parte da ADR-0022 |
| [0012](0012-blocco-face-id.md) | Blocco Face ID: protezione dell'accesso, non cifratura (v1) | Accettato |
| [0013](0013-riconoscimento-forme.md) | Riconoscimento forme implementato in casa | Accettato |
| [0014](0014-elementi-sovrapposti.md) | Testo e immagini come elementi separati dal disegno | Accettato |
| [0015](0015-localizzazione-e-lingua-docs.md) | Localizzazione it/en e lingua della documentazione | Accettato |
| [0016](0016-iphone-viewer.md) | iPhone solo in consultazione, nello stesso progetto | Accettato |
| [0017](0017-preferiti-recenti-per-id.md) | Preferiti e recenti riferiti all'id del quaderno | Accettato |
| [0018](0018-sync-cartella-scelta.md) | Sincronizzazione tramite una cartella scelta dall'utente | Accettato |
| [0019](0019-ricerca-scrittura-vision.md) | Ricerca nella scrittura a mano con Vision, sul dispositivo | Accettato |
| [0020](0020-tela-unica.md) | Un'unica tela PencilKit che scorre e zooma da sola | Accettato |
| [0021](0021-barra-fissa-due-righe.md) | Barra dell'editor fissa in alto, su due righe | Accettato |
| [0022](0022-eccezione-app-store.md) | Eccezione alla GPL per l'App Store | Accettato |
