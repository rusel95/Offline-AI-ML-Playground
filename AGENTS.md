# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `Offline AI&ML Playground/` with feature folders: `App/`, `ChatTab/`, `DownloadTab/`, `SettingsTab/`, and shared logic in `Shared/` (Core/Downloads, Core/Inference, Core/Storage, Services, Protocols).
- Tests mirror the app: `Offline AI&ML PlaygroundTests/` (unit/integration) and `Offline AI&ML PlaygroundUITests/`.
- Xcode project: `Offline AI&ML Playground.xcodeproj`. Assets: `Assets.xcassets/`. Docs: `memory-bank/`, `.kiro/`.

## Build, Test, and Development Commands
- Open in Xcode: `open "Offline AI&ML Playground.xcodeproj"`
- Build (CLI): `xcodebuild -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination "generic/platform=iOS" build`
- Analyze (matches CI): `xcodebuild clean build analyze`
- Test (XCTest): `xcodebuild test -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination "platform=iOS,name=<DeviceName>"`
  - Note: MLX Swift requires a physical iOS device; MLX-related tests must run on device.
- Lint: `bash Scripts/swiftlint.sh` (requires SwiftLint; see `.swiftlint.yml`).

## Coding Style & Naming Conventions
- Language: Swift 5.9+. Indentation: 4 spaces. Soft wrap at ~120 chars.
- SwiftLint enforced (no force unwrap/try, prefer `@MainActor` over `DispatchQueue.main.async`, magic numbers discouraged).
- Naming: `...View`, `...ViewModel`, `...Service`/`...Manager`, `...Protocol`, descriptive model names (`AIModel`, `ModelPaths`).
- Follow SOLID/DRY; keep feature code in its tab module, shared utilities in `Shared/`.

## Testing Guidelines
- Framework: XCTest. Place files as `*Tests.swift` alongside mirrored modules.
- Prefer unit tests for `Shared/Core` and ViewModels; mock MLX where possible. Run device tests for MLX-dependent paths.
- Enable code coverage in the scheme for local reports.

## Commit & Pull Request Guidelines
- Commit style: short, imperative with bracket tag, e.g., `[add] model downloader`, `[fix] memory context`, `[refactor] token flow`.
- PRs must: include a clear description, link issues, screenshots for UI changes, and device/OS info for MLX changes. Ensure SwiftLint passes and CI build/analyze is green.

## Security & Configuration Tips
- Do not commit model binaries or DerivedData. Large assets should use Git LFS (configured for images).
- Avoid secrets in source or `Info.plist`. Keep user-specific paths out of code; use `ModelPaths` utilities.
