# GoVia Mobile v0.1.63+64

## Android Auto – destination search

- Added **Søk** as the fifth top-level Android Auto option after `Ta opp`.
- Uses native Android Auto `SearchTemplate` for safe text/voice destination search.
- Search results are resolved through GoVia `/api/v1/map/geocode`.
- Selecting a result calculates a normal driving route through `/api/v1/map/route` from the current position.
- The result opens the existing GoVia trip preview.
- `Start tur` reuses the existing navigation screen, follow camera, guidance, controls and stop-confirmation flow.
- Search-created routes are temporary and are not automatically stored as planned trips.
- Existing phone/DHU state-isolation architecture is unchanged.

Version: **0.1.63+64**
