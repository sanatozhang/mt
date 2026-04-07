# 构建相关函数（内部实现）
_build_android_internal() {
    local market="$1"
    local build_type="$2"
    local channel="$3"
    local build_all_channels="$4"
    local skip_clean="${5:-false}"  # 第5个参数：是否跳过 clean

    # 验证市场参数
    if [[ "$market" != "cn" ]] && [[ "$market" != "global" ]]; then
        echo -e "${BOLD_RED}错误: 市场参数必须是 cn 或 global${NC}"
        return 1
    fi

    # 验证构建类型
    if [[ "$build_type" != "debug" ]] && [[ "$build_type" != "release" ]] && [[ "$build_type" != "profile" ]]; then
        echo -e "${BOLD_RED}错误: 构建类型必须是 debug、release 或 profile${NC}"
        return 1
    fi

    # CN 版本渠道验证
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

    # Global 版本不支持渠道
    if [[ "$market" == "global" ]] && ([[ -n "$channel" ]] || [[ "$build_all_channels" == "true" ]]); then
        echo -e "${BOLD_YELLOW}警告: Global 版本不支持渠道参数，已忽略${NC}"
        channel=""
        build_all_channels="false"
    fi

    # 执行构建
    local android_dir="${PROJECT_ROOT}/plaud-android"
    if [[ ! -d "$android_dir" ]]; then
        echo -e "${BOLD_RED}错误: Android 项目目录不存在: $android_dir${NC}"
        return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始构建 Android 包${NC}"
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

    # 切换 flavor
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

# 构建相关函数（公开接口）
build_android() {
    local market="$1"
    shift
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            -p|--p|--profile)
                build_type="profile"
                shift
                ;;
            -c|--c|--channel)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --channel 需要指定渠道名称${NC}"
                    return 1
                fi
                channel="$2"
                shift 2
                ;;
            -a|--a|--all)
                build_all_channels=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1
                ;;
        esac
    done

    _build_android_internal "$market" "$build_type" "$channel" "$build_all_channels" "true"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]] && [[ "${BASH_SOURCE[1]:-}" != *"build_check"* ]]; then
        exit $exit_code
    fi

    return $exit_code
}

# 安装 Android 应用（内部实现）
_install_android_internal() {
    local market="$1"
    local build_type="$2"
    local channel="$3"
    local build_all_channels="$4"

    _build_android_internal "$market" "$build_type" "$channel" "$build_all_channels" "true"
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

    local android_dir="${PROJECT_ROOT}/plaud-android"
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
            echo ""
            echo -e "${BOLD_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BOLD_RED}  错误详情:${NC}"
            echo -e "${BOLD_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

            if [[ -n "$install_output" ]]; then
                echo -e "${RED}${install_output}${NC}"
            else
                echo -e "${RED}  未获取到错误信息（退出码: ${install_exit_code}）${NC}"
            fi

            local error_hint=""
            if echo "$install_output" | grep -qi "INSTALL_FAILED_ALREADY_EXISTS\|INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
                error_hint="应用已安装且签名不兼容，请先卸载: adb uninstall <package_name>"
            elif echo "$install_output" | grep -qi "INSTALL_FAILED_INSUFFICIENT_STORAGE"; then
                error_hint="设备存储空间不足，请清理设备存储空间"
            elif echo "$install_output" | grep -qi "INSTALL_FAILED_INVALID_APK"; then
                error_hint="APK 文件损坏或格式不正确，请重新构建"
            elif echo "$install_output" | grep -qi "INSTALL_FAILED_VERSION_DOWNGRADE"; then
                error_hint="安装的版本低于已安装版本，请先卸载或使用 -d 参数允许降级: adb install -d -r <apk>"
            elif echo "$install_output" | grep -qi "INSTALL_FAILED_PERMISSION_DENIED"; then
                error_hint="权限被拒绝，请检查设备是否已授权 USB 调试"
            elif echo "$install_output" | grep -qi "device.*not found\|no devices/emulators found"; then
                error_hint="设备未连接或已断开，请检查 USB 连接和 adb 连接"
            elif echo "$install_output" | grep -qi "INSTALL_PARSE_FAILED\|INSTALL_FAILED"; then
                error_hint="APK 解析失败，可能是构建问题或 APK 文件损坏"
            fi

            if [[ -n "$error_hint" ]]; then
                echo ""
                echo -e "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${BOLD_YELLOW}  建议解决方案:${NC}"
                echo -e "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}  ${error_hint}${NC}"
            fi

            echo -e "${BOLD_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
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
        echo ""
        echo -e "${BOLD_YELLOW}提示:${NC}"
        echo -e "${YELLOW}  - 请检查上述错误详情和解决建议${NC}"
        echo -e "${YELLOW}  - 如果问题持续，可以尝试:${NC}"
        echo -e "${CYAN}    1. 检查设备连接: adb devices${NC}"
        echo -e "${CYAN}    2. 重启 adb: adb kill-server && adb start-server${NC}"
        echo -e "${CYAN}    3. 检查设备存储空间和权限${NC}"
        echo -e "${CYAN}    4. 尝试手动安装: adb install -r <apk_path>${NC}"
        echo ""
        return 1
    fi
    echo -e "${BLUE}========================================${NC}"

    return 0
}

# 安装 Android 应用（公开接口）
install_android() {
    local market="$1"
    shift
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            -p|--p|--profile)
                build_type="profile"
                shift
                ;;
            -c|--c|--channel)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --channel 需要指定渠道名称${NC}"
                    return 1
                fi
                channel="$2"
                shift 2
                ;;
            -a|--a|--all)
                build_all_channels=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1
                ;;
        esac
    done

    _install_android_internal "$market" "$build_type" "$channel" "$build_all_channels"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi

    return $exit_code
}

# 清除缓存函数
clean_cache() {
    local clean_android=true
    local clean_ios=true
    local clean_flutter=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--android)
                clean_android=true
                clean_ios=false
                clean_flutter=false
                shift
                ;;
            -i|--ios)
                clean_android=false
                clean_ios=true
                clean_flutter=false
                shift
                ;;
            -f|--flutter)
                clean_android=false
                clean_ios=false
                clean_flutter=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt clean [-a|--android] [-i|--ios] [-f|--flutter]${NC}"
                echo -e "${CYAN}  -a, --android   只清理 Android 缓存${NC}"
                echo -e "${CYAN}  -i, --ios       只清理 iOS 缓存${NC}"
                echo -e "${CYAN}  -f, --flutter   只清理 Flutter 缓存${NC}"
                echo -e "${CYAN}  无参数          清理全部（Android + iOS + Flutter）${NC}"
                return 1
                ;;
        esac
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  清除缓存${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local cleaned_count=0
    local failed_count=0
    local step_num=1
    local total_steps=0

    if [[ "$clean_flutter" == "true" ]]; then
        ((total_steps++))
    fi
    if [[ "$clean_android" == "true" ]]; then
        ((total_steps++))
    fi
    if [[ "$clean_ios" == "true" ]]; then
        ((total_steps++))
    fi

    if [[ "$clean_flutter" == "true" ]]; then
        echo -e "${CYAN}[${step_num}/${total_steps}] 清除 Flutter 缓存...${NC}"
        ((step_num++))
        local flutter_dirs=(
            "${PROJECT_ROOT}/plaud-flutter-cn/.dart_tool"
            "${PROJECT_ROOT}/plaud-flutter-cn/.flutter-plugins"
            "${PROJECT_ROOT}/plaud-flutter-cn/.flutter-plugins-dependencies"
            "${PROJECT_ROOT}/plaud-flutter-cn/build"
            "${PROJECT_ROOT}/plaud-flutter-global/.dart_tool"
            "${PROJECT_ROOT}/plaud-flutter-global/.flutter-plugins"
            "${PROJECT_ROOT}/plaud-flutter-global/.flutter-plugins-dependencies"
            "${PROJECT_ROOT}/plaud-flutter-global/build"
            "${PROJECT_ROOT}/plaud-flutter-common/.dart_tool"
            "${PROJECT_ROOT}/plaud-flutter-common/.flutter-plugins"
            "${PROJECT_ROOT}/plaud-flutter-common/.flutter-plugins-dependencies"
            "${PROJECT_ROOT}/plaud-flutter-common/build"
        )

        for dir in "${flutter_dirs[@]}"; do
            if [[ -d "$dir" ]] || [[ -f "$dir" ]]; then
                echo -e "${CYAN}  删除: ${dir}${NC}"
                if rm -rf "$dir" 2>/dev/null; then
                    ((cleaned_count++))
                else
                    echo -e "${BOLD_YELLOW}  警告: 无法删除 ${dir}${NC}"
                    ((failed_count++))
                fi
            fi
        done
        echo ""
    fi

    if [[ "$clean_android" == "true" ]]; then
        echo -e "${CYAN}[${step_num}/${total_steps}] 清除 Android 缓存...${NC}"
        ((step_num++))
        local android_dir="${PROJECT_ROOT}/plaud-android"
        if [[ -d "$android_dir" ]]; then
            local android_dirs=(
                "${android_dir}/.gradle"
                "${android_dir}/app/build"
                "${android_dir}/build"
            )

            for dir in "${android_dirs[@]}"; do
                if [[ -d "$dir" ]]; then
                    echo -e "${CYAN}  删除: ${dir}${NC}"
                    if rm -rf "$dir" 2>/dev/null; then
                        ((cleaned_count++))
                    else
                        echo -e "${BOLD_YELLOW}  警告: 无法删除 ${dir}${NC}"
                        ((failed_count++))
                    fi
                fi
            done
        else
            echo -e "${YELLOW}  跳过: Android 目录不存在${NC}"
        fi
        echo ""
    fi

    if [[ "$clean_ios" == "true" ]]; then
        echo -e "${CYAN}[${step_num}/${total_steps}] 清除 iOS 缓存...${NC}"
        local ios_dir="${PROJECT_ROOT}/plaud-ios"
        if [[ -d "$ios_dir" ]]; then
            local ios_dirs=(
                "${ios_dir}/PLAUD/build"
                "${ios_dir}/Pods"
                "${ios_dir}/DerivedData"
            )

            for dir in "${ios_dirs[@]}"; do
                if [[ -d "$dir" ]]; then
                    echo -e "${CYAN}  删除: ${dir}${NC}"
                    if rm -rf "$dir" 2>/dev/null; then
                        ((cleaned_count++))
                    else
                        echo -e "${BOLD_YELLOW}  警告: 无法删除 ${dir}${NC}"
                        ((failed_count++))
                    fi
                fi
            done

            local xcode_derived_data="${HOME}/Library/Developer/Xcode/DerivedData"
            if [[ -d "$xcode_derived_data" ]]; then
                echo -e "${CYAN}  清除 Xcode DerivedData...${NC}"
                echo -e "${YELLOW}  提示: Xcode DerivedData 位于 ${xcode_derived_data}${NC}"
                echo -e "${YELLOW}  如需清除，请手动删除或使用 Xcode 的 Product > Clean Build Folder${NC}"
            fi
        else
            echo -e "${YELLOW}  跳过: iOS 目录不存在${NC}"
        fi
        echo ""
    fi

    echo -e "${BLUE}========================================${NC}"
    if [[ $cleaned_count -gt 0 ]]; then
        echo -e "${GREEN}${CHECK_MARK} 成功清除 ${cleaned_count} 个缓存目录${NC}"
    fi
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${BOLD_RED}${CROSS_MARK} 清除失败 ${failed_count} 个目录${NC}"
    fi
    if [[ $cleaned_count -eq 0 ]] && [[ $failed_count -eq 0 ]]; then
        echo -e "${YELLOW}没有找到需要清除的缓存${NC}"
    fi
    echo -e "${BLUE}========================================${NC}"

    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# go 命令：执行 prebuild + install
go_android() {
    local market="$1"
    shift
    local build_type="debug"
    local channel=""
    local build_all_channels=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            -p|--p|--profile)
                build_type="profile"
                shift
                ;;
            -c|--c|--channel)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${BOLD_RED}错误: --channel 需要指定渠道名称${NC}"
                    return 1
                fi
                channel="$2"
                shift 2
                ;;
            -a|--a|--all)
                build_all_channels=true
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                return 1
                ;;
        esac
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  执行 go 命令（prebuild + install）${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${CYAN}[1/2] 执行 prebuild...${NC}"
    echo ""
    local prebuild_exit_code=0
    capture_command_exit prebuild_exit_code prebuild
    if [[ $prebuild_exit_code -ne 0 ]]; then
        echo -e "${BOLD_RED}错误: prebuild 失败，无法继续${NC}"
        print_composite_failure "go 命令" "prebuild 步骤失败"
        return "$prebuild_exit_code"
    fi
    echo ""

    echo -e "${CYAN}[2/2] 执行 install...${NC}"
    echo ""
    local install_exit_code=0
    capture_command_exit install_exit_code _install_android_internal "$market" "$build_type" "$channel" "$build_all_channels"

    if [[ $install_exit_code -ne 0 ]]; then
        print_composite_failure "go 命令" "install 步骤失败"
        return "$install_exit_code"
    fi

    print_composite_success "go 命令"
    return 0
}

# 预构建：构建 Flutter 模块
prebuild() {
    local build_all_script="${PROJECT_ROOT}/build_all.sh"

    if [[ ! -f "$build_all_script" ]]; then
        echo -e "${BOLD_RED}错误: build_all.sh 不存在: ${build_all_script}${NC}"
        return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始构建 Flutter 模块${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${BLUE}执行 build_all.sh...${NC}"
    print_command "$PROJECT_ROOT" bash "$build_all_script"

    (cd "$PROJECT_ROOT" && bash "$build_all_script" 2>&1) || {
        echo -e "${BOLD_RED}${CROSS_MARK} Flutter 模块构建失败${NC}"
        return 1
    }

    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} Flutter 模块构建成功！${NC}"
    echo -e "${BLUE}========================================${NC}"
    return 0
}

# 编译检查（同时构建 cn 和 global）
build_check() {
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            -p|--p|--profile)
                build_type="profile"
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                exit 1
                ;;
        esac
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  编译检查：同时构建 CN 和 Global${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}构建类型: ${build_type}${NC}"
    echo ""

    local success=true
    local cn_success=false
    local global_success=false

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}构建 CN 版本${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    _build_android_internal cn "$build_type" "" "false" "true" 2>&1
    local cn_exit_code=$?

    if [[ $cn_exit_code -eq 0 ]]; then
        echo -e "${BOLD_GREEN}${CHECK_MARK} CN 构建成功${NC}"
        cn_success=true
    else
        echo -e "${BOLD_RED}${CROSS_MARK} CN 构建失败${NC}"
        success=false
    fi
    echo ""

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}构建 Global 版本${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    _build_android_internal global "$build_type" "" "false" "true" 2>&1
    local global_exit_code=$?

    if [[ $global_exit_code -eq 0 ]]; then
        echo -e "${BOLD_GREEN}${CHECK_MARK} Global 构建成功${NC}"
        global_success=true
    else
        echo -e "${BOLD_RED}${CROSS_MARK} Global 构建失败${NC}"
        success=false
    fi
    echo ""

    echo -e "${BLUE}========================================${NC}"
    if [[ "$cn_success" == true ]] && [[ "$global_success" == true ]]; then
        echo -e "${GREEN}${CHECK_MARK} 编译检查通过：CN 和 Global 构建成功${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 0
    else
        echo -e "${RED}${CROSS_MARK} 编译检查失败：部分构建失败${NC}"
        if [[ "$cn_success" == false ]]; then
            echo -e "${RED}  - CN 构建失败${NC}"
        fi
        if [[ "$global_success" == false ]]; then
            echo -e "${RED}  - Global 构建失败${NC}"
        fi
        echo -e "${BLUE}========================================${NC}"
        return 1
    fi
}

# iOS 构建相关函数
_build_ios_internal() {
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

    local ios_dir="${PROJECT_ROOT}/plaud-ios"
    if [[ ! -d "$ios_dir" ]]; then
        echo -e "${BOLD_RED}错误: iOS 项目目录不存在: $ios_dir${NC}"
        return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始构建 iOS 包${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}市场: ${market}${NC}"
    echo -e "${CYAN}构建类型: ${build_type}${NC}"
    echo ""

    local scheme=""
    local configuration=""
    if [[ "$market" == "cn" ]]; then
        scheme="PLAUD-CN"
    else
        scheme="PLAUD"
    fi

    if [[ "$build_type" == "release" ]]; then
        configuration="Release"
    else
        configuration="Debug"
    fi

    export FLUTTER_MODULE="$market"

    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${BOLD_RED}错误: xcodebuild 命令不可用，请确保已安装 Xcode${NC}"
        return 1
    fi

    local workspace="${ios_dir}/PLAUD/PLAUD.xcworkspace"
    if [[ ! -d "$workspace" ]]; then
        echo -e "${BOLD_RED}错误: Xcode workspace 不存在: $workspace${NC}"
        return 1
    fi

    local derived_data_path="${ios_dir}/PLAUD/build"
    mkdir -p "$derived_data_path"

    echo -e "${BLUE}[1/2] 执行 xcodebuild 构建...${NC}"
    echo -e "${CYAN}Scheme: ${scheme}${NC}"
    echo -e "${CYAN}Configuration: ${configuration}${NC}"
    echo -e "${CYAN}FLUTTER_MODULE: ${FLUTTER_MODULE}${NC}"
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
        FLUTTER_MODULE="$market" \
        2>&1) || {
        echo -e "${BOLD_RED}${CROSS_MARK} iOS 构建失败${NC}"
        return 1
    }

    echo ""

    echo -e "${BLUE}[2/2] 构建完成${NC}"
    echo ""
    echo -e "${BOLD_GREEN}${CHECK_MARK} iOS 构建成功！${NC}"

    local build_dir="${derived_data_path}"
    local product_dir="${build_dir}/Build/Products/${configuration}-iphoneos"

    if [[ -d "$product_dir" ]]; then
        echo -e "${BLUE}构建产物位置:${NC}"
        find "$product_dir" -name "*.app" -type d 2>/dev/null | while read -r app; do
            local app_size
            app_size=$(du -sh "$app" | cut -f1)
            echo -e "${GREEN}  ${CHECK_MARK} $(basename "$app") (${app_size})${NC}"
            echo -e "${CYAN}    ${app}${NC}"
        done
    elif [[ -d "$build_dir" ]]; then
        echo -e "${BLUE}构建产物位置:${NC}"
        find "$build_dir" -name "*.app" -type d 2>/dev/null | head -5 | while read -r app; do
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

# iOS 构建公开接口
build_ios() {
    local market="global"
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            cn|global)
                market="$1"
                shift
                ;;
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt build:ios [cn|global] [-d|-r]${NC}"
                return 1
                ;;
        esac
    done

    _build_ios_internal "$market" "$build_type"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi
}

# 安装 iOS 应用（内部实现）
_install_ios_internal() {
    local market="$1"
    local build_type="$2"

    _build_ios_internal "$market" "$build_type"
    local build_exit_code=$?

    if [[ $build_exit_code -ne 0 ]]; then
        echo -e "${BOLD_RED}构建失败，无法安装${NC}"
        return $build_exit_code
    fi

    local ios_dir="${PROJECT_ROOT}/plaud-ios"
    local build_dir="${ios_dir}/PLAUD/build"
    local app_files=()

    local scheme=""
    if [[ "$market" == "cn" ]]; then
        scheme="PLAUD-CN"
    else
        scheme="PLAUD"
    fi

    local configuration=""
    if [[ "$build_type" == "release" ]]; then
        configuration="Release"
    else
        configuration="Debug"
    fi

    local product_dir="${build_dir}/Build/Products/${configuration}-iphoneos"
    if [[ -d "$product_dir" ]]; then
        while IFS= read -r app; do
            if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                app_files+=("$app")
            fi
        done < <(find "$product_dir" -name "${scheme}.app" -type d 2>/dev/null)

        if [[ ${#app_files[@]} -eq 0 ]]; then
            while IFS= read -r app; do
                if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                    local app_name
                    app_name=$(basename "$app" .app)
                    if [[ "${app_name,,}" == "${scheme,,}" ]]; then
                        app_files+=("$app")
                    fi
                fi
            done < <(find "$product_dir" -name "*.app" -type d 2>/dev/null)
        fi

        if [[ ${#app_files[@]} -eq 0 ]]; then
            while IFS= read -r app; do
                if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                    app_files+=("$app")
                fi
            done < <(find "$product_dir" -name "*.app" -type d 2>/dev/null | head -1)
        fi
    fi

    if [[ ${#app_files[@]} -eq 0 ]] && [[ -d "$build_dir" ]]; then
        while IFS= read -r app; do
            if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                local app_name
                app_name=$(basename "$app")
                if [[ "$app_name" == "${scheme}.app" ]]; then
                    app_files+=("$app")
                fi
            fi
        done < <(find "$build_dir" -name "*.app" -type d 2>/dev/null)

        if [[ ${#app_files[@]} -eq 0 ]]; then
            while IFS= read -r app; do
                if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                    local app_name
                    app_name=$(basename "$app" .app)
                    if [[ "${app_name,,}" == "${scheme,,}" ]]; then
                        app_files+=("$app")
                    fi
                fi
            done < <(find "$build_dir" -name "*.app" -type d 2>/dev/null | head -5)
        fi

        if [[ ${#app_files[@]} -eq 0 ]]; then
            while IFS= read -r app; do
                if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                    app_files+=("$app")
                fi
            done < <(find "$build_dir" -name "*.app" -type d 2>/dev/null | head -1)
        fi
    fi

    if [[ ${#app_files[@]} -eq 0 ]]; then
        local derived_data_base="${HOME}/Library/Developer/Xcode/DerivedData"
        if [[ -d "$derived_data_base" ]]; then
            local recent_derived_data
            recent_derived_data=$(find "$derived_data_base" -maxdepth 1 -type d -name "PLAUD-*" -mmin -30 2>/dev/null | head -1)
            if [[ -n "$recent_derived_data" ]] && [[ -d "$recent_derived_data" ]]; then
                local derived_product_dir="${recent_derived_data}/Build/Products/${configuration}-iphoneos"
                if [[ -d "$derived_product_dir" ]]; then
                    while IFS= read -r app; do
                        if [[ -d "$app" ]] && [[ "$app" == *.app ]]; then
                            app_files+=("$app")
                        fi
                    done < <(find "$derived_product_dir" -name "${scheme}.app" -type d 2>/dev/null)
                fi
            fi
        fi
    fi

    if [[ ${#app_files[@]} -eq 0 ]]; then
        echo -e "${BOLD_RED}错误: 未找到对应的 .app 文件${NC}"
        echo -e "${YELLOW}请检查构建是否成功完成${NC}"
        echo -e "${CYAN}预期构建目录: ${build_dir}${NC}"
        echo -e "${CYAN}预期产物路径: ${product_dir}${NC}"
        echo -e "${YELLOW}提示: 如果构建成功但找不到产物，请检查 Xcode DerivedData 目录${NC}"
        return 1
    fi

    local app_path="${app_files[0]}"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  开始安装到设备${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local devices=()
    local device_names=()

    if command -v xcrun &> /dev/null; then
        local devicectl_output
        devicectl_output=$(xcrun devicectl list devices 2>/dev/null || echo "")
        if [[ -n "$devicectl_output" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ UDID:([[:alnum:]-]+) ]] || [[ "$line" =~ ([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}) ]]; then
                    local udid="${BASH_REMATCH[1]}"
                    local name
                    name=$(echo "$line" | grep -oE "name:[^,]+" | cut -d: -f2 | xargs || echo "Unknown")
                    if [[ -n "$udid" ]] && [[ "$udid" != "00000000-0000-0000-0000-000000000000" ]]; then
                        devices+=("$udid")
                        device_names+=("$name")
                    fi
                fi
            done <<< "$devicectl_output"
        fi
    fi

    if [[ ${#devices[@]} -eq 0 ]] && command -v instruments &> /dev/null; then
        local instruments_output
        instruments_output=$(instruments -s devices 2>/dev/null | grep -E "iPhone|iPad" | grep -v "Simulator" || echo "")
        if [[ -n "$instruments_output" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ \[([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\] ]]; then
                    local udid="${BASH_REMATCH[1]}"
                    local name
                    name=$(echo "$line" | sed -E 's/.*\[.*\] (.*)/\1/' | xargs || echo "Unknown")
                    devices+=("$udid")
                    device_names+=("$name")
                fi
            done <<< "$instruments_output"
        fi
    fi

    if [[ ${#devices[@]} -eq 0 ]] && command -v ios-deploy &> /dev/null; then
        local ios_deploy_output
        ios_deploy_output=$(ios-deploy --detect 2>/dev/null || echo "")
        if [[ -n "$ios_deploy_output" ]]; then
            local udid
            udid=$(echo "$ios_deploy_output" | grep -oE "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" | head -1)
            if [[ -n "$udid" ]]; then
                devices+=("$udid")
                device_names+=("Device")
            fi
        fi
    fi

    if [[ ${#devices[@]} -eq 0 ]]; then
        echo -e "${BOLD_RED}错误: 未检测到已连接的 iOS 设备${NC}"
        echo -e "${YELLOW}请确保:${NC}"
        echo -e "${CYAN}  1. 设备已通过 USB 连接${NC}"
        echo -e "${CYAN}  2. 设备已解锁并信任此计算机${NC}"
        echo -e "${CYAN}  3. 已安装 Xcode 并同意许可协议${NC}"
        echo -e "${YELLOW}提示: 也可以使用 Xcode 直接运行项目来安装${NC}"
        return 1
    fi

    local selected_device=""
    if [[ ${#devices[@]} -eq 1 ]]; then
        selected_device="${devices[0]}"
        echo -e "${CYAN}检测到设备: ${device_names[0]} (${selected_device})${NC}"
    else
        echo -e "${CYAN}检测到 ${#devices[@]} 个设备，请选择:${NC}"
        for i in "${!devices[@]}"; do
            echo -e "${CYAN}  [$((i+1))] ${device_names[$i]} (${devices[$i]})${NC}"
        done
        echo ""
        read -p "请输入设备编号 (1-${#devices[@]}): " device_choice

        if [[ "$device_choice" =~ ^[0-9]+$ ]] && [[ "$device_choice" -ge 1 ]] && [[ "$device_choice" -le ${#devices[@]} ]]; then
            selected_device="${devices[$((device_choice-1))]}"
        else
            echo -e "${BOLD_RED}错误: 无效的设备编号${NC}"
            return 1
        fi
    fi

    echo ""
    echo -e "${CYAN}安装: $(basename "$app_path")${NC}"
    echo -e "${CYAN}路径: ${app_path}${NC}"
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

    if [[ "$install_success" == false ]] && command -v xcrun &> /dev/null; then
        echo -e "${CYAN}尝试使用 xcrun simctl 安装...${NC}"
        if xcrun simctl install "$selected_device" "$app_path" 2>&1; then
            install_success=true
        fi
    fi

    if [[ "$install_success" == true ]]; then
        echo ""
        echo -e "${BOLD_GREEN}  ${CHECK_MARK} 安装成功${NC}"
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}${CHECK_MARK} iOS 应用安装成功！${NC}"
        echo -e "${BLUE}========================================${NC}"
        return 0
    else
        echo ""
        echo -e "${BOLD_RED}  ${CROSS_MARK} 安装失败${NC}"
        echo -e "${YELLOW}提示: 可以尝试使用 Xcode 直接运行项目来安装${NC}"
        echo ""
        echo -e "${BLUE}========================================${NC}"
        return 1
    fi
}

# 安装 iOS 应用（公开接口）
install_ios() {
    local market="global"
    local build_type="debug"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            cn|global)
                market="$1"
                shift
                ;;
            -d|--d|--debug)
                build_type="debug"
                shift
                ;;
            -r|--r|--release)
                build_type="release"
                shift
                ;;
            *)
                echo -e "${BOLD_RED}错误: 未知参数: $1${NC}"
                echo -e "${YELLOW}用法: mt install ios [cn|global] [-d|-r]${NC}"
                return 1
                ;;
        esac
    done

    _install_ios_internal "$market" "$build_type"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        exit $exit_code
    fi

    return $exit_code
}
