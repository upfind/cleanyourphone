#!/usr/bin/env bash
# CleanYourPhone 一键精准恢复脚本 (Xiaomi / HyperOS / MIUI)
# 作用：撤销 clean.sh 所做的所有改动，恢复原厂默认状态
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_DIR="$ROOT_DIR/rules/xiaomi"
BACKUP_DIR="$ROOT_DIR/backup"
LATEST_SNAPSHOT="$BACKUP_DIR/latest"

echo "=================================================="
echo "        CleanYourPhone - 一键还原工具"
echo "=================================================="

if ! command -v adb >/dev/null 2>&1; then
    echo "错误: 未找到 adb 命令。" >&2
    exit 1
fi

DEVICES=$(adb devices | grep -w "device" || true)
if [ -z "$DEVICES" ]; then
    echo "错误: 未检测到连接的设备，请连接手机并确认开启 USB 调试。" >&2
    exit 1
fi

# 1. 恢复被停用的系统广告包
echo ""
echo "[1/3] 正在恢复被停用的系统组件..."
RESTORE_LIST=""
if [ -f "$LATEST_SNAPSHOT/newly_disabled.txt" ]; then
    RESTORE_LIST="$LATEST_SNAPSHOT/newly_disabled.txt"
    echo "使用最近一次操作的精准备份快照..."
elif [ -f "$RULES_DIR/debloat.txt" ]; then
    RESTORE_LIST="$RULES_DIR/debloat.txt"
    echo "未找到独立快照，正在按照规则列表全量回滚..."
fi

if [ -n "$RESTORE_LIST" ]; then
    PKGS=$(LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); print}' "$RESTORE_LIST" \
      | grep -vE '^\s*(#|$)' | sed -E 's/\s+#.*$//' | awk '{print $1}')
    
    RESTORE_COUNT=0
    for pkg in $PKGS; do
        if [ -n "$pkg" ]; then
            adb shell pm enable --user 0 "$pkg" >/dev/null 2>&1 || true
            echo "  - 已重新启用: $pkg"
            RESTORE_COUNT=$((RESTORE_COUNT + 1))
        done
    done
    echo "✓ 阶段一完成: 共恢复 $RESTORE_COUNT 个系统组件。"
fi

# 2. 恢复系统设置与 DNS
echo ""
echo "[2/3] 正在恢复系统设置与 DNS 配置..."
# 恢复 DNS
if [ -f "$LATEST_SNAPSHOT/private_dns_mode_before.txt" ] && [ -s "$LATEST_SNAPSHOT/private_dns_mode_before.txt" ]; then
    ORIG_DNS_MODE=$(cat "$LATEST_SNAPSHOT/private_dns_mode_before.txt" | tr -d '[:space:]')
    adb shell settings put global private_dns_mode "$ORIG_DNS_MODE" >/dev/null 2>&1 || true
    echo "  - 还原 Private DNS 模式: $ORIG_DNS_MODE"
else
    adb shell settings put global private_dns_mode "opportunistic" >/dev/null 2>&1 || true
    echo "  - 还原 Private DNS 模式为默认: opportunistic (自动)"
fi

# 恢复广告追踪开关
adb shell settings put secure limit_ad_tracking 0 >/dev/null 2>&1 || true
adb shell settings put system personalized_ad_enabled 1 >/dev/null 2>&1 || true
echo "  - 还原个性化推荐设置"
echo "✓ 阶段二完成。"

# 3. 恢复第三方 App 的摇一摇传感器权限
echo ""
echo "[3/3] 正在恢复第三方 App 的传感器访问权限..."
SHAKE_LIST=""
if [ -f "$LATEST_SNAPSHOT/shake_restricted_apps.txt" ]; then
    SHAKE_LIST="$LATEST_SNAPSHOT/shake_restricted_apps.txt"
elif [ -f "$RULES_DIR/shake_apps.txt" ]; then
    SHAKE_LIST="$RULES_DIR/shake_apps.txt"
fi

if [ -n "$SHAKE_LIST" ]; then
    SHAKE_PKGS=$(LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); print}' "$SHAKE_LIST" \
      | grep -vE '^\s*(#|$)' | sed -E 's/\s+#.*$//' | awk '{print $1}')
    
    for pkg in $SHAKE_PKGS; do
        if [ -n "$pkg" ]; then
            adb shell appops set "$pkg" BODY_SENSORS allow >/dev/null 2>&1 || true
            adb shell appops set "$pkg" ACTIVITY_RECOGNITION allow >/dev/null 2>&1 || true
            echo "  - 恢复传感器权限: $pkg"
        fi
    done
    echo "✓ 阶段三完成。"
fi

echo ""
echo "=================================================="
echo "          🎉 手机设置已成功完全复原！"
echo "=================================================="
