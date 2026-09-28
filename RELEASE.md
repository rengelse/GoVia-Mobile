# GoVia Mobile v0.1.61+62

## Android Auto process isolation

- Android Auto/MapLibre now runs in a dedicated `:car` process.
- Flutter phone navigation can no longer share the car display main thread.
- Car state is exchanged through an AtomicFile + file-lock bridge.
- The last valid car snapshot remains available when Android Auto starts directly from DHU.
- Recorded rides are transferred through the same process-safe bridge.
- Existing NavigationTemplate UI and cockpit behavior are unchanged.
