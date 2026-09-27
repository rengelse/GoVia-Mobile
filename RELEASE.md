# GoVia Mobile v0.1.10 – Roundtrip, Chat Actions & Community Photos

## Added
- Real GoVia `/api/v1/map/roundtrip` integration with 1–3 routed candidates.
- Roundtrip start from current GPS position.
- Chat likes, edit and delete wired to the existing GoVia chat repository/RLS.
- Community route photo selection (up to 12 images) and upload to private Supabase Storage.
- Published route gallery using signed photo URLs.
- Start-place pin in Planlegg tur now acts as "Bruk min posisjon".

## Hardened
- Ferry is no longer presented as a primary trip/route transport type; it remains an embedded route segment.
- Train remains mapped exclusively to the rail/Entur routing contract.
- Map route rendering uses endpoint markers only for route geometry, preventing the prior white "eraser" effect from thousands of circle markers.

## Platform dependency
Requires GoVia Platform v0.86.180 for roundtrip and published-route image storage/metadata.
