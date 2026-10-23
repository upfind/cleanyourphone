#!/usr/bin/env bash
# CleanYourPhone 主执行脚本 (支持多品牌: 小米、OPPO、vivo、荣耀、三星等)
# 作用：1. 自动准备 ADB 环境  2. 智能探测品牌并路由规则  3. 停用广告服务  4. 优化设置与 DNS  5. 屏蔽摇一摇
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backup"

mkdir -p "$BACKUP_DIR"

echo "=================================================="
echo "        CleanYourPhone - 手机一键去广告"
echo "=================================================="

# 1. 自动解析或配置 ADB
ADB=$(python3 "$SCRIPT_DIR/phone.py" --get-adb-path)

# 2. 检查设备连接
DEVICES=$("$ADB" devices | grep -w "device" || true)
if [ -z "$DEVICES" ]; then
    echo "错误: 未检测到连接的设备！" >&2
    echo "请检查：" >&2
    echo "  1. 手机是否已用数据线连接电脑；" >&2
    echo "  2. 手机是否已在「开发者选项」中开启「USB 调试」；" >&2
    echo "  3. 手机屏幕上是否已弹出并勾选「允许此电脑调试」。" >&2
    exit 1
fi

# 3. 动态探测品牌与匹配规则目录
BRAND_ID=$(python3 "$SCRIPT_DIR/phone.py" --get-brand)
BRAND_RAW=$("$ADB" shell getprop ro.product.brand 2>/dev/null | tr -d '\r' || true)
MODEL=$("$ADB" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)
OS_VER=$("$ADB" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)

echo "已连接设备: $MODEL (品牌: $BRAND_RAW, Android $OS_VER)"

if [ "$BRAND_ID" = "unknown" ] || [ ! -d "$ROOT_DIR/rules/$BRAND_ID" ]; then
    echo "提示: 未自动匹配到特定品牌规则，可选规则如下:"
    echo "  1) xiaomi  (小米 / Redmi / POCO)"
    echo "  2) oppo    (OPPO / 一加 OnePlus / 真我 Realme)"
    echo "  3) vivo    (vivo / iQOO)"
    echo "  4) honor   (荣耀 MagicOS / 华为 EMUI)"
    echo "  5) samsung (三星 One UI)"
    read -r -p "请手动输入要匹配的品牌名称 (例如 xiaomi): " MANUAL_BRAND
    BRAND_ID="${MANUAL_BRAND:-xiaomi}"
fi

RULES_DIR="$ROOT_DIR/rules/$BRAND_ID"
if [ ! -d "$RULES_DIR" ]; then
    echo "错误: 未找到规则目录 $RULES_DIR" >&2
    exit 1
fi

echo "✓ 已匹配专属规则库 -> rules/$BRAND_ID"

# 4. 创建状态快照 (Backup Snapshot)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_DIR="$BACKUP_DIR/snapshot_$TIMESTAMP"
mkdir -p "$SNAPSHOT_DIR"
LATEST_LINK="$BACKUP_DIR/latest"
rm -f "$LATEST_LINK"
ln -s "$SNAPSHOT_DIR" "$LATEST_LINK"
echo "$BRAND_ID" > "$SNAPSHOT_DIR/brand.txt"

echo ""
echo "[1/4] 正在创建操作前备份快照 -> $SNAPSHOT_DIR ..."
"$ADB" shell pm list packages -d > "$SNAPSHOT_DIR/disabled_packages_before.txt" 2>/dev/null || true
"$ADB" shell settings get global private_dns_mode > "$SNAPSHOT_DIR/private_dns_mode_before.txt" 2>/dev/null || true
"$ADB" shell settings get global private_dns_specifier > "$SNAPSHOT_DIR/private_dns_specifier_before.txt" 2>/dev/null || true
"$ADB" shell settings get secure limit_ad_tracking > "$SNAPSHOT_DIR/limit_ad_tracking_before.txt" 2>/dev/null || true
"$ADB" shell settings get system personalized_ad_enabled > "$SNAPSHOT_DIR/personalized_ad_enabled_before.txt" 2>/dev/null || true
echo "✓ 备份已就绪 (可通过 tools/restore.sh 一键精准还原)"

# 5. 阶段一：停用系统级广告服务 (Debloat)
echo ""
echo "[2/4] 正在停用系统级广告与臃肿服务 (Debloat)..."
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
else
    echo "未找到 $DEBLOAT_FILE，跳过阶段一。"
fi

# 6. 阶段二：系统设置级广告关闭与 DNS 注入
echo ""
echo "[3/4] 正在优化系统广告开关与配置 Private DNS..."
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

# 7. 阶段三：封杀第三方常用 App 的“摇一摇”开屏广告
echo ""
echo "[4/4] 正在检测第三方 App 并屏蔽“摇一摇”流氓传感器权限..."
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

echo ""
echo "=================================================="
echo "          🎉 清理与优化全部顺利完成！"
echo "=================================================="
echo "本次操作摘要："
echo "  1. 手机匹配品牌：$BRAND_ID"
echo "  2. 停用广告服务：$DISABLED_COUNT 项"
echo "  3. 屏蔽摇一摇应用：$SHAKE_COUNT 款"
echo "  4. 全局防广告 DNS：已启用"
echo ""
echo "💡 如需恢复所有修改，随时运行: tools/restore.sh"
echo "=================================================="
