# GoVia Mobile v0.1.36 – Trip Flow, Place Names & Android Auto Cockpit

## v0.1.36+37

### Turplanlegging
- Ny tydelig slutt på planleggingen: **Lagre tur** eller **Start nå**.
- `Lagre tur` legger turen direkte i **Turer → Planlagt**.
- `Start nå` lagrer turen automatisk og åpner navigasjon direkte uten unødvendige mellomskjermer.
- Lagrede planlagte turer persisteres lokalt med rutegeometri og manøvre og overlever app-restart.
- Planlagt tur har en direkte **Start tur**-handling i turdetaljen.

### Stedsnavn
- `Bruk min posisjon` gjør reverse geocoding og bruker menneskelesbart vei-/stedsnavn.
- Koordinater brukes fortsatt internt som lat/lon, men ikke som presentasjonsnavn.
- Ved manglende reverse-geocoding brukes `Her` som fallback, ikke rå koordinater.

### Android Auto
- Ekte Lys / Mørk / Automatisk er beholdt.
- Mørk kartstil er løftet for bedre kontrast på projiserte skjermer.
- Navigasjonskortet er gjort mindre og mer kompakt for å frigjøre kartflate.
- REC-kortet er gjort mindre og mindre dominerende.
- Trip-tekst i host-estimat bruker renset tur-/stedsnavn.
- Kotlin visibility-fixen fra v0.1.35 er beholdt.

### Verifikasjon
- Oppdatert statisk verifier.
- Ny regresjonstest for reverse geocoding, lokal lagring og direkte lagre/start-flyt.
- Rettet syntaksfeil i Android Auto cockpit-testfilen.
