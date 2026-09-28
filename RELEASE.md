# GoVia Mobile v0.1.56+57

## GitHub Actions packaging fix

- Restores `.github/workflows/android-release.yml` to release packages.
- Fixes release packaging so hidden project directories such as `.github` are included.
- GitHub Actions again builds debug APK artifacts on `main` and signed release APK assets on `v*` tags.
- No runtime/UI behavior changed from v0.1.55.
