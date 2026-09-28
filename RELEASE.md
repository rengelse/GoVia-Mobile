# GoVia Mobile v0.1.62+63


## Android Auto state ownership
- Removed Android Auto bridge writes from `notifyListeners()` completely.
- Phone-only navigation (`shellIndex`, loading, chat/profile UI and other presentation changes) can no longer trigger a car-state write.
- Android Auto sync is now scheduled only from explicit car-domain mutations such as trip selection/status, cloud trip refresh, voice setting and car theme changes.
- Keeps the persisted process-safe snapshot for direct DHU startup.

## Android Auto process isolation

- Android Auto/MapLibre now runs in a dedicated `:car` process.
- Flutter phone navigation can no longer share the car display main thread.
- Car state is exchanged through an AtomicFile + file-lock bridge.
- The last valid car snapshot remains available when Android Auto starts directly from DHU.
- Recorded rides are transferred through the same process-safe bridge.
- Existing NavigationTemplate UI and cockpit behavior are unchanged.
