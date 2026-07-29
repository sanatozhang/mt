# Flutter 3.0（历史项目）搭建指南

`mt` 从某个版本开始默认走 **Native 4.0**（`plaud-native-app.git`，纯 Native，不需要 Flutter）。如果你负责的还是 Flutter + Native 混合的老项目（`Plaud-App.git`，即 3.0），本文档说明如何用 `mt` 搭建 3.0 环境。

## 一步到位：`mt init --v3`

```bash
cd /path/to/your/workspace
mt init --v3
```

`mt init --v3` 会依次完成：
1. 检测 Homebrew（未安装会提示手动安装 [brew.sh](https://brew.sh) 后重试）
2. 检测并安装 FVM
3. 安装并配置 Flutter `3.38.9`
4. 写入 shell 环境，创建 `fvm` / `flutter` / `dart` 命令入口
5. clone 主仓库 `Plaud-App.git`，初始化子模块，并单独 clone `nicebuildSDK`（Android 端蓝牙 SDK）

初始化完成后建议 `source` 一下 shell 配置，并检查环境：

```bash
source ~/.zshrc   # 或 ~/.bashrc
cd Plaud-App
mt doctor
```

如果要指定目录名：

```bash
mt init --v3 My-Plaud-App
```

## 只想 clone 代码，不装 Flutter 环境：`mt clone --v3`

如果你的机器已经装好 Flutter/FVM（比如换了台电脑重新拉代码），可以只做 clone：

```bash
mt clone --v3
```

`mt clone --v3` 只做 clone 这一步（clone 主仓 + `git submodule update --init --recursive` + 单独 clone `nicebuildSDK`），不会检查/安装 Homebrew、FVM、Flutter。

## 不带 `--v3`/`--v4` 直接执行会怎样？

`mt init` / `mt clone` 不带版本参数时，会交互询问：

```
Select which version to clone:
请选择要 clone 的版本：
  1) Native 4.0  (default / 默认)
  2) Flutter 3.0
Enter your choice [1]:
```

直接回车（或输入 `1`）会走 4.0；输入 `2` 选择 3.0 时：
- 通过 `mt init` 进入：正常按 3.0 完整流程执行。
- 通过 `mt clone` 进入：会先提示"3.0 还需要额外配置 Flutter 环境，建议直接运行 `mt init --v3`"，需要你确认（输入 `y`）才会继续只 clone；不确认则中止，不会 clone。

没有连接终端的场景（比如脚本里跑）不会弹交互，直接静默按 4.0 处理——如果你的脚本需要走 3.0，请显式传 `--v3`。

## 工作区结构（3.0 / flutter-mt）

| 名称 | 路径 | 说明 |
|---|---|---|
| Plaud-App | `.` | 主仓库（super-repo），包含以下子模块 |
| plaud-flutter-cn | `plaud-flutter-cn/` | Flutter CN 业务代码 |
| plaud-flutter-global | `plaud-flutter-global/` | Flutter Global 业务代码 |
| plaud-flutter-common | `plaud-flutter-common/` | Flutter 公共代码 |
| plaud-android | `plaud-android/` | Android 原生工程（workspace marker） |
| plaud-ios | `plaud-ios/` | iOS 原生工程 |
| nicebuildSDK | `plaud-android/nicebuildSDK` | Android 蓝牙 SDK，单独 clone（不是 super-repo 的 submodule） |
| PenSubmodules | `plaud-ios/PLAUD/PenSubmodules` | iOS 录音笔子模块 |

进入 `Plaud-App` 目录后，`mt` 会自动识别为 `flutter-mt` workspace，其余命令（`mt build`、`mt install`、`mt prebuild`、`mt pr` 等）与 [README](../README.zh.md) 中描述的用法完全一致。

## 常见问题

- **Homebrew/FVM 已经装过了，`mt init --v3` 还要重新装吗？** 不会，`mt init` 会先检测，已安装则直接跳过对应步骤。
- **`nicebuildSDK` 目录已存在怎么办？** `mt clone`/`mt init` 会跳过已存在的目录，不会覆盖。
- **子模块初始化失败怎么办？** 按提示手动执行 `cd Plaud-App && git submodule update --init --recursive`。
