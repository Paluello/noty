# ADR-0010: Registrazione audio in background con sincronizzazione dei tratti
- **Stato**: Accettato · **Data**: 2026-10-09

## Contesto
AUD-1..3: deve essere "mega efficiente, non rompersi, funzionare in background".

## Decisione
- `AVAudioSession` in modalità `.record` / `.playAndRecord` e **background mode audio** abilitato.
- Registrazione AAC mono a 64 kbps (circa 30 MB/ora), con `AVAudioRecorder` o `AVAudioEngine`.
- **Resistenza ai crash**: scriviamo segmenti da 60 s (`audio/<rec>/000.m4a`, `001.m4a`…), uniti solo in fase di esportazione. Un crash fa perdere al massimo l'ultimo segmento.
- Vengono gestite interruzioni (chiamate, Siri) e cambio di route (cuffie): pausa automatica e ripresa con un marcatore.
- **Sincronizzazione**: ogni `PKStroke` ha `path.creationDate`; salviamo l'inizio della registrazione e calcoliamo l'offset di ogni tratto, quindi non serve un formato aggiuntivo per i tratti.

## Conseguenze
+ Il sync si ottiene "gratis" dai timestamp di PencilKit. − Il background audio va motivato nella review dell'App Store (lo è: registrazione di lezioni). Serve la permission del microfono.
