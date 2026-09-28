# GoVia Mobile v0.1.58+59

## Android Auto forward follow camera

- Active navigation now defaults to a forward-looking follow/chase camera instead of a near top-down view.
- Camera bearing follows the vehicle heading with smoothing to reduce visual jitter.
- Camera target is placed ahead of the vehicle so the marker sits lower and more road is visible in front.
- Navigation pitch is increased to 50 degrees for a stronger behind-the-vehicle perspective.
- Zoom adapts moderately to speed: closer at low speed, slightly wider at higher speed.
- Recenter returns directly to the follow/chase view.
- Recording keeps its existing map framing; this change is scoped to active navigation.
- GitHub Actions workflow remains included in release packages and continues to build APK artifacts.
