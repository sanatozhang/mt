# Changelog

[中文](CHANGELOG.md) | English

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-07-29

### Added

#### Bilingual (Chinese / English) output
- Every user-visible output under `bin/` (prompts, errors, help text, install wizard) now supports bilingual output — Chinese first, English on the line below
- Added `echo_bi` / `echo_bi_err` bilingual output helpers (`bin/lib/mt_core.sh`); `bin/install-mt.sh` carries its own copy since it's a standalone distribution script
- The full `mt help` text is now bilingual; `mt init` is flagged in both the help text and the README as the first command new hires should run
- Added language-switch links to `README.md` / `CHANGELOG.md`; `README.md` now defaults to English, with the Chinese version moved to `README.zh.md`; added a full English translation `CHANGELOG.en.md`

### Unchanged (backward compatible)

- Command behavior, exit codes, and the field structure/keys of `--json` output are all unchanged — only display text such as `message`/`summary` gained an English counterpart
- Strings used internally as sentinel values for comparison (e.g. `mt status`'s "no changes", `mt pr`'s PR status codes) keep their original Chinese text unchanged; only their display is bilingual

## [2.0.1] - 2026-05-28

### Added

#### `mt sync` — one-command upstream sync
- New command `mt sync [base_branch] [--push]`: runs `git fetch origin <base>` + `git rebase origin/<base>` on every repository
- Automatically switches to `git pull --ff-only` when the current branch equals the base, avoiding a rebase onto itself
- A dirty workspace / detached HEAD is skipped automatically with a clear reason, so uncommitted changes are never disturbed
- On rebase conflicts, `git rebase --abort` runs automatically to protect the workspace; the failing repository is recorded and other repositories keep processing
- `--push` option: after a successful rebase, runs `git push --force-with-lease` to the current branch's remote
- Default base is `main`; another base can be specified (e.g. `mt sync development`)

### Fixed

#### `mt pull/fetch/push/clone` appeared to "hang" on long-running network commands
- Previously, `run_command` captured the entire output before printing it, so network commands could sit silently for 30+ seconds on slow repositories
- Added an `is_long_running_git_command` allowlist (fetch/pull/push/clone/submodule update|sync|foreach); these commands now use a dual-track approach: streamed via `tee` while also being captured to disk
- Users now see real-time progress such as `From github.com:... -> FETCH_HEAD`
- Short commands (status/branch/log/diff, etc.) still use the original `format_output` coloring path — output style is unchanged

## [2.0.0] - 2026-05-28

### Major changes

#### Simultaneous support for the Plaud-Flutter and Plaud-Native projects
mt can now be used identically across two kinds of workspaces:
- **flutter-mt**: the original Flutter + Native hybrid project (marker: `plaud-android`), 7 repositories by default
- **native-app2**: the new Plaud pure-Native project (marker: `plaud-native-android`), 5 repositories

mt automatically detects the current workspace type from `cwd` and switches its underlying implementation — command names, arguments, and artifact paths are identical to existing usage.

### New features

#### Project detection and guards
- New `PROJECT_PROFILES` registry (in `bin/mt`) declaring the directory layout for both workspace types
- New `detect_project_kind` / `require_project_kind` guard functions
- Running a build/install command outside either project now shows a friendly error listing the supported workspaces

#### native-app2 build pipeline
- `mt build [cn|global] [-d/-r/-p] [-c <channel>] [-a]`: calls `plaud-native-android/switch_flavor.sh` + `gradlew assemble*`
  - Full support for all 7 CN channels: official / huawei / xiaomi / oppo / vivo / honor / yingyongbao
- `mt build:ios [cn|global] [-d/-r]`: calls `xcodebuild build` with scheme `Plaud-CN`/`Plaud-Global`, producing a `.app`
- `mt install` / `mt install:ios`: automatically installs to a device after building (adb / xcrun devicectl / ios-deploy)
- `mt prebuild`: runs `plaud-native-android/build.sh` then `plaud-native-ios/scripts/start/build.sh`, handling translation, analytics, CocoaPods, etc.
- `mt go` / `mt rebuild` / `mt build:check` / `mt clean`: all support native-app2

#### native-app2 multi-repo Git support
- New `NATIVE_APP2_REPOSITORIES` list (5 entries): `plaud-native-android` / `plaud-native-ios` / `plaud-native-harmony` plus two nested submodules `nicebuildSDK` / `PenSubmodules`
- `mt status` / `mt branch` / `mt checkout` / `mt pull` / `mt push` / `mt list` / `mt pr` and all other multi-repo Git commands automatically use the new list under native-app2
- Global filter options `--current` / `--main-only` / `--subrepos-only` / `--only` / `--exclude` behave unchanged

### Architecture

#### Dual-track isolation design
- New `bin/lib/mt_build_app2.sh` (~800 lines) holding all `_app2_*` implementations for native-app2
- The existing `bin/lib/mt_build.sh` internal functions (`_build_android_internal` / `_build_ios_internal` / `prebuild` / `clean_cache`, etc.) are **unchanged, not a single line touched**
- Dispatch happens at the `handle_*` entry layer in `bin/lib/mt_cli.sh` — the call chain for flutter-mt projects is identical to before the change
- Repository list dispatch is centralized in `mt_core.sh:get_repositories`, routed by `detect_project_kind`

### Improvements

- `find_project_root` now recognizes the marker of any registered profile (compatible with both A and B project types when searching upward)
- Clearer error messages: an unrecognized workspace now lists the supported project names and markers

### Unchanged (backward compatible)

- All command behavior, output, artifact paths, and error messages under flutter-mt projects are identical to 1.4.2
- The 7 repository definitions in `DEFAULT_REPOSITORIES` were not modified in any way
- The install method, `mt upgrade`, `mt init`, and other toolchain utilities are unchanged

## [1.4.2] - 2026-01-26

### New features

#### PR Ready and review summary
- `mt pr -r/--ready` moves the PR from Draft to Ready for review after creation
- The review broadcast summary now includes author/changes/link, in a format better suited for direct forwarding
- A footnote is appended to the summary: this PR review was created by the mt tool
- `mt init` now checks Homebrew/FVM, installs Flutter `3.38.9`, and automatically clones the repository

### Improvements

#### Multi-repo coverage
- The default repository list is fixed at 7 repositories; missing or uninitialized repositories are skipped automatically
- Removed the runtime dependency on `.mt-config.yaml`; the default 7 repositories now run with zero configuration
- `mt status` prints "no changes" when there's nothing to show
- Added global repository filtering and execution controls: `--current`, `--main-only`, `--subrepos-only`, `--only`, `--exclude`, `--dry-run`, `--json`, `--fail-fast`
- Added `mt doctor` to check the toolchain, workspace, and repository status
- Split `bin/mt` into modules under `bin/lib/*.sh`; the entry script is now a lightweight loader, making each command domain easier to maintain
- Composite commands like `mt go`, `mt rebuild`, `mt init` now clearly report an overall failure and return a non-zero exit code if any step fails

### Fixed

#### PR description update errors
- Fixed an `response/http_code` undefined-variable error caused by a malformed here-doc when `mt pr` updates a PR description
- Fixed `mt pr` mistaking a closed/merged historical PR for the current open PR, which could make some repositories "disappear" from the summary

## [1.4.1] - 2025-01-16

### Fixed

#### Remote install environment variable fix
- **Critical fix**: fixed mt not being added to the environment variables when installed via `curl | bash`
- Remote execution now automatically skips the system-level install (which needs a password) and goes straight to the user-level install (no password needed)
- Fixed the PATH check logic in `install_user_path()`:
  - The config file is now checked and updated (if missing) regardless of whether the current PATH already contains `.local/bin`
  - Ensures the PATH configuration persists to the shell config file (`.zshrc` or `.bashrc`)
- Improved error handling for symlink creation so the install process never fails silently
- Added clearer messaging telling users they need to reload their config or reopen the terminal

## [1.4.0] - 2025-01-16

### New features

#### Colored status output
- The `mt status` command now supports colored output, matching `git status` colors exactly
- Different states use different colors:
  - Cyan/blue: branch info (`On branch ...`)
  - Green: staged changes (`Changes to be committed:`, `new file:`, `nothing to commit`)
  - Red: unstaged changes (`Changes not staged for commit:`, `modified:`, `deleted:`, `Untracked files:`)
  - Yellow: informational hints (`Your branch is ahead/behind...`, `no changes added to commit`, `renamed:`)
- Automatically recognizes file status codes (`M  file`, ` M file`, `?? file`, etc.) and applies the matching color
- The `status` command no longer shows an extra "succeeded" message — output is cleaner

### Improvements

#### Cache directory permission handling
- Fixed a permission error when the cache directory (`~/.cache/mt`) couldn't be created in some environments
- If the cache directory can't be created, the version check is silently skipped without affecting core functionality
- A failed version check no longer interrupts command execution, improving tool stability

### Fixed

#### Error handling improvements
- Fixed an error message that appeared when cache directory creation failed
- Improved error handling logic so the tool works correctly even in permission-restricted environments

#### Fixed a BASH_SOURCE unbound-variable error
- Fixed a possible "unbound variable" error when accessing `BASH_SOURCE[0]` and `BASH_SOURCE[1]` under `set -u`
- Fixed all `BASH_SOURCE` accesses in `bin/mt` and `bin/install-mt.sh` to use safe defaults (`${BASH_SOURCE[0]:-$0}` and `${BASH_SOURCE[1]:-}`)
- Ensures the script works correctly across execution contexts (direct execution, sourcing, symlinks, remote `curl` execution, etc.)
- Specifically fixed an error that occurred when running the install script via `curl | bash`

#### Fixed install script path handling
- Fixed a path error (`No such file or directory`) when the `bin` directory doesn't exist during a remote install script execution
- Improved path validation logic to auto-create the directory or provide a clear error when it's missing
- Uses a safer path computation method (`dirname` instead of `..`) to avoid path resolution errors
- Ensures the `bin` directory is correctly recognized and accessed after cloning the repository

## [1.2.0] - 2024-12-18

### New features

#### Sub-repository branch operation sync
- Branch-related operations (checkout, branch, merge, rebase, switch, cherry-pick) now also run in the Android and iOS project sub-repositories
- Android sub-repository: `plaud-android/nicebuildSDK` (auto-detected and executed)
- iOS sub-repository: `plaud-ios/PLAUD/PenSubmodules` (auto-detected and executed)
- A missing sub-repository is skipped automatically without affecting the main repository operation

#### Clone enhancements
- `mt clone` now automatically clones the Android sub-repository `ble-sdk-android` into `plaud-android/nicebuildSDK`
- The iOS sub-repository is initialized automatically via `git submodule update --init --recursive` (a Git submodule)

### Improvements

#### Push command behavior change
- `mt push` now runs push on every configured repository, no longer checking for local commits first
- Removed the pre-push change-detection logic to simplify the workflow
- If a repository has nothing to push, Git's own error message is shown instead of skipping it early

#### Execution summary fix
- Fixed incorrect summary counts when a branch operation included sub-repositories (e.g. showing 7/5)
- All executed repositories (main + sub-repositories) are now counted correctly, showing an accurate execution count

## [1.1.0] - 2024-12-17

### New features

#### Git command alias support
- Added common Git command aliases to improve efficiency
- Supported basic command aliases:
  - `co` → `checkout`
  - `br` → `branch`
  - `ci`/`cm` → `commit`
  - `st` → `status`
  - `ps`/`ph` → `push`
  - `pl` → `pull`
  - `m` → `merge`
  - `rb` → `rebase`
  - `sa` → `stash`
  - `sw` → `switch`
  - `cp` → `cherry-pick`
  - `fe`/`ft` → `fetch`
  - `di` → `diff`
  - `lo` → `log`
  - `rs` → `reset`
  - `rv` → `revert`
  - `sh` → `show`
  - `ta` → `tag`
  - `ad` → `add`
- Supported compound aliases with arguments:
  - `cob` → `checkout -b` (create and switch branch)
  - `bra` → `branch -a` (show all branches)
  - `cim` → `commit -m` (commit with a message)
  - `ciam` → `commit -am` (stage all and commit)
  - `cane` → `commit --amend --no-edit` (amend the last commit)
  - `phf` → `push -f` (force push)
  - `plro` → `pull --rebase origin` (rebase-pull from origin)
  - `rbi` → `rebase -i` (interactive rebase)
  - `rba` → `rebase --abort` (abort rebase)
  - `rbc` → `rebase --continue` (continue rebase)
  - `rth` → `reset --hard` (hard reset)
  - `rts` → `reset --soft` (soft reset)
  - `cpa` → `cherry-pick --abort` (abort cherry-pick)
  - `cpc` → `cherry-pick --continue` (continue cherry-pick)
  - `shs` → `stash save` (save a stash)
  - `sha` → `stash apply` (apply a stash)
  - `shp` → `stash pop` (pop a stash)
  - `shd` → `stash drop` (drop a stash)

#### Plaud tool integration
- Integrated the Plaud-app-scripts toolset into mt
- All tool scripts have been copied into `scripts/plaud-tools/`, keeping the tools self-contained
- Added the `mt plaud` command prefix to unify management of Plaud-related tools
- Supported tool commands:
  - `mt plaud version` - version conversion tool (versionCode ↔ version string)
  - `mt plaud log sync` - sync log analysis tool
  - `mt plaud log clean` - network log cleanup tool
  - `mt plaud log time-diff` - sync time-gap analysis tool
  - `mt plaud check opus` - Opus file format checker
  - `mt plaud copy` - batch file copy tool
  - `mt plaud decrypt` - Plaud encrypted file decryption tool

#### Project clone feature
- Added the `mt clone` command to clone the Plaud-App repository in one step
- Automatically runs `git submodule update --init --recursive` to initialize all submodules
- Supports specifying a target directory (defaults to `Plaud-App`)
- Provides clear progress messages and error handling

#### Git submodule support
- Full support for the `git submodule` command
- Can run submodule operations across all configured repositories
- Example: `mt submodule update --init --recursive`

### Improvements

#### Project root detection
- Improved the `find_project_root` function to correctly identify the project root even without a config file
- Detects the project root by recognizing the project structure (containing multiple plaud-related subdirectories)
- Fixed incorrect path resolution when running commands from a subdirectory (e.g. `plaud-flutter-cn`)

#### Help documentation update
- Updated the `mt help` output to include all new features
- Added detailed explanations and examples for Git command aliases
- Added usage instructions for the Plaud tools

#### Error message improvements
- Improved the error message for unsupported commands, now showing all supported aliases
- Improved the output shown during submodule initialization

### Technical improvements

#### Script path management
- Prefers the script directory inside the mt project (`scripts/plaud-tools/`)
- Supports specifying an external script directory via the `PLAUD_SCRIPTS_DIR` environment variable
- Backward compatible: falls back to the external directory if the internal scripts aren't found

#### Code organization
- All Plaud tool scripts are now integrated into the mt project, keeping the tools self-contained
- Added a `scripts/plaud-tools/README.md` documentation file

### Documentation

- Updated `README.md` and `doc/README.md` to describe all new features
- Updated `doc/TECHNICAL_DESIGN.md` to record technical implementation details

## [1.0.0] - Initial release

### Features

- Unified execution of Git commands across multiple repositories
- Configuration-file-based repository list management
- Support for all common Git commands
- Branch operation support (checkout, branch, switch, merge, rebase, cherry-pick)
- Status viewing and stash operations (status, stash)
- Commit and push (auto-skips repositories with no changes)
- Diff viewing (auto-skips repositories with no changes)
- Tool commands: list, init, config, delete, clean, upgrade
- Build commands: prebuild, build, install, build:check, build:ios
- PR creation (supports Draft PRs, automatically adding a Copilot reviewer, MT AUTO label)
- iOS install support (physical device detection and selection)
