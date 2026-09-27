# GoVia Mobile v0.1.8 – Transport-Aware Platform & Discover

## Changes
- GoVia core is explicitly transport-aware: motorcycle, car, walking, cycling, train and ferry.
- Plan Trip asks for transport type before route profile.
- Route profiles are transport-specific and only expose behaviors the client can execute honestly.
- Motorcycle retains Fastest / Balanced / Curvy / Max Curvy candidate ranking.
- Car, cycling and walking use time/distance based profiles instead of motorcycle terminology.
- Ferry stages never generate fake road geometry.
- Roundtrip UI is transport-aware while the dedicated generator remains a later backend item.
- Added Discover with transport filters.
- Added public route detail, publish route and saved routes.
- Publishing creates a transport-aware public route snapshot via the GoVia domain API.
- Public routes can be cloned into the user's own trip/routing state.
- Favorites are wired through the publishedRoute repository.
- No dummy community routes are shown in production.

## Backend pairing
Requires GoVia platform v0.86.179 or newer for live Discover/publishing/favorites.
Photo metadata exists in the backend foundation, while binary photo upload/storage UI is still a later community increment.

## Version
0.1.8+9
