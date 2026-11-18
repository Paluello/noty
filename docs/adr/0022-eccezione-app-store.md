# ADR-0022: Eccezione alla GPL per l'App Store
- **Stato**: Accettato · **Data**: 2026-11-18
- **Sostituisce in parte**: ADR-0011 (restano GPL-3.0-or-later, DCO e distribuzione con AltStore)

## Contesto
L'ADR-0011 escludeva l'App Store. Ora l'obiettivo è pubblicare Noty sull'App Store quando le
donazioni ricorrenti copriranno i 99 € annui dell'Apple Developer Program.

La FSF considera i termini dell'App Store incompatibili con la GPL. Per pubblicare serve
un'eccezione nella licenza, accettata da tutti i titolari dei diritti sul codice. Oggi il
titolare è uno solo, quindi è il momento più semplice per aggiungerla: con ogni nuovo
contributore diventerebbe più difficile.

## Decisione
- Noty resta sotto **GPL-3.0-or-later**, con un **permesso aggiuntivo** (sezione 7 della GPL)
  che consente la distribuzione tramite App Store e TestFlight. Il testo è in
  [`LICENSE-EXCEPTION.md`](../../LICENSE-EXCEPTION.md).
- Il permesso vale solo se il codice sorgente corrispondente resta disponibile sotto
  GPL-3.0-or-later.
- Chi contribuisce accetta che il proprio codice sia distribuito con lo stesso permesso.
  Lo dice `CONTRIBUTING.md`, e il DCO (`Signed-off-by`) lo conferma.
- AltStore e SideStore restano il canale principale finché l'App Store non è finanziato.
  Il link "Sostieni Noty" compare solo nella build AltStore: l'App Store non consente
  donazioni esterne all'acquisto in-app.

## Alternative considerate
- **Restare senza App Store** (ADR-0011): installare con AltStore è scomodo (rinnovo ogni
  7 giorni) e taglia fuori molti studenti.
- **Passare a MPL-2.0 o MIT**: compatibili con l'App Store, ma permettono fork chiusi.
- **Aggiungere l'eccezione più avanti**: servirebbe il consenso di ogni contributore
  arrivato nel frattempo.

## Conseguenze
+ Si può pubblicare sull'App Store senza cambiare licenza.
+ Il codice e le versioni modificate restano liberi: chi distribuisce deve comunque
  pubblicare il sorgente sotto GPL.
− Chi riusa parti di Noty in un progetto GPL senza eccezione può togliere il permesso
  aggiuntivo (sezione 7 della GPL): quella copia non andrà sull'App Store.
− Non è un parere legale. Prima della pubblicazione conviene far rileggere il testo.
