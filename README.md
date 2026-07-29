# MT

English | [中文](README.zh.md)

`mt` is Plaud's multi-repository development tool. **Since v2.0 it supports two kinds of workspaces** with zero configuration, out of the box:

> 🚀 **New to the project?** Once mt is installed, the first command you run is always [`mt init`](#initialize-the-dev-environment-first-step-for-newcomers) — it sets up the Flutter engine and pulls all the code for you.

| Workspace type | Detected via marker | Repos | Applies to |
|---|---|---|---|
| **flutter-mt** | `plaud-android/` | 7 | Plaud-App (Flutter + Native hybrid project) |
| **native-app2** | `plaud-native-android/` | 5 | Plaud-Native-App2 (pure Native project: Android / iOS / HarmonyOS) |

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

> **This is the first command a new hire should run.** Once mt is installed, you don't need to install Flutter by hand or manually clone repositories — one `mt init` does it all.

Run this the first time you set up a workspace:

```bash
cd /path/to/your/workspace
mt init
```

To use a custom directory name:

```bash
mt init My-Plaud-App
```

`mt init` sets up the project environment. It runs through, in order:
- Detecting Homebrew
- Detecting and installing FVM
- Installing and configuring Flutter `3.38.9`
- Writing to your shell environment and creating `fvm` / `flutter` / `dart` command entries
- Running `mt clone` to pull the Plaud-App code

After initialization, it's a good idea to check your environment once:

```bash
cd Plaud-App
mt doctor
```

If you passed a custom directory name, `cd` into that directory instead.

## Recommended for beginners

After entering the project for the first time, we recommend running:

```bash
cd Plaud-App
mt go
```

`mt go` is the most common entry point for newcomers — by default it runs `prebuild + install` for Android `global debug`.

## Common commands

- `mt init`
  Set up the project environment, pull the code, and configure the Flutter engine.
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

Once inside the workspace, the commands are identical to Plaud-App:

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
