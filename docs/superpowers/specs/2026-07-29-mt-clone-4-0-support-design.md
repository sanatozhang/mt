# mt clone/init 支持 Plaud-App 4.0（Native mono-repo）设计

## 背景

`mt` 目前只支持一种 clone 方式：`Plaud-App.git`（3.0，Flutter + Native 混合 mono-repo，7 个子仓库，需要额外安装配置 Flutter 引擎）。

Plaud-App 现在有了 4.0 架构：`plaud-native-app.git`，纯 Native mono-repo，对应现有代码里已经定义好的 `native-app2` workspace 类型（`bin/mt` 里的 `NATIVE_APP2_REPOSITORIES` / `PROJECT_PROFILES`），共 5 个子仓库，不需要 Flutter 环境。

4.0 是新项目的默认路径，3.0 是仍在维护的旧项目路径。目前 README 和 `mt init`/`mt clone` 代码只覆盖了 3.0，需要补上 4.0，并把 4.0 设为默认。

## 目标

1. `mt clone` / `mt init` 能够 clone 4.0（`plaud-native-app.git`），且 4.0 是默认选项。
2. 3.0 的现有能力保留（代码路径不删除），通过显式选择/参数继续可用。
3. README 默认展示 4.0 流程；3.0 的完整说明移到独立文档。

## 非目标

- 不改动 `doctor` / `build` / `prebuild` / `install` 等命令 —— 它们已经通过目录 marker（`plaud-android` vs `plaud-native-android`）自动识别工作区类型，4.0 clone 完成后天然可用。
- 不废弃或删除 3.0 的任何现有代码路径。
- 不引入新的 workspace profile —— 4.0 直接复用现有的 `native-app2` profile 和 `NATIVE_APP2_REPOSITORIES`。

## 4.0 仓库清单（确认信息）

- 主仓库（mono-repo）：`git@github.com:Plaud-AI/plaud-native-app.git`
- 默认克隆目录名：`Plaud-Native-App`
- `git submodule update --init --recursive` 之后会带出：
  - `plaud-native-android`
  - `plaud-native-ios`
  - `plaud-native-harmony`
- 以下两个仓库不是该 mono-repo 的 submodule，需要跟 3.0 一样单独 clone（地址复用 `bin/mt` 里 `NATIVE_APP2_REPOSITORIES` 已有配置）：
  - `nicebuildSDK` → `<target>/plaud-native-android/nicebuildSDK`（`git@github.com:Plaud-AI/ble-sdk-android.git`）
  - `PenSubmodules` → `<target>/plaud-native-ios/plaud/PenSubmodules`（`git@github.com:Plaud-AI/ios-lib-nicebuild-blepen.git`）

## 架构改动

### 1. 新增 `clone_native_app2()`（`bin/lib/mt_repo.sh`）

结构照抄现有 `clone_plaud_app()`：

1. 目标目录已存在 → 沿用现有的警告 + 二次确认逻辑
2. `[1/3] git clone git@github.com:Plaud-AI/plaud-native-app.git <target_dir>`
3. `[2/3] git submodule update --init --recursive`
4. `[3/3]` 依次单独 clone `nicebuildSDK`、`PenSubmodules`（复用 `NATIVE_APP2_REPOSITORIES` 里的路径与地址常量，不新增硬编码）

失败处理与提示文案风格与 `clone_plaud_app()` 保持一致（中文在前、英文在后，遵循现有 `echo_bi` 的既有顺序 —— **注意**：本次新增的“版本选择”交互提示是例外，见下方“版本选择交互”一节，按用户要求英文在前）。

### 2. 版本选择交互（新增，仅用于本次改动）

在 `mt clone` 和 `mt init` 内部新增一个共享的版本判定函数，例如 `resolve_project_version()`，判定优先级：

1. 命令行显式传入 `--v3` 或 `--v4` → 直接采用，不再询问。
2. 未传参：
   - 如果 stdin 是 TTY → 交互询问（见下方文案），直接回车走默认 4.0。
   - 如果不是 TTY（脚本/CI 场景）→ 静默按 4.0 处理，不报错、不阻塞。

交互文案（本次新增部分，英文在前、中文在后）：

```
Select which version to clone:
请选择要 clone 的版本：
  1) Native 4.0  (default / 默认)
  2) Flutter 3.0
Enter your choice [1]:
```

- 输入为空或 `1` → 4.0
- 输入 `2` → 3.0

### 3. `mt clone [目录名] [--v3|--v4]`

- 解析结果为 **4.0** → 调用 `clone_native_app2`
- 解析结果为 **3.0**：
  - 若来自显式 `--v3` 参数 → 直接执行现有 `clone_plaud_app`（不打断，视为明确意图）
  - 若来自交互选择 `2` → 先打印提示：

    ```
    Flutter 3.0 also requires setting up the Flutter environment.
    3.0 还需要额外配置 Flutter 环境。
    We recommend running `mt init --v3` instead, which sets up the environment and clones for you.
    建议直接运行 `mt init --v3`，会自动完成环境配置和代码克隆。
    ```

    再询问是否仍然只执行 clone（默认 N）。选 N/直接回车 → 中止，不 clone。选 Y → 执行 `clone_plaud_app`。

### 4. `mt init [目录名] [--v3|--v4]`

- 版本判定复用 `resolve_project_version()`
- **4.0（默认）** → 跳过 Homebrew / FVM / Flutter 安装那一整套 bootstrap 步骤，直接调用 `clone_native_app2`。即 4.0 下 `mt init` 等价于 `mt clone --v4`。
- **3.0** → 行为完全不变：Homebrew → FVM → Flutter `3.38.9` → `clone_plaud_app`（即现有 `bootstrap_environment_and_clone`）。

### 5. CLI 参数解析

`--v3` / `--v4` 作为新增的 flag，与现有第一个位置参数（自定义目录名）不冲突：
- `mt init My-Dir --v4`
- `mt init --v3`（用默认目录名）
- `mt clone --v3 My-Dir`（顺序不敏感）

沿用 `bin/mt` 里现有的参数解析风格（类似 `--current`/`--json` 等 flag 的处理方式）。

## 文档改动

- `README.md`（英文默认）/ `README.zh.md`：
  - 顶部工作区表格、安装、`mt init` 相关段落默认展示 **4.0 / native-app2** 流程（无需 Flutter 环境，`mt init` 一步到位）。
  - 原有面向 3.0 的详细步骤（Flutter 引擎安装、`mt init` 完整 bootstrap 说明）整段移出，替换为一段简短说明 + 链接到新文档，并给出 `--v3` 用法提示。
- 新增 `doc/CLONE_V3.md`（沿用 `doc/` 目录现有的"仅中文"惯例）：
  - 完整保留 3.0 的 clone / init 说明（Homebrew/FVM/Flutter 步骤、`mt init --v3` / `mt clone --v3` 用法）。
- 两份 README 的"详细文档"区块各加一条指向 `doc/CLONE_V3.md` 的链接。

## 边界情况

- 目标目录已存在：两个 clone 函数都沿用现有的"已存在，是否继续"确认逻辑。
- 子仓库目录已存在（如 `nicebuildSDK` 已经 clone 过）：跳过，打印提示（与现有 `clone_plaud_app` 行为一致）。
- 非 TTY 环境：不阻塞，静默走 4.0 默认路径。
- `--v3` 和 `--v4` 同时传入：视为参数错误，报错并提示只能二选一。

## 验证方式

- 手动在一个干净目录下运行 `mt clone --v4`，确认能 clone 出 `plaud-native-android` / `plaud-native-ios` / `plaud-native-harmony` + `nicebuildSDK` + `PenSubmodules`，且 `cd` 进去后 `mt doctor` 能正确识别为 `native-app2` 工作区。
- 手动运行 `mt clone`（不带参数，交互场景）确认默认回车能走 4.0。
- 手动运行 `mt clone --v3` 确认与现状（`clone_plaud_app`）行为一致，未被破坏。
- 手动运行 `mt init --v4` 确认跳过 Flutter/FVM/Homebrew 步骤，直接 clone。
- 手动运行 `mt init --v3` 确认与现状（`bootstrap_environment_and_clone`）行为一致。
- Review 两份 README + 新增的 `doc/CLONE_V3.md` 渲染效果。
