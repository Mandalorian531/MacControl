# AGENTS.md

## Cursor Cloud specific instructions

**This is a native macOS-only application. It cannot be built, run, tested, or linted on the Linux Cloud Agent VM.**

MacControl is an Apple Silicon macOS utility. The whole codebase depends on Apple-only
frameworks and macOS-only build tooling that do not exist on Linux:

- `Package.swift` declares a single platform: `.macOS(.v14)`.
- Every target imports Apple-only frameworks — `AppKit`, `SwiftUI`, `IOKit`,
  `WidgetKit`, `ServiceManagement`, and `Security`. None of these ship with the
  open-source Swift toolchain on Linux.
- `scripts/build.sh` requires `xcrun --sdk macosx` and `codesign`;
  `scripts/package-dmg.sh` requires `ditto` and `hdiutil`. These are macOS-only and
  are not present on the Linux VM.
- CI builds on Apple's runner: `.github/workflows/release.yml` uses `runs-on: macos-15`.
- There are no automated tests (no XCTest / swift-testing targets) and no lint config
  (no SwiftLint / SwiftFormat).

Verified during environment setup: installing the open-source Swift 6.0.3 toolchain on
this Linux VM lets `swift --version` run, but `swift build` still fails immediately with
`error: no such module 'Security'` (and the same for the other Apple frameworks). So a
Swift toolchain does **not** unblock development here.

Do not add a Swift toolchain install to the Cloud Agent update script — it provides no
development capability for this repo and only adds startup cost.

### How to actually build / run (requires real macOS hardware)

Build and run on an Apple Silicon Mac (macOS 14+) with Apple Command Line Tools / Xcode,
per `README.md` (section "Compilation"):

```bash
./scripts/build.sh          # or: make build
./scripts/package-dmg.sh    # or: make dmg
open dist/MacControl.app    # or: make run
```

For Cloud Agent work, scope tasks to changes that do not require building or running the
app: source edits, docs (e.g. `README.md`), CI config, resources, and static review.
