#!/usr/bin/env python3
"""CleanYourPhone CLI & Device Helper.

Provides device probing, status backup and ADB helper functions.
Supports standard system ADB via USB or Wi-Fi.
"""
import os
import re
import subprocess
import sys
from pathlib import Path


def run_adb(args, check=True):
    """Run an ADB command and return stdout string."""
    cmd = ["adb"] + args
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=check,
        )
        return res.stdout.strip()
    except FileNotFoundError:
        sys.exit("错误: 未找到 adb 命令。请先安装 Android Platform Tools 并将其加入 PATH。")
    except subprocess.CalledProcessError as e:
        if check:
            sys.exit(f"ADB 命令执行失败 ({' '.join(cmd)}):\n{e.stderr.strip()}")
        return ""


def get_prop(name):
    """Get system property value."""
    return run_adb(["shell", "getprop", name], check=False)


def probe():
    """Probe connected device info."""
    devices = run_adb(["devices"]).splitlines()
    online_devices = [line.split()[0] for line in devices[1:] if "\tdevice" in line]
    if not online_devices:
        sys.exit("错误: 未检测到已连接的 Android 设备。请开启手机 USB 调试并允许电脑连接。")

    brand = get_prop("ro.product.brand") or get_prop("ro.product.manufacturer")
    model = get_prop("ro.product.model")
    market_name = get_prop("ro.product.marketname")
    android_ver = get_prop("ro.build.version.release")
    sdk_ver = get_prop("ro.build.version.sdk")
    miui_ver = get_prop("ro.miui.ui.version.name")
    os_ver = get_prop("ro.build.version.incremental")

    print("=" * 48)
    print("           CleanYourPhone 设备探针")
    print("=" * 48)
    print(f"品牌 / 厂商:   {brand}")
    print(f"设备型号:       {model} {f'({market_name})' if market_name else ''}")
    print(f"Android 版本:  {android_ver} (API Level {sdk_ver})")
    if miui_ver:
        print(f"MIUI/HyperOS:  {miui_ver} ({os_ver})")
    else:
        print(f"固件版本:       {os_ver}")
    print("=" * 48)
    return brand, model


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--probe":
        probe()
    elif sys.argv[1] == "--getprop":
        if len(sys.argv) > 2:
            print(get_prop(sys.argv[2]))
        else:
            print("用法: phone.py --getprop <属性名>")
    else:
        print("用法: phone.py [--probe | --getprop <name>]")


if __name__ == "__main__":
    main()
