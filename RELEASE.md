# GoVia Mobile v0.1.49+50

## Android Auto process isolation

- Android Auto `CarAppService` now runs in a dedicated `:car` process.
- Car ride recording service runs in the same dedicated car process.
- Flutter phone UI remains in the main process and is no longer taken down by a car-session failure.
- Cross-process state sync moved from SharedPreferences to a small AtomicFile-backed bridge.
- Recorded rides also use the file bridge with a file lock for safe drain/append behavior.
- Existing bridge data is migrated from legacy SharedPreferences on first use.
- Locked GoVia Home/Trips/Navigation visual work is preserved.
- Car API 7+ still uses MapWithContentTemplate without duplicate host floating buttons.

Version: `0.1.49+50`
Tag: `v0.1.49`
