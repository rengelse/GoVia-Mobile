# v0.1.41 – Android Auto UI Alignment

- Hjem bruker nå store GridTemplate-kort for `Turer` og `Ta opp` i stedet for en rå tekstliste.
- Aktiv tur vises som eget `Fortsett tur`-kort når det finnes en aktiv tur.
- Turer bruker `Planlagt`, `Aktiv` og `Fullført` som ekte Android Auto-faner på Car API 6+, med trygg ListTemplate-fallback på eldre host.
- Turpreview er fortsatt map-first, men med tydeligere tittelkort og egen kompakt KPI/statusstripe nederst.
- Aktiv navigasjon får større og mer lesbart manøverpanel, egen POI-rad og separat statuspill for ankomst og restdistanse.
- Kartkameraet legger kjøretøyet lavere i bildet under aktiv navigasjon slik at mer av ruten foran er synlig.
- Ruten er gjort smalere for bedre kartlesbarhet.
- Eksisterende light/dark/automatic-kartmodus og popToRoot-avslutningsflyt beholdes.
