# MT

English | [中文](README.zh.md)

`mt` is Plaud's multi-repository development tool. **Since v2.0 it supports two kinds of workspaces** with zero configuration, out of the box:

> 🚀 **New to the project?** Once mt is installed, the first command you run is always [`mt init`](#initialize-the-dev-environment-first-step-for-newcomers) — it pulls all the code for you. By default it sets up the **Native 4.0** workspace (no Flutter needed).

| Workspace type | Detected via marker | Repos | Applies to |
|---|---|---|---|
| **native-app2** (4.0, default) | `plaud-native-android/` | 5 | Plaud-Native-App2 (pure Native project: Android / iOS / HarmonyOS) |
| **flutter-mt** (3.0, legacy) | `plaud-android/` | 7 | Plaud-App (Flutter + Native hybrid project) — see [doc/CLONE_V3.md](doc/CLONE_V3.md) *(Chinese only)* |

mt automatically detects the workspace type based on your current directory — command names and arguments are identical, so there's no need to switch tools.

## Installation

One-line install is recommended:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/main/bin/install-mt.sh)"
```

If the one-line install fails, or `curl` can't reach GitHub Raw, fall back to a manual install:

```bash
git clone https://github.com/sanatozhang/mt.git
cd mt
./bin/install-mt.sh
```

After installing, reopen your terminal, or run:

```bash
source ~/.zshrc
# or
source ~/.bashrc
```

## Initialize the dev environment (first step for newcomers)

> **This is the first command a new hire should run.** Once mt is installed, you don't need to manually clone repositories — one `mt init` does it all.

By default `mt init` sets up the **Native 4.0** workspace (`Plaud-Native-App`) — no Flutter environment required:

```bash
cd /path/to/your/workspace
mt init
```

`mt init` will ask which version to set up (default: **Native 4.0**, press Enter to accept). If no terminal is attached (e.g. run from a script), it silently defaults to 4.0 as well. You can also skip the prompt with an explicit flag:

```bash
mt init --v4   # Native 4.0 (default) — same as mt clone --v4, no Flutter setup
mt init --v3   # Flutter 3.0 (legacy) — installs Homebrew/FVM/Flutter, then clones Plaud-App
```

To use a custom directory name:

```bash
mt init My-Plaud-Native-App
```

After initialization, it's a good idea to check your environment once:

```bash
cd Plaud-Native-App
mt doctor
```

If you passed a custom directory name, `cd` into that directory instead.

Still on the Flutter + Native hybrid project (3.0)? See [doc/CLONE_V3.md](doc/CLONE_V3.md) *(Chinese only)* for the full `--v3` setup flow.

## Recommended for beginners

After entering the project for the first time, we recommend running:

```bash
cd Plaud-Native-App
mt go
```

`mt go` is the most common entry point for newcomers — by default it runs `prebuild + install` for Android `global debug`.

## Common commands

- `mt init`
  Set up the project and pull the code. Native 4.0 by default (no Flutter); `--v3` also configures the Flutter engine for the legacy hybrid project.
- `mt clone`
  Only clone the repositories (skip the environment bootstrap). Same `--v3`/`--v4` selection as `mt init`.
- `mt go`
  Recommended for beginners. Runs `prebuild + install` for Android `global debug` by default.
- `mt install`
  Build the Android package and install it on a device.
- `mt install:ios`
  Build the iOS package and install it on a device.
- `mt prebuild`
  - **flutter-mt**: calls the workspace's `build_all.sh`, which includes `flutter pub get`, i18n scripts, etc.
  - **native-app2**: runs `plaud-native-android/build.sh` (translation/analytics) then `plaud-native-ios/scripts/start/build.sh` (pod install)
- `mt build`
  Build only, don't install.
- `mt pr`
  Create PRs across repositories.
- `mt upgrade`
  Upgrade the mt tool.

Common global options include `--current`, `--json`, `--dry-run`, `--fail-fast`. See the detailed documentation for the full option reference.

## Using it in the Plaud-Native-App2 project

This is the default workspace `mt init` sets up (see above). Once inside the workspace, the commands are identical to Plaud-App:

```bash
cd /path/to/plaud-native-app2

mt status                        # status of 5 repositories
mt build global -d               # build the Android Global Debug APK
mt build cn -r -c huawei         # build the Android CN Huawei Release APK
mt build:ios global -d           # build the iOS Plaud-Global.app
mt install global -d             # build + adb install
mt prebuild                      # run the native-android / native-ios setup scripts
mt go global -d                  # prebuild + install in one go
mt clean -a                      # clear the Android cache only
```

Repository list (switches automatically by workspace, no configuration needed):
- `plaud-native-android` / `plaud-native-ios` / `plaud-native-harmony`
- Nested submodules: `nicebuildSDK`, `PenSubmodules`

> When a build command is run outside either supported workspace, mt shows a friendly message listing the supported workspaces.

## Detailed documentation

- [Usage guide](doc/README.md) *(Chinese only)*
- [Technical design](doc/TECHNICAL_DESIGN.md) *(Chinese only)*
- [Flutter 3.0 (legacy) setup guide](doc/CLONE_V3.md) *(Chinese only)*
