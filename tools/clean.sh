#!/usr/bin/env bash
# CleanYourPhone 主执行脚本 (支持全自动运行或分步确认执行)
# 支持参数：
#   tools/clean.sh               (全量连续执行)
#   tools/clean.sh --backup      (仅创建备份快照)
#   tools/clean.sh --debloat     (仅执行阶段一: 停用系统广告服务)
#   tools/clean.sh --settings    (仅执行阶段二: 优化设置与注入 DNS)
#   tools/clean.sh --shake       (仅执行阶段三: 屏蔽第三方摇一摇)
#   tools/clean.sh --help        (显示帮助信息)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backup"

mkdir -p "$BACKUP_DIR"

STAGE="${1:-all}"

if [ "$STAGE" = "--help" ] || [ "$STAGE" = "-h" ]; then
    echo "用法: tools/clean.sh [选项]"
    echo "选项:"
    echo "  (无参数)      执行全量流程 (备份 + 阶段一 + 阶段二 + 阶段三)"
    echo "  --backup     仅创建状态备份快照"
    echo "  --debloat    仅执行【阶段一】: 停用系统级广告服务"
    echo "  --settings   仅执行【阶段二】: 优化广告设置与注入防广告 DNS"
    echo "  --shake      仅执行【阶段三】: 屏蔽第三方 App“摇一摇”广告"
    echo "  --help, -h   显示本帮助信息"
    exit 0
fi

# 1. 自动解析或配置 ADB
ADB=$(python3 "$SCRIPT_DIR/phone.py" --get-adb-path)

# 2. 检查设备连接
DEVICES=$("$ADB" devices | grep -w "device" || true)
if [ -z "$DEVICES" ]; then
    echo "错误: 未检测到连接的设备，请连接手机并确认开启 USB 调试。" >&2
    exit 1
fi

# 3. 动态探测品牌与匹配规则目录
BRAND_ID=$(python3 "$SCRIPT_DIR/phone.py" --get-brand)
BRAND_RAW=$("$ADB" shell getprop ro.product.brand 2>/dev/null | tr -d '\r' || true)
MODEL=$("$ADB" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)
OS_VER=$("$ADB" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)

if [ "$BRAND_ID" = "unknown" ] || [ ! -d "$ROOT_DIR/rules/$BRAND_ID" ]; then
    BRAND_ID="xiaomi"
fi
RULES_DIR="$ROOT_DIR/rules/$BRAND_ID"

# 4. 创建状态快照
ensure_snapshot() {
    LATEST_LINK="$BACKUP_DIR/latest"
    if [ ! -d "$LATEST_LINK" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        SNAPSHOT_DIR="$BACKUP_DIR/snapshot_$TIMESTAMP"
        mkdir -p "$SNAPSHOT_DIR"
        rm -f "$LATEST_LINK"
        ln -s "$SNAPSHOT_DIR" "$LATEST_LINK"
        echo "$BRAND_ID" > "$SNAPSHOT_DIR/brand.txt"

        "$ADB" shell pm list packages -d > "$SNAPSHOT_DIR/disabled_packages_before.txt" 2>/dev/null || true
        "$ADB" shell settings get global private_dns_mode > "$SNAPSHOT_DIR/private_dns_mode_before.txt" 2>/dev/null || true
        "$ADB" shell settings get global private_dns_specifier > "$SNAPSHOT_DIR/private_dns_specifier_before.txt" 2>/dev/null || true
        "$ADB" shell settings get secure limit_ad_tracking > "$SNAPSHOT_DIR/limit_ad_tracking_before.txt" 2>/dev/null || true
        "$ADB" shell settings get system personalized_ad_enabled > "$SNAPSHOT_DIR/personalized_ad_enabled_before.txt" 2>/dev/null || true
        echo "✓ 备份已就绪 -> $SNAPSHOT_DIR"
    fi
}

run_debloat() {
    ensure_snapshot
    SNAPSHOT_DIR=$(readlink "$BACKUP_DIR/latest" || echo "$BACKUP_DIR/latest")
    echo "=================================================="
    echo "【阶段一】停用系统级广告与臃肿服务 (Debloat)..."
    echo "=================================================="
    DEBLOAT_FILE="$RULES_DIR/debloat.txt"
    DISABLED_COUNT=0
    if [ -f "$DEBLOAT_FILE" ]; then
        DEBLOAT_PKGS=$(LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); print}' "$DEBLOAT_FILE" \
          | grep -vE '^\s*(#|$)' | sed -E 's/\s+#.*$//' | awk '{print $1}')
        
        for pkg in $DEBLOAT_PKGS; do
            if [ -n "$pkg" ]; then
                RES=$("$ADB" shell pm disable-user --user 0 "$pkg" 2>&1 | tr -d '\r' || true)
                if [[ "$RES" == *"disabled"* || "$RES" == *"new state"* ]]; then
                    echo "  - 已停用: $pkg"
                    echo "$pkg" >> "$SNAPSHOT_DIR/newly_disabled.txt"
                    DISABLED_COUNT=$((DISABLED_COUNT + 1))
                fi
            fi
        done
        echo "✓ 阶段一完成: 共停用 $DISABLED_COUNT 个系统广告组件。"
    fi
}

run_settings() {
    ensure_snapshot
    echo "=================================================="
    echo "【阶段二】系统广告开关优化与 Private DNS 注入..."
    echo "=================================================="
    SETTINGS_FILE="$RULES_DIR/settings.conf"
    if [ -f "$SETTINGS_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            clean_line=$(echo "$line" | sed -E 's/\s+#.*$//' | xargs)
            if [ -n "$clean_line" ]; then
                read -r ns key val <<< "$clean_line"
                if [ -n "$ns" ] && [ -n "$key" ] && [ -n "$val" ]; then
                    "$ADB" shell settings put "$ns" "$key" "$val" >/dev/null 2>&1 || true
                    echo "  - 设置: [$ns] $key -> $val"
                fi
            fi
        done < "$SETTINGS_FILE"
        echo "✓ 阶段二完成: 已关闭广告推荐，并开启全局防广告 DNS (AdGuard DoT)。"
    fi
}

run_shake() {
    ensure_snapshot
    SNAPSHOT_DIR=$(readlink "$BACKUP_DIR/latest" || echo "$BACKUP_DIR/latest")
    echo "=================================================="
    echo "【阶段三】屏蔽第三方常见 App 的“摇一摇”开屏广告..."
    echo "=================================================="
    SHAKE_FILE="$RULES_DIR/shake_apps.txt"
    [ -f "$SHAKE_FILE" ] || SHAKE_FILE="$ROOT_DIR/rules/shake_apps.txt"

    SHAKE_COUNT=0
    if [ -f "$SHAKE_FILE" ]; then
        INSTALLED_PKGS=$("$ADB" shell pm list packages | sed 's/^package://' | tr -d '\r')
        
        while IFS= read -r line || [ -n "$line" ]; do
            pkg=$(echo "$line" | sed -E 's/\s+#.*$//' | awk '{print $1}')
            if [ -n "$pkg" ]; then
                if echo "$INSTALLED_PKGS" | grep -qx "$pkg"; then
                    "$ADB" shell appops set "$pkg" BODY_SENSORS ignore >/dev/null 2>&1 || true
                    "$ADB" shell appops set "$pkg" ACTIVITY_RECOGNITION ignore >/dev/null 2>&1 || true
                    echo "  - 屏蔽传感器: $pkg"
                    echo "$pkg" >> "$SNAPSHOT_DIR/shake_restricted_apps.txt"
                    SHAKE_COUNT=$((SHAKE_COUNT + 1))
                fi
            fi
        done < "$SHAKE_FILE"
        echo "✓ 阶段三完成: 已对当前手机上安装的 $SHAKE_COUNT 款热门 App 限制摇一摇跳转。"
    fi
}

case "$STAGE" in
    --backup)
        ensure_snapshot
        ;;
    --debloat)
        run_debloat
        ;;
    --settings)
        run_settings
        ;;
    --shake)
        run_shake
        ;;
    all)
        echo "已连接设备: $MODEL (品牌: $BRAND_RAW, 匹配规则: rules/$BRAND_ID)"
        ensure_snapshot
        run_debloat
        run_settings
        run_shake
        echo ""
        echo "=================================================="
        echo "          🎉 清理与优化全部顺利完成！"
        echo "=================================================="
        echo "💡 如需恢复所有修改，随时运行: tools/restore.sh"
        ;;
    *)
        echo "未知参数: $STAGE"
        echo "查看帮助请运行: tools/clean.sh --help"
        exit 1
        ;;
esac
