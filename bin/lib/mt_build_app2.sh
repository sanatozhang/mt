# plaud-native-app2 (PROJECT_KIND=native-app2) 打包实现
#
# 设计原则: 与 mt_build.sh 完全隔离
# - 所有函数前缀 _app2_，不复用 mt_build.sh 内部函数
# - 路径常量在函数内部局部声明，便于未来 B 项目独立演进
# - 命令行参数解析与 A 项目保持一致（cn/global、-r/-d、-c <channel>、-a 等）
#
# 对应关系（参考 docs/superpowers/specs/2026-05-26-mt-support-native-app2-design.md）:
#   A plaud-android        → B plaud-native-android
#   A plaud-ios/PLAUD/...   → B plaud-native-ios/plaud/...
#   A scheme PLAUD/PLAUD-CN → B scheme Plaud-Global/Plaud-CN

# ============================================================
# Android: build / install
# ============================================================

_app2_build_android_internal() {
    local market="$1"
    local build_type="$2"
    local channel="$3"
    local build_all_channels="$4"
    local skip_clean="${5:-false}"

    if [[ "$market" != "cn" ]] && [[ "$market" != "global" ]]; then
        echo -e "${BOLD_RED}错误: 市场参数必须是 cn 或 global${NC}"
        return 1
    fi

    if [[ "$build_type" != "debug" ]] && [[ "$build_type" != "release" ]] && [[ "$build_type" != "profile" ]]; then
        echo -e "${BOLD_RED}错误: 构建类型必须是 debug、release 或 profile${NC}"
        return 1
    fi

    if [[ "$market" == "cn" ]]; then
        local valid_channels=("official" "huawei" "xiaomi" "oppo" "vivo" "honor" "yingyongbao")
        if [[ -n "$channel" ]]; then
            local valid=false
            for valid_channel in "${valid_channels[@]}"; do
                if [[ "$channel" == "$valid_channel" ]]; then
                    valid=true
                    break
                fi
            done
            if [[ "$valid" == false ]]; then
                echo -e "${BOLD_RED}错误: 无效的渠道 '$channel'${NC}"
                echo -e "${YELLOW}支持的渠道: ${valid_channels[*]}${NC}"
                return 1
            fi
        fi
    fi

    if [[ "$market" == "global" ]] && ([[ -n "$channel" ]] || [[ "$build_all_channels" == "true" ]]); then
        echo -e "${BOLD_YELLOW}警告: Global 版本不支持渠道参数，已忽略${NC}"
        channel=""
        build_all_channels="false"
    fi

    local android_dir="${PROJECT_ROOT}/plaud-native-android"
    if [[ ! -d "$android_dir" ]]; then
        echo -e "${BOLD_RED}错误: Android 项目目录不存在: $android_dir${NC}"
        return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始构建 Android 包 [native-app2]${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}市场: ${market}${NC}"
    echo -e "${CYAN}构建类型: ${build_type}${NC}"
    if [[ "$market" == "cn" ]]; then
        if [[ "$build_all_channels" == "true" ]]; then
            echo -e "${CYAN}渠道: 所有渠道${NC}"
        elif [[ -n "$channel" ]]; then
            echo -e "${CYAN}渠道: ${channel}${NC}"
        else
            echo -e "${CYAN}渠道: official (默认)${NC}"
        fi
    fi
    echo ""

    echo -e "${BLUE}[1/3] 切换 Flavor...${NC}"
    local switch_script="${android_dir}/switch_flavor.sh"
    if [[ ! -f "$switch_script" ]]; then
        echo -e "${BOLD_RED}错误: switch_flavor.sh 不存在${NC}"
        return 1
    fi

    print_command "$android_dir" bash "$switch_script" "$market"

    (cd "$android_dir" && bash "$switch_script" "$market" 2>&1) || {
        echo -e "${BOLD_RED}错误: 切换 Flavor 失败${NC}"
        return 1
    }
    echo -e "${GREEN}${CHECK_MARK} Flavor 已切换为 ${market}${NC}"
    echo ""

    echo -e "${BLUE}[2/3] 执行 Gradle 构建...${NC}"
    local gradle_task=""

    if [[ "$market" == "cn" ]]; then
        if [[ "$build_all_channels" == "true" ]]; then
            if [[ "$build_type" == "release" ]]; then
                gradle_task="assembleCnAllRelease"
            else
                echo -e "${BOLD_RED}错误: --all 选项目前只支持 release 构建${NC}"
                return 1
            fi
        elif [[ -n "$channel" ]]; then
            local channel_capitalized="$(echo "${channel:0:1}" | tr '[:lower:]' '[:upper:]')${channel:1}"
            local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
            gradle_task="assembleCn${channel_capitalized}${build_type_capitalized}"
        else
            local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
            gradle_task="assembleCnOfficial${build_type_capitalized}"
        fi
    else
        local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
        gradle_task="assembleGlobal${build_type_capitalized}"
    fi

    if [[ "$skip_clean" == "true" ]]; then
        echo -e "${CYAN}执行任务: ./gradlew ${gradle_task}${NC}"
        print_command "$android_dir" ./gradlew "$gradle_task" --stacktrace
        (cd "$android_dir" && ./gradlew "$gradle_task" --stacktrace 2>&1) || {
            echo -e "${BOLD_RED}${CROSS_MARK} Gradle 构建失败${NC}"
            return 1
        }
    else
        echo -e "${CYAN}执行任务: ./gradlew clean ${gradle_task}${NC}"
        print_command "$android_dir" ./gradlew clean "$gradle_task" --stacktrace
        (cd "$android_dir" && ./gradlew clean "$gradle_task" --stacktrace 2>&1) || {
            echo -e "${BOLD_RED}${CROSS_MARK} Gradle 构建失败${NC}"
            return 1
        }
    fi
    echo ""

    echo -e "${BLUE}[3/3] 构建完成${NC}"
    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} 构建成功！${NC}"

    local apk_dir="${android_dir}/app/build/outputs/apk"
    if [[ -d "$apk_dir" ]]; then
        echo -e "${BLUE}APK 文件位置:${NC}"
        find "$apk_dir" -name "*.apk" -type f | while read -r apk; do
            local apk_size
            apk_size=$(du -h "$apk" | cut -f1)
            echo -e "${GREEN}  ${CHECK_MARK} $(basename "$apk") (${apk_size})${NC}"
            echo -e "${CYAN}    ${apk}${NC}"
        done
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    return 0
}

_app2_build_android() {
    local market="$1"
    shift
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug)
                build_type="debug"; shift ;;
            -r|--r|--release)
                build_type="release"; shift ;;
            -p|--p|--profile)
                build_type="profile"; shift ;;
            -c|--c|--channel)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --channel 需要指定渠道名称${NC}"
                    return 1
                fi
                channel="$2"; shift 2 ;;
            -a|--a|--all)
                build_all_channels=true; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1 ;;
        esac
    done

    _app2_build_android_internal "$market" "$build_type" "$channel" "$build_all_channels" "true"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]] && [[ "${BASH_SOURCE[1]:-}" != *"build_check"* ]]; then
        exit $exit_code
    fi

    return $exit_code
}

_app2_install_android_internal() {
    local market="$1"
    local build_type="$2"
    local channel="$3"
    local build_all_channels="$4"

    _app2_build_android_internal "$market" "$build_type" "$channel" "$build_all_channels" "true"
    local build_exit_code=$?

    if [[ $build_exit_code -ne 0 ]]; then
        echo -e "${BOLD_RED}构建失败，无法安装${NC}"
        return $build_exit_code
    fi

    if ! command -v adb &> /dev/null; then
        echo -e "${BOLD_RED}错误: adb 命令不可用，请确保已安装 Android SDK Platform Tools${NC}"
        echo -e "${YELLOW}安装方法: brew install android-platform-tools${NC}"
        return 1
    fi

    local devices
    devices=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | wc -l | tr -d ' ')
    if [[ "$devices" -eq 0 ]]; then
        echo -e "${BOLD_RED}错误: 未检测到已连接的 Android 设备${NC}"
        echo -e "${YELLOW}请确保:${NC}"
        echo -e "${CYAN}  1. 设备已通过 USB 连接${NC}"
        echo -e "${CYAN}  2. 已启用 USB 调试${NC}"
        echo -e "${CYAN}  3. 已授权此计算机进行 USB 调试${NC}"
        return 1
    fi

    local android_dir="${PROJECT_ROOT}/plaud-native-android"
    local apk_dir="${android_dir}/app/build/outputs/apk"
    local apk_files=()

    if [[ ! -d "$apk_dir" ]]; then
        echo -e "${BOLD_RED}错误: APK 目录不存在: $apk_dir${NC}"
        return 1
    fi

    if [[ "$market" == "cn" ]]; then
        if [[ "$build_all_channels" == "true" ]]; then
            while IFS= read -r apk; do
                apk_files+=("$apk")
            done < <(find "$apk_dir" -name "*.apk" -type f -path "*/cn/*" 2>/dev/null | sort -r | head -10)
        elif [[ -n "$channel" ]]; then
            local channel_capitalized="$(echo "${channel:0:1}" | tr '[:lower:]' '[:upper:]')${channel:1}"
            local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
            while IFS= read -r apk; do
                local apk_name
                apk_name=$(basename "$apk")
                if [[ "$apk_name" =~ ${channel_capitalized} ]] || [[ "$apk_name" =~ ${channel} ]]; then
                    if [[ "$apk_name" =~ ${build_type_capitalized} ]] || [[ "$apk_name" =~ ${build_type} ]]; then
                        apk_files+=("$apk")
                    fi
                fi
            done < <(find "$apk_dir" -name "*.apk" -type f 2>/dev/null)
        else
            local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
            while IFS= read -r apk; do
                local apk_name
                apk_name=$(basename "$apk")
                if [[ "$apk_name" =~ Official ]] || [[ "$apk_name" =~ official ]]; then
                    if [[ "$apk_name" =~ ${build_type_capitalized} ]] || [[ "$apk_name" =~ ${build_type} ]]; then
                        apk_files+=("$apk")
                    fi
                fi
            done < <(find "$apk_dir" -name "*.apk" -type f 2>/dev/null)
        fi
    else
        local build_type_capitalized="$(echo "${build_type:0:1}" | tr '[:lower:]' '[:upper:]')${build_type:1}"
        while IFS= read -r apk; do
            local apk_name
            apk_name=$(basename "$apk")
            if [[ "$apk_name" =~ Global ]] || [[ "$apk_name" =~ global ]]; then
                if [[ "$apk_name" =~ ${build_type_capitalized} ]] || [[ "$apk_name" =~ ${build_type} ]]; then
                    apk_files+=("$apk")
                fi
            fi
        done < <(find "$apk_dir" -name "*.apk" -type f 2>/dev/null)
    fi

    if [[ ${#apk_files[@]} -eq 0 ]]; then
        echo -e "${BOLD_YELLOW}警告: 未找到精确匹配的 APK，尝试查找最新生成的 APK...${NC}"
        while IFS= read -r apk; do
            apk_files+=("$apk")
        done < <(find "$apk_dir" -name "*.apk" -type f -mmin -5 2>/dev/null | sort -r | head -5)
    fi

    if [[ ${#apk_files[@]} -eq 0 ]]; then
        echo -e "${BOLD_RED}错误: 未找到对应的 APK 文件${NC}"
        echo -e "${YELLOW}请检查构建是否成功完成${NC}"
        echo -e "${CYAN}APK 目录: ${apk_dir}${NC}"
        return 1
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始安装到设备${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local install_success=0
    local install_failed=0

    for apk_file in "${apk_files[@]}"; do
        echo -e "${CYAN}安装: $(basename "$apk_file")${NC}"
        echo -e "${CYAN}路径: ${apk_file}${NC}"
        echo ""

        local install_output
        local install_exit_code
        install_output=$(adb install -r "$apk_file" 2>&1)
        install_exit_code=$?

        if [[ $install_exit_code -eq 0 ]]; then
            if echo "$install_output" | grep -qi "success\|Success"; then
                echo -e "${BOLD_GREEN}  ${CHECK_MARK} 安装成功${NC}"
                ((install_success++))
            else
                echo -e "${BOLD_YELLOW}  ⚠  安装完成（可能有警告）${NC}"
                if [[ -n "$install_output" ]]; then
                    echo -e "${YELLOW}  输出: ${install_output}${NC}"
                fi
                ((install_success++))
            fi
        else
            echo -e "${BOLD_RED}  ${CROSS_MARK} 安装失败${NC}"
            if [[ -n "$install_output" ]]; then
                echo -e "${RED}${install_output}${NC}"
            fi
            ((install_failed++))
        fi
        echo ""
    done

    echo -e "${BLUE}========================================${NC}"
    if [[ $install_success -gt 0 ]]; then
        echo -e "${GREEN}${CHECK_MARK} 成功安装 ${install_success} 个 APK${NC}"
    fi
    if [[ $install_failed -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 安装失败 ${install_failed} 个 APK${NC}"
        return 1
    fi
    echo -e "${BLUE}========================================${NC}"

    return 0
}

_app2_install_android() {
    local market="$1"
    shift
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug) build_type="debug"; shift ;;
            -r|--r|--release) build_type="release"; shift ;;
            -p|--p|--profile) build_type="profile"; shift ;;
            -c|--c|--channel)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --channel 需要指定渠道名称${NC}"
                    return 1
                fi
                channel="$2"; shift 2 ;;
            -a|--a|--all) build_all_channels=true; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1 ;;
        esac
    done

    _app2_install_android_internal "$market" "$build_type" "$channel" "$build_all_channels"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi

    return $exit_code
}

# ============================================================
# iOS: build / install
# ============================================================

# Scheme 映射: cn -> Plaud-CN, global -> Plaud-Global
_app2_ios_scheme_for_market() {
    local market="$1"
    if [[ "$market" == "cn" ]]; then
        echo "Plaud-CN"
    else
        echo "Plaud-Global"
    fi
}

_app2_build_ios_internal() {
    local market="$1"
    local build_type="$2"

    if [[ "$market" != "cn" ]] && [[ "$market" != "global" ]]; then
        echo -e "${BOLD_RED}错误: 市场参数必须是 cn 或 global${NC}"
        return 1
    fi

    if [[ "$build_type" != "debug" ]] && [[ "$build_type" != "release" ]]; then
        echo -e "${BOLD_RED}错误: 构建类型必须是 debug 或 release${NC}"
        return 1
    fi

    local ios_dir="${PROJECT_ROOT}/plaud-native-ios"
    if [[ ! -d "$ios_dir" ]]; then
        echo -e "${BOLD_RED}错误: iOS 项目目录不存在: $ios_dir${NC}"
        return 1
    fi

    local workspace="${ios_dir}/plaud/plaud.xcworkspace"
    if [[ ! -d "$workspace" ]]; then
        echo -e "${BOLD_RED}错误: Xcode workspace 不存在: $workspace${NC}"
        return 1
    fi

    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${BOLD_RED}错误: xcodebuild 命令不可用，请确保已安装 Xcode${NC}"
        return 1
    fi

    local scheme
    scheme=$(_app2_ios_scheme_for_market "$market")

    local configuration
    if [[ "$build_type" == "release" ]]; then
        configuration="Release"
    else
        configuration="Debug"
    fi

    local derived_data_path="${ios_dir}/plaud/build"
    mkdir -p "$derived_data_path"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始构建 iOS 包 [native-app2]${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}市场: ${market}${NC}"
    echo -e "${CYAN}构建类型: ${build_type}${NC}"
    echo -e "${CYAN}Scheme: ${scheme}${NC}"
    echo -e "${CYAN}Configuration: ${configuration}${NC}"
    echo -e "${CYAN}DerivedData: ${derived_data_path}${NC}"
    echo ""

    print_command "$ios_dir" xcodebuild -workspace "$workspace" -scheme "$scheme" -configuration "$configuration" -derivedDataPath "$derived_data_path" build

    (cd "$ios_dir" && xcodebuild \
        -workspace "$workspace" \
        -scheme "$scheme" \
        -configuration "$configuration" \
        -sdk iphoneos \
        -derivedDataPath "$derived_data_path" \
        build \
        2>&1) || {
        echo -e "${BOLD_RED}${CROSS_MARK} iOS 构建失败${NC}"
        return 1
    }

    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} iOS 构建成功！${NC}"

    local product_dir="${derived_data_path}/Build/Products/${configuration}-iphoneos"
    if [[ -d "$product_dir" ]]; then
        echo -e "${BLUE}构建产物位置:${NC}"
        find "$product_dir" -name "*.app" -type d 2>/dev/null | while read -r app; do
            local app_size
            app_size=$(du -sh "$app" | cut -f1)
            echo -e "${GREEN}  ${CHECK_MARK} $(basename "$app") (${app_size})${NC}"
            echo -e "${CYAN}    ${app}${NC}"
        done
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    return 0
}

_app2_build_ios() {
    local market="global"
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            cn|global) market="$1"; shift ;;
            -d|--d|--debug) build_type="debug"; shift ;;
            -r|--r|--release) build_type="release"; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt build:ios [cn|global] [-d|-r]${NC}"
                return 1 ;;
        esac
    done

    _app2_build_ios_internal "$market" "$build_type"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi
}

_app2_install_ios_internal() {
    local market="$1"
    local build_type="$2"

    _app2_build_ios_internal "$market" "$build_type"
    local build_exit_code=$?

    if [[ $build_exit_code -ne 0 ]]; then
        echo -e "${BOLD_RED}构建失败，无法安装${NC}"
        return $build_exit_code
    fi

    local ios_dir="${PROJECT_ROOT}/plaud-native-ios"
    local build_dir="${ios_dir}/plaud/build"
    local scheme
    scheme=$(_app2_ios_scheme_for_market "$market")
    local configuration
    if [[ "$build_type" == "release" ]]; then
        configuration="Release"
    else
        configuration="Debug"
    fi

    local product_dir="${build_dir}/Build/Products/${configuration}-iphoneos"
    local app_files=()

    if [[ -d "$product_dir" ]]; then
        while IFS= read -r app; do
            if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                app_files+=("$app")
            fi
        done < <(find "$product_dir" -name "${scheme}.app" -type d 2>/dev/null)
    fi

    if [[ ${#app_files[@]} -eq 0 ]]; then
        echo -e "${BOLD_RED}错误: 未找到 ${scheme}.app${NC}"
        echo -e "${CYAN}预期产物路径: ${product_dir}${NC}"
        return 1
    fi

    local app_path="${app_files[0]}"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始安装到设备${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}安装: $(basename "$app_path")${NC}"
    echo -e "${CYAN}路径: ${app_path}${NC}"
    echo ""

    # 简化版设备检测: 优先 devicectl，回退 ios-deploy
    local selected_device=""
    if command -v xcrun &> /dev/null; then
        local devicectl_output
        devicectl_output=$(xcrun devicectl list devices 2>/dev/null || echo "")
        selected_device=$(echo "$devicectl_output" | grep -oE "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" | grep -v "00000000-0000-0000-0000-000000000000" | head -1)
    fi

    if [[ -z "$selected_device" ]] && command -v ios-deploy &> /dev/null; then
        selected_device=$(ios-deploy --detect 2>/dev/null | grep -oE "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" | head -1)
    fi

    if [[ -z "$selected_device" ]]; then
        echo -e "${BOLD_RED}错误: 未检测到已连接的 iOS 设备${NC}"
        echo -e "${YELLOW}请确保设备已连接、解锁并信任此计算机${NC}"
        return 1
    fi

    echo -e "${CYAN}设备: ${selected_device}${NC}"
    echo ""

    local install_success=false
    if command -v xcrun &> /dev/null; then
        echo -e "${CYAN}使用 xcrun devicectl 安装...${NC}"
        if xcrun devicectl device install app --device "$selected_device" "$app_path" 2>&1; then
            install_success=true
        fi
    fi
    if [[ "$install_success" == false ]] && command -v ios-deploy &> /dev/null; then
        echo -e "${CYAN}使用 ios-deploy 安装...${NC}"
        if ios-deploy --bundle "$app_path" --id "$selected_device" 2>&1; then
            install_success=true
        fi
    fi

    if [[ "$install_success" == true ]]; then
        echo -e "${BOLD_GREEN}${CHECK_MARK} iOS 应用安装成功！${NC}"
        return 0
    fi

    echo -e "${BOLD_RED}${CROSS_MARK} 安装失败${NC}"
    return 1
}

_app2_install_ios() {
    local market="global"
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            cn|global) market="$1"; shift ;;
            -d|--d|--debug) build_type="debug"; shift ;;
            -r|--r|--release) build_type="release"; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt install ios [cn|global] [-d|-r]${NC}"
                return 1 ;;
        esac
    done

    _app2_install_ios_internal "$market" "$build_type"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi

    return $exit_code
}

# ============================================================
# prebuild / clean / go / build_check
# ============================================================

# B 项目无 Flutter，prebuild 等价于跑两端的 setup 脚本（翻译/埋点/pod install）
_app2_prebuild() {
    local market="${1:-global}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  执行 prebuild [native-app2]${NC}"
    echo -e "${BLUE}  market=${market}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local android_setup="${PROJECT_ROOT}/plaud-native-android/build.sh"
    if [[ -f "$android_setup" ]]; then
        echo -e "${CYAN}[1/2] Android setup (翻译/埋点/git hooks)...${NC}"
        print_command "${PROJECT_ROOT}/plaud-native-android" bash "$android_setup"
        (cd "${PROJECT_ROOT}/plaud-native-android" && bash "$android_setup" 2>&1) || {
            echo -e "${BOLD_RED}${CROSS_MARK} Android setup 失败${NC}"
            return 1
        }
        echo ""
    else
        echo -e "${YELLOW}[1/2] 跳过 Android setup: ${android_setup} 不存在${NC}"
    fi

    local ios_setup="${PROJECT_ROOT}/plaud-native-ios/scripts/start/build.sh"
    if [[ -f "$ios_setup" ]]; then
        echo -e "${CYAN}[2/2] iOS setup (pod install + 翻译, ${market})...${NC}"
        print_command "${PROJECT_ROOT}/plaud-native-ios" bash "$ios_setup" "$market"
        (cd "${PROJECT_ROOT}/plaud-native-ios" && bash "$ios_setup" "$market" 2>&1) || {
            echo -e "${BOLD_YELLOW}⚠ iOS setup 退出非 0（可能 open workspace 失败），不影响 prebuild${NC}"
        }
        echo ""
    else
        echo -e "${YELLOW}[2/2] 跳过 iOS setup: ${ios_setup} 不存在${NC}"
    fi

    echo -e "${BOLD_GREEN}${CHECK_MARK} prebuild 完成${NC}"
    echo -e "${BLUE}========================================${NC}"
    return 0
}

_app2_go_android() {
    local market="$1"
    shift

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  执行 go 命令 [native-app2]（prebuild + install）${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${CYAN}[1/2] 执行 prebuild...${NC}"
    local prebuild_exit_code=0
    capture_command_exit prebuild_exit_code _app2_prebuild "$market"
    if [[ $prebuild_exit_code -ne 0 ]]; then
        print_composite_failure "go 命令" "prebuild 步骤失败"
        return "$prebuild_exit_code"
    fi
    echo ""

    echo -e "${CYAN}[2/2] 执行 install...${NC}"
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug) build_type="debug"; shift ;;
            -r|--r|--release) build_type="release"; shift ;;
            -p|--p|--profile) build_type="profile"; shift ;;
            -c|--c|--channel) channel="$2"; shift 2 ;;
            -a|--a|--all) build_all_channels=true; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1 ;;
        esac
    done

    local install_exit_code=0
    capture_command_exit install_exit_code _app2_install_android_internal "$market" "$build_type" "$channel" "$build_all_channels"
    if [[ $install_exit_code -ne 0 ]]; then
        print_composite_failure "go 命令" "install 步骤失败"
        return "$install_exit_code"
    fi

    print_composite_success "go 命令"
    return 0
}

_app2_clean_cache() {
    local clean_android=true
    local clean_ios=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--android) clean_android=true; clean_ios=false; shift ;;
            -i|--ios) clean_android=false; clean_ios=true; shift ;;
            -f|--flutter)
                echo -e "${BOLD_YELLOW}警告: native-app2 项目无 Flutter 模块，-f 参数被忽略${NC}"
                clean_android=false; clean_ios=false; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt clean [-a|--android] [-i|--ios]${NC}"
                return 1 ;;
        esac
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  清除缓存 [native-app2]${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local cleaned_count=0

    if [[ "$clean_android" == "true" ]]; then
        echo -e "${CYAN}清除 Android 缓存...${NC}"
        local android_dir="${PROJECT_ROOT}/plaud-native-android"
        if [[ -d "$android_dir" ]]; then
            for dir in "${android_dir}/.gradle" "${android_dir}/app/build" "${android_dir}/build"; do
                if [[ -d "$dir" ]]; then
                    echo -e "${CYAN}  删除: ${dir}${NC}"
                    rm -rf "$dir" && ((cleaned_count++)) || true
                fi
            done
        fi
        echo ""
    fi

    if [[ "$clean_ios" == "true" ]]; then
        echo -e "${CYAN}清除 iOS 缓存...${NC}"
        local ios_dir="${PROJECT_ROOT}/plaud-native-ios"
        if [[ -d "$ios_dir" ]]; then
            for dir in "${ios_dir}/plaud/build" "${ios_dir}/plaud/Pods" "${ios_dir}/plaud/Podfile.lock"; do
                if [[ -d "$dir" ]] || [[ -f "$dir" ]]; then
                    echo -e "${CYAN}  删除: ${dir}${NC}"
                    rm -rf "$dir" && ((cleaned_count++)) || true
                fi
            done
        fi
        echo ""
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}${CHECK_MARK} 清除完成 (${cleaned_count} 项)${NC}"
    echo -e "${BLUE}========================================${NC}"
    return 0
}

_app2_build_check() {
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug) build_type="debug"; shift ;;
            -r|--r|--release) build_type="release"; shift ;;
            -p|--p|--profile) build_type="profile"; shift ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"; exit 1 ;;
        esac
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  编译检查 [native-app2]: CN + Global${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local cn_success=false global_success=false

    _app2_build_android_internal cn "$build_type" "" "false" "true" 2>&1
    [[ $? -eq 0 ]] && cn_success=true

    _app2_build_android_internal global "$build_type" "" "false" "true" 2>&1
    [[ $? -eq 0 ]] && global_success=true

    if [[ "$cn_success" == true ]] && [[ "$global_success" == true ]]; then
        echo -e "${GREEN}${CHECK_MARK} 编译检查通过${NC}"
        return 0
    fi
    echo -e "${RED}${CROSS_MARK} 编译检查失败${NC}"
    return 1
}
