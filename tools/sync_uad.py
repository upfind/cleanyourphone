#!/usr/bin/env python3
"""Sync & Generate Multi-Brand Debloat Rules from UAD-NG (Universal Android Debloater Next Generation).

Source: https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation
This script extracts "Recommended" packages for each major phone brand, categorizes them,
and generates clean, human-readable rules/<brand>/debloat.txt files.
"""
import json
import os
import re
import ssl
import sys
import urllib.request
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
RULES_DIR = ROOT_DIR / "rules"
CACHE_FILE = ROOT_DIR / "tools" / "uad_data_cache.json"
UAD_URL = "https://raw.githubusercontent.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/main/resources/assets/uad_lists.json"

BRANDS = {
    "xiaomi": {
        "title": "小米 / Redmi / POCO (MIUI / HyperOS)",
        "prefixes": ("com.miui.", "com.xiaomi.", "com.mi."),
        "extra_priority": {
            "com.miui.systemAdSolution": "MSA (MIUI System Ad Solution，系统广告核心分发引擎，强烈推荐停用)",
            "com.miui.analytics": "小米系统遥测、数据采集与上报服务",
            "com.miui.bugreport": "错误日志自动收集与上报",
            "com.mfashiongallery.emag": "小米锁屏画报 (锁屏动态广告壁纸)",
            "com.miui.personalassistant": "智能助理/负一屏 (资讯流与广告推广)",
            "com.miui.hybrid": "快应用引擎 (诱导点击并拉起全屏商业推广)",
            "com.miui.hybrid.accessory": "快应用辅助服务",
            "com.miui.yellowpage": "小米黄页服务 (来电推荐与商业广告)",
            "com.miui.player": "小米音乐 (内置大量广告与推广，第三方播放器用户推荐停用)",
            "com.miui.videoplayer": "小米视频 (内置大量广告，第三方播放器用户推荐停用)",
        },
    },
    "oppo": {
        "title": "OPPO / 一加 (OnePlus) / 真我 (Realme) (ColorOS / Realme UI)",
        "prefixes": ("com.oppo.", "com.coloros.", "com.heytap.", "com.nearme.", "com.realme."),
        "extra_priority": {
            "com.heytap.mcs": "欢太移动云推送 (通知栏营销广告主力推送服务)",
            "com.coloros.lockscreen.magazine": "ColorOS 锁屏杂志/画报 (锁屏商业推广壁纸)",
            "com.heytap.browser": "欢太浏览器 (自带信息流资讯与广告)",
            "com.coloros.gamespace": "游戏空间 (内置游戏中心广告推广)",
            "com.nearme.statistics": "欢太数据统计与遥测上报",
            "com.heytap.habit.analysis": "用户习惯分析与个性化广告画像服务",
            "com.oppo.market": "欢太软件商店推广组件",
            "com.heytap.music": "自带音乐推广组件",
            "com.heytap.yoli": "自带视频/短视频信息流推广",
        },
    },
    "vivo": {
        "title": "vivo / iQOO (OriginOS / Funtouch OS)",
        "prefixes": ("com.vivo.", "com.bbk."),
        "extra_priority": {
            "com.vivo.magazine": "vivo 锁屏画报/杂志壁纸广告",
            "com.vivo.space": "vivo 营销中心/生活服务商业推广",
            "com.vivo.browser": "vivo 自带浏览器 (信息流推广与资讯广告)",
            "com.bbk.appstore.game": "游戏推荐服务",
            "com.vivo.pushservice": "vivo 营销推送通道",
            "com.vivo.hiboard": "负一屏/智慧桌面资讯信息流",
            "com.vivo.music": "自带音乐商业推广",
            "com.vivo.video": "自带视频流媒体推广",
        },
    },
    "honor": {
        "title": "荣耀 (MagicOS) / 华为 (EMUI / HarmonyOS)",
        "prefixes": ("com.hihonor.", "com.huawei."),
        "extra_priority": {
            "com.huawei.magazine": "华为杂志锁屏商业广告",
            "com.hihonor.magazinelock": "荣耀杂志锁屏商业广告",
            "com.huawei.browser": "华为自带浏览器信息流",
            "com.hihonor.browser": "荣耀自带浏览器信息流",
            "com.huawei.livecontent": "情景智能商业信息流",
            "com.huawei.hms.analytics": "HMS 遥测与数据分析上报",
            "com.huawei.android.pushagent": "通知栏营销推送通道",
        },
    },
    "samsung": {
        "title": "三星 (Samsung One UI)",
        "prefixes": ("com.samsung.", "com.sec."),
        "extra_priority": {
            "com.samsung.android.app.spage": "Samsung Free / 负一屏资讯与推广广告",
            "com.samsung.android.sm.devicesecurity": "自带 McAfee 杀毒安全扫描与弹窗推广",
            "com.samsung.android.bixby.wakeup": "Bixby 语音唤醒 (如果不使用可停用)",
            "com.samsung.android.game.gamehome": "游戏中心 (内置游戏推广与推荐)",
            "com.sec.android.app.samsungapps": "三星应用商店推广推送",
            "com.samsung.android.spay": "三星智付内置轮播活动推广",
        },
    },
}


def load_uad_data():
    """Load UAD-NG data from local cache or download online."""
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                print(f"使用本地缓存数据: {CACHE_FILE}")
                return json.load(f)
        except Exception:
            pass

    print(f"正在从 UAD-NG 仓库下载最新数据 ({UAD_URL})...")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(UAD_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f)
        print("✓ 数据下载并缓存成功！")
        return data


def categorize_package(pkg, desc):
    """Categorize a package by its name and description keywords."""
    p_lower = pkg.lower()
    d_lower = desc.lower()

    if any(k in p_lower or k in d_lower for k in ("analytics", "statistic", "bugreport", "log", "ad", "tracking", "telemetry", "mcs", "msa", "feedback", "report")):
        return 1, "核心广告、统计与遥测追踪服务"
    if any(k in p_lower or k in d_lower for k in ("magazine", "wallpaper", "lockscreen", "emag", "theme")):
        return 2, "锁屏画报、壁纸与商业轮播"
    if any(k in p_lower or k in d_lower for k in ("assistant", "hybrid", "browser", "search", "spage", "hiboard", "feed", "news")):
        return 3, "负一屏资讯、信息流与自带浏览器推广"
    if any(k in p_lower or k in d_lower for k in ("game", "music", "video", "player", "mall", "store", "shop")):
        return 4, "视听娱乐、应用商店与游戏中心推广"
    return 5, "其他推荐停用的系统臃肿组件 (UAD Recommended)"


def generate_rules():
    data = load_uad_data()

    for brand_id, b_meta in BRANDS.items():
        brand_dir = RULES_DIR / brand_id
        brand_dir.mkdir(parents=True, exist_ok=True)
        debloat_file = brand_dir / "debloat.txt"
        settings_file = brand_dir / "settings.conf"

        # 匹配该品牌且属于 Recommended 的包
        matched_pkgs = {}
        for pkg, info in data.items():
            if info.get("removal") == "Recommended":
                if any(pkg.startswith(p) for p in b_meta["prefixes"]):
                    matched_pkgs[pkg] = info.get("description", "").strip().replace("\n", " ")

        # 注入高优自定义包
        for pkg, desc in b_meta.get("extra_priority", {}).items():
            matched_pkgs[pkg] = desc

        # 分类整理
        categories = {1: [], 2: [], 3: [], 4: [], 5: []}
        cat_names = {
            1: "核心广告、统计与遥测追踪服务",
            2: "锁屏画报、壁纸与商业轮播",
            3: "负一屏资讯、信息流与自带浏览器推广",
            4: "视听娱乐、应用商店与游戏中心推广",
            5: "其他推荐停用的系统臃肿组件 (UAD Recommended)",
        }

        for pkg, desc in sorted(matched_pkgs.items()):
            cid, _ = categorize_package(pkg, desc)
            clean_desc = desc.split("\n")[0].strip()
            categories[cid].append((pkg, clean_desc))

        # 写入 debloat.txt
        with open(debloat_file, "w", encoding="utf-8") as f:
            f.write(f"# {b_meta['title']} 广告与臃肿服务精简列表\n")
            f.write("# 数据来源：UAD-NG (Universal Android Debloater Next Generation) + 本地优化规则\n")
            f.write("# 级别：Recommended (推荐停用，不影响系统正常核心功能与通信)\n")
            f.write("# 说明：采用 pm disable-user --user 0 停用，不卸载，随时可通过 tools/restore.sh 一键恢复。\n\n")

            for cid in sorted(categories.keys()):
                items = categories[cid]
                if not items:
                    continue
                f.write(f"# ==================== {cid}. {cat_names[cid]} ({len(items)} 项) ====================\n")
                for pkg, desc in items:
                    if desc:
                        f.write(f"{pkg:<40} # {desc}\n")
                    else:
                        f.write(f"{pkg}\n")
                f.write("\n")

        print(f"✓ 已生成 [{brand_id}] 规则列表 -> {debloat_file} (共收录 {len(matched_pkgs)} 个推荐停用包)")

        # 生成该品牌对应的 settings.conf
        if not settings_file.exists():
            with open(settings_file, "w", encoding="utf-8") as f:
                f.write(f"# {b_meta['title']} 系统设置优化项\n")
                f.write("# 格式: 命名空间(global/secure/system) 键名 目标值 # 注释\n\n")
                f.write("# 1. 全局 DoT 去广告 Private DNS (阻断第三方 App 广告 SDK 请求)\n")
                f.write("global private_dns_mode hostname # 启用加密 DNS\n")
                f.write("global private_dns_specifier dns.adguard-dns.com # AdGuard 去广告 DNS\n\n")
                f.write("# 2. 限制广告跟踪\n")
                f.write("secure limit_ad_tracking 1 # 限制广告追踪\n")
                f.write("system personalized_ad_enabled 0 # 关闭个性化推荐\n")
            print(f"✓ 已创建 [{brand_id}] 设置配置 -> {settings_file}")

    print("\n所有品牌配置文件均已独立生成于 rules/ 目录下！")


if __name__ == "__main__":
    generate_rules()
