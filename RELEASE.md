# v0.1.42 – Android Auto Pixel Alignment

## Endret
- Låser de fire avtalte Android Auto-referansebildene som visuell baseline.
- Korrigerer cockpit-skalering for 800×400 DHU: geometri skaleres nå faktisk ned i stedet for å tvinges til minimum 0,78.
- Skiller geometrisk skalering fra tekstskalering slik at kort/ikoner plasseres riktig uten at tekst blir for liten.
- Preview er bygget om til fire separate KPI-kort: Distanse, Kjøretid, POI og Stopp.
- Navigation-overlay har strammere venstre kolonne, korrigert manøverkort, POI-kort og bunnstatus.
- Beholder eksisterende MapLibre/OpenFreeMap-arkitektur, dark/light/system, route rendering, opptak og popToRoot-exit.

## Versjon
- App: 0.1.42+43
- Tag: v0.1.42
