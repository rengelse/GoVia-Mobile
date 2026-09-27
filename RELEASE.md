# v0.1.44 – Android Auto Home & Trips Alignment

Denne revisjonen retter Home/Turoversikt mot den låste GoVia-referansen og rydder den stale cockpit-testen.

## Endringer
- Home bruker nå GoVia-eid surface-layout i stedet for host GridTemplate-fliser.
- Turer bruker nå GoVia-eid surface-layout med Planlagt / Aktiv / Fullført-faner og horisontale turkort.
- Ekte GoVia-logoasset brukes i custom header.
- Fortsett tur vises som kompakt egen rad når aktiv tur finnes.
- Custom hit-zones åpner Turer, Ta opp, aktiv tur, faner og de synlige turkortene.
- `android_auto_cockpit_layout_test.dart` verifiserer faktisk status-pill struktur i stedet for en tilfeldig kommentarstreng.
- Navigasjon/cockpit fra v0.1.43 beholdes.

## Versjon
- App: 0.1.44+45
- Tag: v0.1.44
