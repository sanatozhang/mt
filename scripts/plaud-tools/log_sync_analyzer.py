import re
import sys

# filepath: /path/to/your/file.txt
# 假设文件内容存储在 file.txt 中
if len(sys.argv) > 1:
    file_path = sys.argv[1]
else:
    file_path = "plaud.log"

# 用于存储结果的集合（去重）
sync_start_results = set()
sync_complete_results = set()


# 将毫秒转换为英文时间格式 "3h52m12s"
def format_duration(milliseconds):
    """将毫秒转换为英文时间格式，如 3h52m12s"""
    if milliseconds is None:
        return "N/A"
    try:
        total_seconds = int(milliseconds) // 1000
        hours = total_seconds // 3600
        minutes = (total_seconds % 3600) // 60
        seconds = total_seconds % 60

        parts = []
        if hours > 0:
            parts.append(f"{hours}h")
        if minutes > 0 or hours > 0:
            parts.append(f"{minutes}m")
        parts.append(f"{seconds}s")

        return "".join(parts)
    except (ValueError, TypeError):
        return "N/A"


# 正则表达式匹配模式
sync_start_pattern = r"开始同步:\[(.*?)\] \[(.*?)\]"
# 修改正则表达式以捕获时间长度（毫秒），格式为 [数字]/[数字]，第二个数字是时间长度
# 匹配格式：文件同步完成 :[true] [FileKey] [日期时间] [0] [null] [文件路径] [文件大小]/[时间长度(毫秒)]
# 使用非贪婪匹配，匹配最后一个包含 / 的方括号作为文件路径，最后匹配 [数字]/[数字]
sync_complete_pattern = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+).*?文件同步完成 :\[true\] \[(.*?)\] \[(.*?)\].*?\[([^\]]*\/[^\]]+)\].*?\[(\d+)\]/\[(\d+)\]"

# 读取文件并匹配内容
with open(file_path, "r", encoding="utf-8", errors="ignore") as file:
    for line in file:
        # 匹配 "开始同步" 的模式
        sync_start_match = re.search(sync_start_pattern, line)
        if sync_start_match:
            aaaa = sync_start_match.group(1)
            xxx = sync_start_match.group(2)
            sync_start_results.add((aaaa, xxx))  # 使用集合自动去重

        # 匹配 "文件同步完成" 的模式
        sync_complete_match = re.search(sync_complete_pattern, line)
        if sync_complete_match:
            timestamp = sync_complete_match.group(1)
            aaaa000xxx = sync_complete_match.group(2)  # FileKey
            file_name = sync_complete_match.group(3)  # FileName (日期时间字段)
            # group(4) 是文件路径，group(5) 是文件大小，group(6) 实际是 fileSize
            # 通过公式 (fileSize / (80 * 1) * 20) 计算真正的时间长度（毫秒）
            file_size = (
                sync_complete_match.group(6)
                if sync_complete_match.lastindex >= 6
                else None
            )
            # 计算真正的时间长度
            if file_size is not None:
                try:
                    duration_ms = int(file_size) / (80 * 1) * 20
                except (ValueError, TypeError):
                    duration_ms = None
            else:
                duration_ms = None

            sync_complete_results.add(
                (timestamp, aaaa000xxx, file_name, duration_ms)
            )  # 使用集合自动去重

# 提取所有完成记录的 FileKey，用于匹配
completed_filekeys = {item[1] for item in sync_complete_results}  # 提取所有 FileKey

# 打印 "开始同步" 的结果
print("开始同步结果：")
print(f"{'No.':<5}{'Status':<12}{'aaaa':<20}{'xxx':<20}")
print("-" * 57)
for idx, (aaaa, xxx) in enumerate(sorted(sync_start_results), start=1):  # 排序后输出
    # 检查是否有对应的完成记录：FileKey = xxx + aaaa
    expected_filekey = xxx + aaaa
    is_completed = expected_filekey in completed_filekeys
    status = "✓ Complete" if is_completed else "✗ INCOMPLETE"
    print(f"{idx:<5}{status:<12}{aaaa:<20}{xxx:<20}")

print("\n文件同步完成结果：")
# 打印 "文件同步完成" 的结果
print(
    f"{'No.':<5}{'Status':<12}{'FileKey':<20}{'Sync(PLAUD->App)':<30}{'FileName':<30}{'Duration(OPUS)':<15}"
)
print("-" * 112)
for idx, (timestamp, aaaa000xxx, bbb, duration_ms) in enumerate(
    sorted(sync_complete_results), start=1
):  # 排序后输出
    # 检查是否有对应的开始记录：FileKey = xxx + aaaa
    # 遍历所有开始记录，检查是否存在 xxx + aaaa == FileKey
    has_start = any(xxx + aaaa == aaaa000xxx for aaaa, xxx in sync_start_results)
    status = "✓ Complete" if has_start else "⚠ No Start"
    duration_str = format_duration(duration_ms)
    print(
        f"{idx:<5}{status:<12}{aaaa000xxx:<20}|   SyncTime: {timestamp:<30}, FileName: {bbb:<30}, Duration: {duration_str:<15}"
    )
