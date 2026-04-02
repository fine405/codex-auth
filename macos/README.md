# Codex Auth — macOS Menu Bar App

A lightweight native macOS menu bar app for managing Codex accounts. Built with Swift + SwiftUI, it reads the same `~/.codex/accounts/registry.json` used by the CLI.

## Features

- **Menu bar icon** — lives in the system menu bar, no Dock icon
- **Account overview** — email, plan badge, 5h & weekly usage bars
- **One-click switch** — click any account to switch instantly
- **Live refresh** — watches `registry.json` for changes (e.g. from CLI or auto-switch daemon)
- **Config toggles** — auto-switch and Usage API on/off directly from the panel

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ toolchain (included with Xcode 15+)
- [Optional] Zig toolchain — only needed for `make build` to embed the CLI binary

## Quick Start

```sh
# Development mode (build + run directly)
cd macos
make dev

# Build .app bundle (Swift only, no Zig binary embedded)
make bundle

# Full build (Zig CLI + Swift + .app bundle)
make build

# Run the .app
make run

# Clean build artifacts
make clean
```

## Project Structure

```
macos/
├── Package.swift                        # SPM manifest (macOS 13+)
├── Info.plist                           # LSUIElement=true (menu bar only)
├── Makefile                             # Build automation
├── Sources/CodexAuthApp/
│   ├── main.swift                       # Entry point, hides Dock icon
│   ├── AppDelegate.swift                # NSStatusBar + NSPopover setup
│   ├── Models.swift                     # Codable structs for registry.json
│   ├── AccountsViewModel.swift          # Data loading, mutations, file watching
│   └── Views.swift                      # SwiftUI interface
└── README.md
```

## Architecture

```
┌─────────────────┐
│  NSStatusBar     │  Menu bar icon (SF Symbol)
│  (AppDelegate)   │
└────────┬────────┘
         │ click
┌────────▼────────┐
│  NSPopover       │  Transient popover (auto-close on outside click)
│  (SwiftUI View)  │
└────────┬────────┘
         │ data
┌────────▼────────┐
│ AccountsViewModel│  Reads/writes registry.json directly
│                  │  Watches file changes via DispatchSource
└────────┬────────┘
         │
    ~/.codex/accounts/registry.json
```

### Data Flow

| Operation | Method | Details |
|-----------|--------|---------|
| Read accounts | Direct file read | Parses `registry.json` with `JSONDecoder` |
| Switch account | Direct file copy | Copies `accounts/<key>.auth.json` → `auth.json`, updates registry |
| Toggle config | Direct file write | Modifies `auto_switch` / `api` fields in registry |
| Live refresh | DispatchSource | Watches `registry.json` for write/rename/delete events |

No dependency on the CLI binary for core operations. The CLI is optionally embedded in the `.app` bundle for future use (e.g. triggering `reconcileManagedService` after switch).

## Build Modes

### `make dev` — Development

Runs `swift run` directly. Fast iteration, no `.app` bundle created. The app reads `~/.codex/accounts/registry.json` from the user's home directory.

### `make bundle` — Swift-only Bundle

1. `swift build -c release`
2. Creates `Codex Auth.app/` with proper bundle structure
3. Skips Zig binary embedding if not built

### `make build` — Full Build

1. `cd .. && zig build -Doptimize=ReleaseSafe` — builds the CLI
2. `swift build -c release` — builds the Swift app
3. Assembles `.app` bundle with CLI embedded at `Contents/Resources/codex-auth`

## How It Works

### Account File Resolution

Account auth snapshots are stored at `~/.codex/accounts/<file_key>.auth.json`. The file key is derived from the `account_key`:

- If the key contains only `[a-zA-Z0-9._-]` → used as-is
- Otherwise → base64url-no-pad encoded

This matches the Zig CLI's `accountFileKey()` logic exactly.

### Account Switching

When the user clicks an inactive account:

1. Copy `~/.codex/accounts/<file_key>.auth.json` → `~/.codex/auth.json`
2. Update `active_account_key` and `active_account_activated_at_ms` in `registry.json`
3. The DispatchSource detects the change and refreshes the UI

### Config Changes

Toggle switches directly modify `registry.json`:

- **Auto-switch**: sets `auto_switch.enabled`
- **Usage API**: sets `api.usage` and `api.account` together

## Known Limitations

- **No login/import/remove** — use `codex-auth` CLI for these operations
- **No LaunchAgent management** — toggling auto-switch only updates the config; the daemon service is not installed/uninstalled from the GUI
- **No app signing** — the `.app` bundle is unsigned; macOS may require allowing it in System Settings > Privacy & Security
