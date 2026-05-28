# MT

`mt` 是 Plaud 的多仓库开发工具，**自 v2.0 起同时支持两类工作区**，零配置开箱即用：

| 工作区类型 | 识别 marker | 仓库数 | 适用项目 |
|---|---|---|---|
| **flutter-mt** | `plaud-android/` | 7 个 | Plaud-App（Flutter + Native 混合工程） |
| **native-app2** | `plaud-native-android/` | 5 个 | Plaud-Native-App2（纯 Native 工程：Android / iOS / 鸿蒙） |

mt 会根据当前所在目录自动识别工作区类型，命令名与参数完全一致，无需切换工具。

## 安装

推荐直接一键安装：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanatozhang/mt/main/bin/install-mt.sh)"
```

如果一键安装失败，或者 `curl` 无法访问 GitHub Raw，就直接回退到手动安装：

```bash
git clone https://github.com/sanatozhang/mt.git
cd mt
./bin/install-mt.sh
```

安装完成后，重新打开终端，或者执行：

```bash
source ~/.zshrc
# 或
source ~/.bashrc
```

## 初始化开发环境

首次拉起工作区时执行：

```bash
cd /path/to/your/workspace
mt init
```

如果要指定目录名：

```bash
mt init My-Plaud-App
```

`mt init` 用来创建项目环境。它会依次完成：
- 检测 Homebrew
- 检测并安装 FVM
- 安装并配置 Flutter `3.38.9`
- 写入 shell 环境，并创建 `fvm` / `flutter` / `dart` 命令入口
- 执行 `mt clone` 拉取 Plaud-App 代码

初始化完成后建议先检查一次环境：

```bash
cd Plaud-App
mt doctor
```

如果你传了自定义目录名，进入对应目录即可。

## 新手推荐

第一次进入项目后，推荐直接执行：

```bash
cd Plaud-App
mt go
```

`mt go` 是新手最常用的入口，默认会执行 Android `global debug` 的 `prebuild + install`。

## 常用命令

- `mt init`
  创建项目环境，拉取代码，配置 Flutter 引擎。
- `mt go`
  新手推荐命令。默认执行 Android `global debug` 的 `prebuild + install`。
- `mt install`
  执行 Android 打包并安装到设备。
- `mt install:ios`
  执行 iOS 打包并安装到设备。
- `mt prebuild`
  - **flutter-mt**：调用工作区 `build_all.sh`，包括 `flutter pub get`、多语言脚本等
  - **native-app2**：依次跑 `plaud-native-android/build.sh`（翻译/埋点）与 `plaud-native-ios/scripts/start/build.sh`（pod install）
- `mt build`
  只构建，不安装。
- `mt pr`
  为多仓库创建 PR。
- `mt upgrade`
  更新 mt 工具。

常用全局选项有 `--current`、`--json`、`--dry-run`、`--fail-fast`。完整参数说明见详细文档。

## 在 Plaud-Native-App2 项目下使用

进入工作区后，命令与 Plaud-App 完全一致：

```bash
cd /path/to/plaud-native-app2

mt status                        # 5 个仓库的状态
mt build global -d               # 构建 Android Global Debug APK
mt build cn -r -c huawei         # 构建 Android CN Huawei Release APK
mt build:ios global -d           # 构建 iOS Plaud-Global.app
mt install global -d             # 构建 + adb install
mt prebuild                      # 跑 native-android / native-ios 的 setup 脚本
mt go global -d                  # prebuild + install 一条龙
mt clean -a                      # 只清 Android 缓存
```

仓库列表（自动按工作区切换，无需配置）：
- `plaud-native-android` / `plaud-native-ios` / `plaud-native-harmony`
- 嵌套子模块：`nicebuildSDK`、`PenSubmodules`

> 不在两类工作区目录下执行打包命令时，mt 会给出友好提示并列出已支持的工作区。

## 详细文档

- [使用文档](doc/README.md)
- [技术方案](doc/TECHNICAL_DESIGN.md)
