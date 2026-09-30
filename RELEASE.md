# GoVia Mobile v0.1.108+109 — Navigation Runtime Hardening

- Prefer provider `startPathIndex/endPathIndex` when selecting the active road speed limit on phone and Android Auto.
- Keep meter-based matching only as compatibility fallback.
- Reject stale/inaccurate recording fixes, suppress network fixes while fresh GPS exists, and reject implausible position jumps.
- No new UI feature work.
