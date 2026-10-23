#!/usr/bin/env python3
"""CleanYourPhone CLI & Device Helper.

Provides automatic ADB environment bootstrapping, multi-brand device probing,
status backup and ADB helper functions.
"""
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
BIN_DIR = TOOLS_DIR / "bin"


def ensure_adb():
    """Ensure adb binary is available. If not, auto-download Google platform-tools."""
    # 1. 优先使用系统已有的 adb
    system_adb = shutil.which("adb")
    if system_adb:
        return system_adb

    # 2. 检查本地 tools/bin 是否已下载过
    bin_name = "adb.exe" if platform.system() == "Windows" else "adb"
    local_adb = BIN_DIR / "platform-tools" / bin_name
    if local_adb.is_file() and os.access(local_adb, os.X_OK):
        return str(local_adb)

    # 3. 自动从 Google 官方轻量源下载 (约 10MB)
    system_name = platform.system()
    if system_name == "Darwin":
        url = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
    elif system_name == "Linux":
        url = "https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
    elif system_name == "Windows":
        url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    else:
        sys.exit(f"错误: 不支持的操作系统 {system_name}，请手动安装 adb。")

    print("=" * 48, file=sys.stderr)
    print("检测到电脑尚未配置 ADB，正在为您全自动准备环境...", file=sys.stderr)
    print("正在从 Google 官方直链获取 platform-tools (~10MB)...", file=sys.stderr)
    print("=" * 48, file=sys.stderr)

    BIN_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = BIN_DIR / "platform-tools.zip"

    try:
        urllib.request.urlretrieve(url, zip_path)
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(BIN_DIR)
        if zip_path.exists():
            zip_path.unlink()
        if platform.system() != "Windows":
            local_adb.chmod(0o755)
        print("✓ ADB 调试环境已自动就绪！无需手动配置环境变量。\n", file=sys.stderr)
        return str(local_adb)
    except Exception as e:
        sys.exit(f"自动下载 ADB 失败 ({e})。请检查网络，或手动安装 platform-tools。")


def run_adb(args, check=True):
    """Run an ADB command and return stdout string."""
    adb_path = ensure_adb()
    cmd = [adb_path] + args
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=check,
        )
        return res.stdout.strip()
    except subprocess.CalledProcessError as e:
        if check:
            sys.exit(f"ADB 命令执行失败 ({' '.join(cmd)}):\n{e.stderr.strip()}")
        return ""


def get_prop(name):
    """Get system property value."""
    return run_adb(["shell", "getprop", name], check=False)


def detect_brand():
    """Detect phone brand and return brand id matching rules/<brand>."""
    raw_brand = (get_prop("ro.product.brand") or get_prop("ro.product.manufacturer") or "").lower()
    if any(k in raw_brand for k in ("xiaomi", "redmi", "poco", "blackshark")):
        return "xiaomi"
    if any(k in raw_brand for k in ("oppo", "oneplus", "realme")):
        return "oppo"
    if any(k in raw_brand for k in ("vivo", "iqoo")):
        return "vivo"
    if any(k in raw_brand for k in ("honor", "huawei")):
        return "honor"
    if any(k in raw_brand for k in ("samsung",)):
        return "samsung"
    return "unknown"


def probe():
    """Probe connected device info."""
    devices = run_adb(["devices"]).splitlines()
    online_devices = [line.split()[0] for line in devices[1:] if "\tdevice" in line]
    if not online_devices:
        sys.exit("错误: 未检测到已连接的 Android 设备。\n请用数据线连接手机，并在手机上开启「USB 调试」且点击「允许调试」。")

    brand = get_prop("ro.product.brand") or get_prop("ro.product.manufacturer")
    model = get_prop("ro.product.model")
    market_name = get_prop("ro.product.marketname")
    android_ver = get_prop("ro.build.version.release")
    sdk_ver = get_prop("ro.build.version.sdk")
    miui_ver = get_prop("ro.miui.ui.version.name")
    os_ver = get_prop("ro.build.version.incremental")
    brand_id = detect_brand()

    print("=" * 48)
    print("           CleanYourPhone 设备探针")
    print("=" * 48)
    print(f"品牌 / 厂商:   {brand} (规则标识: {brand_id})")
    print(f"设备型号:       {model} {f'({market_name})' if market_name else ''}")
    print(f"Android 版本:  {android_ver} (API Level {sdk_ver})")
    if miui_ver:
        print(f"定制系统:       {miui_ver} ({os_ver})")
    else:
        print(f"固件版本:       {os_ver}")
    print("=" * 48)
    return brand, model


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--get-adb-path":
        print(ensure_adb())
        return

    if len(sys.argv) > 1 and sys.argv[1] == "--get-brand":
        print(detect_brand())
        return

    if len(sys.argv) < 2 or sys.argv[1] == "--probe":
        probe()
    elif sys.argv[1] == "--getprop":
        if len(sys.argv) > 2:
            print(get_prop(sys.argv[2]))
        else:
            print("用法: phone.py --getprop <属性名>")
    else:
        print("用法: phone.py [--probe | --get-adb-path | --get-brand | --getprop <name>]")


if __name__ == "__main__":
    main()
