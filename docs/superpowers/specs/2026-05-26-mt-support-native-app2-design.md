# mt 支持 plaud-native-app2 打包 — 设计文档

**日期**: 2026-05-26
**状态**: Draft，等用户 review
**作者**: Claude (with sanato)

## 1. 背景与目标

### 1.1 现状

mt 当前只支持 `/Users/sanato/Desktop/code/flutter/`（以下简称 **A 项目**）打包：
- Android: `plaud-android/` 下 `switch_flavor.sh` + `gradlew assemble{Cn|Global}{Channel?}{BuildType}`
- iOS: `plaud-ios/PLAUD/PLAUD.xcworkspace` + scheme `PLAUD` / `PLAUD-CN`，`xcodebuild build` 出 `.app`
- prebuild: `build_all.sh` 编 Flutter 模块（cn/global/common）

### 1.2 新增需求

支持 `/Users/sanato/Desktop/code/plaud-native-app2/`（以下简称 **B 项目**），目录结构：
```
plaud-native-app2/
├── plaud-native-android/   # 纯 native Android（cn/global + 7 渠道）
├── plaud-native-ios/       # 纯 native iOS（schemes: Plaud-CN / Plaud-Global）
├── plaud-native-harmony/   # 鸿蒙（本次不集成，预留扩展位）
└── build_all.sh            # 项目自带的 sync + setup 入口
```

mt 在 B 目录下行为与 A 对称：`mt build cn -r` 出 APK、`mt build:ios global -d` 出 `.app`、`mt install` / `mt go` 等命令语义不变。

### 1.3 硬约束

- **A 项目零回归**：现有 mt 命令在 A 项目里行为、产物路径、参数、报错信息一字不改。
- **代码隔离**：B 项目的逻辑全部新增到独立文件，不修改现有 `_build_android_internal` / `_install_android_internal` / `_build_ios_internal` / `_install_ios_internal` / `prebuild` 等函数的内部实现。
- **不在工作目录时报错**：用户在 A/B 之外的目录跑 mt 打包命令，给出清晰提示。

### 1.4 范围外（明确不做）

- 鸿蒙打包（用户暂时放弃，但保留 `PROJECT_PROFILES` 数据结构里的鸿蒙字段以便后续扩展）。
- iOS 在 B 里出 IPA（保持和 A 对称只出 `.app`；要 IPA 走 `plaud-native-ios/scripts/jenkins/build_and_upload.sh`）。
- `mt pr` / `mt list` / `mt doctor` / git 系列命令在 B 里的行为（这些跟仓库枚举有关，B 项目仓库列表不同，本次不动；如有冲突在实施期再说）。

## 2. 实证依据

### 2.1 B Android 打包闭环（已实测 ✅）

```
cd plaud-native-android
bash switch_flavor.sh global
./gradlew :app:assembleGlobalDebug
→ BUILD SUCCESSFUL in 1m 53s
→ app/build/outputs/apk/global/debug/PLAUD_v4.0.0_800_20260526-global-debug.apk (147MB)
```

Flavor 机制和 A **完全对称**：
- region: `cn` / `global`
- channel（仅 cn 维度）: `official` / `huawei` / `xiaomi` / `oppo` / `vivo` / `honor` / `yingyongbao`
- Gradle task 命名: `assembleCn{Channel}{Release|Debug}` / `assembleGlobal{Release|Debug}`
- APK 产物路径: `app/build/outputs/apk/{flavor}/{type}/*.apk`

### 2.2 B iOS 打包闭环（已实测 ✅）

```
xcodebuild build \
  -workspace plaud-native-ios/plaud/plaud.xcworkspace \
  -scheme Plaud-Global \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO
→ Plaud-Global.app (81MB) 产出
```

- 真实 scheme 名: `Plaud-Global`（global）/ `Plaud-CN`（cn）— **首字母大写、其余小写**
- Workspace 路径: `plaud-native-ios/plaud/plaud.xcworkspace`
- Bundle ID: `ai.plaud.ios.plaud` (global) / `ai.plaud.ios.plaudzh` (cn)

> 注：实测时 R.swift Run Script Phase 失败，但 `.app` 主体产物已生成；此为项目内部环境问题，与 mt 集成无关，A 项目走同样 `xcodebuild build` 路径也会遇到同类 phase 错误，行为一致。

### 2.3 B Setup 脚本（替代 A 的 prebuild）

B 项目自带：
- `plaud-native-android/build.sh` — 跑翻译/埋点生成 + git hooks setup
- `plaud-native-ios/scripts/start/build.sh {cn|global}` — pod install + 翻译 + 打开 workspace（mt 调用时需禁止 `open` 行为，见 §4.5）
- `plaud-native-harmony/build.sh` — 鸿蒙 setup（本次不调用）

## 3. 顶层架构

### 3.1 双轨隔离模型

```
                 mt CLI 入口
                      |
              parse_global_options
                      |
           ┌──────────┴──────────┐
           |   project_kind?     |   (新增的薄识别层)
           └──────────┬──────────┘
                      |
       ┌──────────────┼──────────────┐
       v              v              v
   flutter-mt      native-app2     unknown
   (A 项目)        (B 项目)         |
       |              |             v
       v              v          错误退出
  原 mt_build.sh   新 mt_build_app2.sh
  (一行不改)       (全新文件)
```

### 3.2 隔离粒度

| 文件 | 类型 | 变更 |
|---|---|---|
| `bin/lib/mt_core.sh` | 现有 | **改**：新增 `PROJECT_PROFILES` 数据结构 + `detect_project_kind()` 函数 + `find_project_root()` 增加 native-app2 marker 识别（向后兼容，A 路径不变） |
| `bin/lib/mt_build.sh` | 现有 | **不动内部实现**：`_build_android_internal` / `_install_android_internal` / `_build_ios_internal` / `_install_ios_internal` / `prebuild` / `clean_cache` 内部一行不改 |
| `bin/lib/mt_build_app2.sh` | **新文件** | B 项目对应的所有打包/安装/setup/clean 实现，命名空间 `_app2_*` |
| `bin/lib/mt_cli.sh` | 现有 | **改**：每个相关 `handle_*_command` 顶部加 1 行 `dispatch_by_project_kind` 分发；A 路径走原 handler，B 路径走新 handler |
| `bin/mt` (启动入口，假设存在) | 现有 | 多加载 `mt_build_app2.sh` 一行 |

**核心隔离手段**：分发发生在 **handle_* 层**（CLI 路由层），而不是 `*_internal` 内部。这样：
- A 用户跑 `mt build cn -r` → `handle_build_command` → 检测 PROJECT_KIND=flutter-mt → 调原 `build_android`（**与改造前调用栈完全一致**）
- B 用户跑 `mt build cn -r` → `handle_build_command` → 检测 PROJECT_KIND=native-app2 → 调新 `_app2_build_android`

A 项目代码路径**没有任何新的条件分支或函数调用层级**。

### 3.3 不在工作目录的处理

`detect_project_kind` 返回值：
- `flutter-mt` / `native-app2` → 正常分发
- `unknown` → 打包类命令报错退出：
  ```
  错误: 当前目录不在已知工作区
  当前目录: /Users/xxx/somewhere
  已支持的工作区:
    - flutter-mt (marker: plaud-android)
    - native-app2 (marker: plaud-native-android)
  请 cd 到对应项目根目录后重试
  ```
- 非打包命令（`mt --version`、`mt help` 等）不受 project kind 限制

## 4. 详细设计

### 4.1 项目识别（`mt_core.sh`）

```bash
# Profile 数据结构: name|marker|android_dir|ios_dir|ios_workspace_rel|ios_scheme_cn|ios_scheme_global|harmony_dir|flutter_dirs
# - marker: 用于识别 PROJECT_ROOT 的标志目录（PROJECT_ROOT 下存在此目录即匹配）
# - 字段为空表示该平台/能力不支持
PROJECT_PROFILES=(
    "flutter-mt|plaud-android|plaud-android|plaud-ios|plaud-ios/PLAUD/PLAUD.xcworkspace|PLAUD-CN|PLAUD||plaud-flutter-cn,plaud-flutter-global,plaud-flutter-common"
    "native-app2|plaud-native-android|plaud-native-android|plaud-native-ios|plaud-native-ios/plaud/plaud.xcworkspace|Plaud-CN|Plaud-Global|plaud-native-harmony|"
)

# 找到 PROJECT_ROOT 时同时记录 PROJECT_KIND
# 沿用 find_project_root 的"向上找 marker"思路，但 marker 来自所有 profile 的并集
detect_project_kind() {
    # 输出 profile name，找不到输出 "unknown"
}

get_profile_field() {
    local kind="$1" field_index="$2"  # 1-based per profile pipe-split
    # 返回对应字段
}
```

`find_project_root()` 改造点：把 `workspace_contains_main_repositories` 的 marker 列表从硬编码 `DEFAULT_REPOSITORIES` 扩展为"所有 profile 的 marker 字段集合"。**A 项目识别行为保持不变**（plaud-android marker 仍然命中 flutter-mt profile）。

### 4.2 CLI 分发层（`mt_cli.sh`）

```bash
# 仅在打包/安装/clean/prebuild/go/rebuild 类命令前调用
require_project_kind() {
    local kind
    kind=$(detect_project_kind)
    if [[ "$kind" == "unknown" ]]; then
        echo -e "${BOLD_RED}错误: 当前目录不在已知工作区${NC}"
        # ... 完整提示 ...
        exit 1
    fi
    echo "$kind"
}

handle_build_command() {
    local kind; kind=$(require_project_kind) || exit $?
    if [[ "$kind" == "native-app2" ]]; then
        # 走新分支
        if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
            _app2_build_android "global" "$@"
        else
            _app2_build_android "$@"
        fi
        return $?
    fi
    # A 项目分支：原代码原样保留
    if [[ -z "${1:-}" ]] || [[ "${1}" =~ ^- ]]; then
        build_android "global" "$@"
    else
        build_android "$@"
    fi
}
# 同样模式应用于: handle_install_command / handle_install_ios_command / handle_build_ios_command
#                handle_go_command / handle_rebuild_command / handle_prebuild_command
#                handle_clean_command / handle_build_check_command
```

### 4.3 B 项目实现层（`mt_build_app2.sh` — 全新文件）

文件结构：

```bash
# === Android ===
_app2_build_android_internal()    # 拷贝自 _build_android_internal，仅改路径常量
_app2_build_android()             # 公开接口
_app2_install_android_internal()  # 同上
_app2_install_android()           # 公开接口

# === iOS ===
_app2_build_ios_internal()        # 改 workspace 路径 + scheme 名（Plaud-Global / Plaud-CN）
_app2_build_ios()
_app2_install_ios_internal()
_app2_install_ios()

# === prebuild ===
_app2_prebuild()
    # 1. bash plaud-native-android/build.sh
    # 2. bash plaud-native-ios/scripts/start/build.sh {market}  (默认 global)
    #    需 export DO_OPEN=false 或用 sed 跳过 `open ...xcworkspace` 行，避免 CI/CLI 弹 Xcode

# === go / clean ===
_app2_go_android()
_app2_clean_cache()
_app2_build_check()
```

**为什么不抽公共代码**：
- 现有 `_build_android_internal` 200 行代码里硬编码了 `${PROJECT_ROOT}/plaud-android`，要抽公共得改它的内部，违反"代码隔离"硬约束
- 拷贝 + 改路径常量是**最低耦合**做法；两个 internal 函数功能相同但服务不同 profile，本就该独立演进（B 项目未来可能加渠道、改产物路径，不应牵动 A）
- 代价：~400 行新代码，但是**纯增量、纯隔离**

### 4.4 B 项目 Android 实现要点

- 路径常量：`local android_dir="${PROJECT_ROOT}/plaud-native-android"`
- switch_flavor.sh / gradle task / APK 产物路径 / 渠道列表 **全部和 A 一致**，函数体除路径外几乎逐字一致
- 签名配置：B 项目 `app/build.gradle.kts` 引用 `SignatureConfig`（在 buildSrc 里），release 构建会用到 — mt 不需要管这个，gradle 自己处理

### 4.5 B 项目 iOS 实现要点

- Workspace: `${PROJECT_ROOT}/plaud-native-ios/plaud/plaud.xcworkspace`
- Scheme 映射:
  ```
  cn      → Plaud-CN
  global  → Plaud-Global
  ```
- 配置 (`-configuration`): `Debug` / `Release` 和 A 一致
- 产物路径: `${derived_data_path}/Build/Products/${configuration}-iphoneos/*.app`
- DerivedData 默认走 mt 控制的本地目录 `${ios_dir}/plaud/build`，和 A 行为一致

### 4.6 B 项目 prebuild 实现

```bash
_app2_prebuild() {
    local market="${1:-global}"

    # 1. Android setup（翻译/埋点/git hooks）
    bash "${PROJECT_ROOT}/plaud-native-android/build.sh"

    # 2. iOS setup（pod install + 翻译）
    #    原脚本最后会 `open` 打开 workspace，CLI 环境下要绕过
    local ios_build="${PROJECT_ROOT}/plaud-native-ios/scripts/start/build.sh"
    # 用子 shell + 重定向 stdin，并通过环境变量提示项目自己跳过 open（如果项目支持）
    # 兜底方案：直接调，open 命令在 headless 环境失败也不影响 setup 主流程
    bash "$ios_build" "$market" || true
}
```

**待确认点**：`scripts/start/build.sh` 末尾 `open "$ROOT_DIR/plaud/plaud.xcworkspace"` 是否需要 mt 显式跳过？看用户日常使用是 CLI 还是 IDE 集成，default behavior 是允许它弹 Xcode（与"开发者 setup"语义对齐）。

### 4.7 B 项目 clean 实现

```
plaud-native-android/.gradle, app/build, build
plaud-native-ios/plaud/build, plaud/Pods, plaud/DerivedData
（鸿蒙缓存不清，本次范围外）
```

不清 Flutter 缓存（B 项目无 Flutter）。

## 5. 测试计划

### 5.1 A 项目回归测试（必须，零容忍）

在 A 项目目录下依次跑：
- `mt build global -d` — 应和改造前**完全一致**的 console 输出 + 产物
- `mt build:ios global -d`
- `mt install global -d`
- `mt prebuild`
- `mt clean`
- `mt clean -a` / `-i` / `-f`
- `mt build cn -r -c huawei`

验证手段：改造前后跑同一命令，diff stdout（允许差异：时间戳、APK 内 hash）。

### 5.2 B 项目功能测试

- `cd plaud-native-app2 && mt build global -d` → 出 global debug APK
- `mt build:ios global -d` → 出 `Plaud-Global.app`
- `mt build cn -r -c huawei` → 出 cn huawei release APK（需用户机器有签名）
- `mt prebuild` → 翻译/埋点/pod install 正确触发
- `mt clean` → B 项目缓存目录被清理
- `mt go global -d` → prebuild 等价物 + install 闭环

### 5.3 边界测试

- `cd /tmp && mt build cn -r` → 报"不在已知工作区"错误，列出两个 profile
- `cd plaud-native-app2/plaud-native-android && mt build global -d` → 应正确识别 native-app2（PROJECT_ROOT 上溯）
- `cd plaud-native-app2 && mt --version` / `mt help` → 不受 project kind 限制，正常输出

## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `find_project_root` 改造引入 A 项目识别偏差 | A 回归 | 实施时保持 marker 顺序：flutter-mt 的 marker 先匹配；新增测试用例：cd A 项目 → PROJECT_KIND=flutter-mt |
| B 项目 iOS R.swift 等 Run Script Phase 失败 | 用户跑 mt build:ios 报 BUILD FAILED | 这是项目内部问题不归 mt 管，但要在 doc 提示用户确保 R.swift / SwiftLint 工具链就绪；可选：mt 在 BUILD FAILED 时检查 .app 是否真生成，给出 hint |
| B 项目 release 签名缺失 | release 构建报错 | 不在 mt 范围，给清晰错误透传 |
| 鸿蒙未来要接入 | 现有结构需扩展 | PROJECT_PROFILES 已预留 `harmony_dir` 字段；后续仅需新增 `_app2_build_harmony`（或独立的 `mt_build_harmony.sh`），不影响本次架构 |

## 7. 实施颗粒度

单 PR 闭环，按以下顺序实施：

```
[1] mt_core.sh
    - 新增 PROJECT_PROFILES 常量
    - 新增 detect_project_kind / get_profile_field
    - find_project_root 扩展为遍历所有 profile marker
    - 单元验证: cd A → detect=flutter-mt; cd B → detect=native-app2; cd /tmp → detect=unknown

[2] mt_build_app2.sh (新文件)
    - 实现 _app2_build_android* / _app2_install_android*
    - 实现 _app2_build_ios* / _app2_install_ios*
    - 实现 _app2_prebuild / _app2_go_android / _app2_clean_cache
    - 装配测试: 直接调函数验证

[3] bin/mt 入口
    - source mt_build_app2.sh

[4] mt_cli.sh
    - 新增 require_project_kind
    - 改造 handle_build_command / handle_install_command / handle_install_ios_command /
          handle_build_ios_command / handle_go_command / handle_rebuild_command /
          handle_prebuild_command / handle_clean_command / handle_build_check_command
    - 模式: kind=$(require_project_kind); if [[ kind == native-app2 ]] dispatch new; else 原代码

[5] 测试
    - A 回归: 在 flutter 目录跑 build/install/prebuild/clean，比对改造前后行为
    - B 功能: 在 plaud-native-app2 目录跑同样命令，验证产物
    - 边界: /tmp 下跑 build 应报错

[6] doc/README
    - 增加"支持的工作区"章节，列两个 profile
    - 提示 B 项目首次使用前需 git submodule update --init --recursive
```

## 8. 待用户确认

- prebuild 在 B 里允许 iOS setup 脚本末尾 `open ...xcworkspace`（弹 Xcode），还是 mt 显式禁用？默认允许。
- B 项目首次集成是否需要 mt 自动跑 `git submodule update --init --recursive`？默认不做（用户手动）。
