import argparse

def format_device_version(version_code, show_full=True):
    """
    将versionCode转换为格式化的版本字符串
    """
    code = version_code or 0
    
    if code < 255:
        return f"{code:04d}"
    
    major = (code >> 16) & 0xFF
    minor = (code >> 8) & 0xFF
    patch = code & 0xFF
    
    return f"{major}.{minor}.{patch}" if show_full else f"{major}.{minor}"

def parse_version_string(version_str):
    """
    将版本字符串反向转换为versionCode
    """
    # 处理4位数字的情况（如0230）
    if version_str.isdigit() and len(version_str) == 4:
        code = int(version_str)
        if 0 <= code <= 255:
            return code
        else:
            raise ValueError(f"4位数字版本必须在0-255之间，输入为: {version_str}")
    
    # 处理x.y或x.y.z格式
    parts = version_str.split('.')
    if len(parts) not in [2, 3]:
        raise ValueError(f"版本格式不正确，应为x.y或x.y.z，输入为: {version_str}")
    
    try:
        major = int(parts[0])
        minor = int(parts[1])
        patch = int(parts[2]) if len(parts) == 3 else 0
    except ValueError:
        raise ValueError(f"版本号部分必须为整数，输入为: {version_str}")
    
    # 检查每个部分是否在有效范围内（0-255）
    for part, name in [(major, "主版本号"), (minor, "次版本号"), (patch, "修订号")]:
        if not (0 <= part <= 255):
            raise ValueError(f"{name}必须在0-255之间，值为: {part}")
    
    return (major << 16) | (minor << 8) | patch

def main():
    parser = argparse.ArgumentParser(description='versionCode与版本字符串转换器')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-c', '--code', type=int, help='传入versionCode，转换为版本字符串')
    group.add_argument('-s', '--string', help='传入版本字符串，转换为versionCode')
    parser.add_argument('-f', '--full', action='store_true', help='当转换为字符串时，是否显示完整版本（包含修订号）')
    
    args = parser.parse_args()
    
    try:
        if args.code is not None:
            # 转换versionCode为字符串
            result = format_device_version(args.code, args.full)
            print(f"versionCode {args.code} 对应的版本字符串为: {result}")
        else:
            # 转换字符串为versionCode
            result = parse_version_string(args.string)
            print(f"版本字符串 '{args.string}' 对应的versionCode为: {result}")
    except ValueError as e:
        print(f"错误: {e}")
        exit(1)

if __name__ == "__main__":
    main()
