#!/usr/bin/env python3
"""容器唯一机器码生成工具

首次运行时生成32位唯一ID并写入文件，后续运行直接读取。
用于私有化部署授权系统的机器标识。

用法：
    python generate_machine_id.py [--path /data/.machine_id]
"""

import argparse
import hashlib
import os
import socket
import sys
import time

DEFAULT_MACHINE_ID_PATH = "/data/.machine_id"


def generate_machine_id() -> str:
    """生成32位唯一机器码。

    算法：SHA256(hostname + 当前时间戳 + 32字节随机盐) 取前32位。
    """
    raw = socket.gethostname() + str(time.time()) + os.urandom(32).hex()
    return hashlib.sha256(raw.encode()).hexdigest()[:32]


def get_or_create_machine_id(path: str = DEFAULT_MACHINE_ID_PATH) -> str:
    """获取或创建机器码。

    如果指定路径已存在机器码文件，直接读取返回（保证容器重启不变）。
    如果不存在，生成新的32位ID并写入文件。

    Args:
        path: 机器码文件路径，默认 /data/.machine_id

    Returns:
        32位机器码字符串
    """
    # 已有文件：直接读取
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            machine_id = f.read().strip()
        if machine_id:
            return machine_id

    # 生成新机器码
    machine_id = generate_machine_id()

    # 确保父目录存在
    parent_dir = os.path.dirname(path)
    if parent_dir:
        os.makedirs(parent_dir, exist_ok=True)

    # 写入文件
    with open(path, "w", encoding="utf-8") as f:
        f.write(machine_id)

    return machine_id


def main():
    parser = argparse.ArgumentParser(
        description="容器唯一机器码生成工具",
        epilog="首次运行生成32位ID并持久化，后续运行直接读取。",
    )
    parser.add_argument(
        "--path",
        default=DEFAULT_MACHINE_ID_PATH,
        help=f"机器码文件路径（默认: {DEFAULT_MACHINE_ID_PATH}）",
    )
    args = parser.parse_args()

    try:
        machine_id = get_or_create_machine_id(args.path)
        print(machine_id)
    except PermissionError:
        print(f"错误: 无权限写入 {args.path}，请检查目录权限或使用 --path 指定其他路径", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
