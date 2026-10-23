# CleanYourPhone 📱

> 免 Root、零刷机、**免手动安装 ADB**，基于规则库驱动的 Android 手机一键去广告与系统纯净优化工具。

借鉴 [CleanYourTV](https://github.com/Gathin23/cleanyourtv) 的设计哲学，CleanYourPhone 旨在通过全自动脚本与 AI 协同，解决智能手机系统中泛滥的开机广告、负一屏资讯、锁屏壁纸营销以及第三方 App 恶劣的“摇一摇”流氓开屏跳转。

---

## ✨ 核心特性

- **⚡ 零环境门槛（小白友好）**：
  - **无需手动安装 ADB**：电脑上有 `adb` 自动使用；没有 `adb` 时，脚本/AI 会自动从 Google 官方直链秒速拉取免安装运行环境（约 10MB），**用户完全不需要手动配置环境变量**。
- **🌐 全面支持主流手机品牌**（规则源自活跃维护的社区开源数据库 UAD-NG + 本地深度定制）：
  - 📱 **小米 / Redmi / POCO**（MIUI / HyperOS）
  - 📱 **OPPO / 一加 (OnePlus) / 真我 (Realme)**（ColorOS / Realme UI）
  - 📱 **vivo / iQOO**（OriginOS / Funtouch OS）
  - 📱 **荣耀 (Honor) / 华为**（MagicOS / EMUI / HarmonyOS）
  - 📱 **三星 (Samsung)**（One UI）
- **🛡️ 纯净安全，100% 可逆**：
  - **免 Root**：仅需开启手机的 USB 调试；
  - **停用而非卸载**：使用 `pm disable-user --user 0` 冻结系统服务，不修改系统分区，不影响系统 OTA 升级；
  - **自动状态快照**：操作前自动备份原始状态，通过 `tools/restore.sh` 随时一键原样复原。
- **🚀 三层立体去广告策略**：
  1. **系统级臃肿与广告服务清理（Debloat）**：一键停用厂商广告中心（如小米 MSA、OPPO Heytap Push、vivo 营销中心）、数据遥测收集、锁屏画报、快应用等流氓常驻服务；
  2. **系统设置级广告关闭（Settings Tweaks）**：批量写入底层系统设置，关闭个性化广告推荐，并注入全局 AdGuard DoT 加密去广告 DNS；
  3. **“摇一摇”流氓跳转彻底封杀（Sensor Blocker）**：全品牌通用！通过 Android 原生 `appops` 精准限制微信、淘宝、知乎、微博、B站等 22 款常见 App 获取加速度计/陀螺仪数据，在不影响 App 正常使用的前提下终结“手抖即跳转广告”。
- **🤖 完美支持 AI 协作**：
  - 内置 [`PROMPT.md`](PROMPT.md)，将手机连上电脑后，直接把提示词发给 AI 助手（Claude Code、Cursor、Gemini CLI 等），Agent 会全自动准备环境、智能识别手机品牌、备份、执行并生成报告。

---

## 📁 目录结构

```text
cleanyourphone/
├── README.md                      # 项目说明文档
├── PROMPT.md                      # 供 AI Agent 自动执行的操作提示词
├── rules/                         # 品牌规则配置库（每个品牌完全独立）
│   ├── xiaomi/                    # 小米 / Redmi / POCO (156 项推荐停用包)
│   │   ├── debloat.txt
│   │   └── settings.conf
│   ├── oppo/                      # OPPO / 一加 / 真我 (123 项推荐停用包)
│   │   ├── debloat.txt
│   │   └── settings.conf
│   ├── vivo/                      # vivo / iQOO (100 项推荐停用包)
│   │   ├── debloat.txt
│   │   └── settings.conf
│   ├── honor/                     # 荣耀 / 华为 (213 项推荐停用包)
│   │   ├── debloat.txt
│   │   └── settings.conf
│   ├── samsung/                   # 三星 One UI (488 项推荐停用包)
│   │   ├── debloat.txt
│   │   └── settings.conf
│   └── shake_apps.txt             # 全品牌通用：22款常见“摇一摇”第三方应用清单
├── tools/                         # 工具链
│   ├── phone.py                   # 自动环境配置、多品牌自动识别路由
│   ├── sync_uad.py                # 从 UAD-NG 社区数据库同步更新品牌规则的工具
│   ├── clean.sh                   # 一键清理执行主脚本（含自动品牌路由、备份、三阶段清理）
│   └── restore.sh                 # 一键完整状态还原脚本
└── backup/                        # 本地自动备份目录（自动被 git 忽略）
```

---

## 🚀 快速开始

### 准备工作（仅需 1 步）
- **手机开启 USB 调试**：
  1. 打开手机「设置 → 关于手机/关于设备」，连续点击「版本号」7 次开启开发者模式；
  2. 进入「开发者选项」，开启 **USB 调试**；
  3. 用数据线将手机连接电脑，在手机屏幕弹出的授权弹窗中勾选“始终允许”并点确定。
  *(电脑端不需要提前下载或配置任何调试工具！)*

---

### 方式一：让 AI Agent 帮你跑（最省心）

直接将 [`PROMPT.md`](PROMPT.md) 中的提示词复制发给你的 AI 编程助手（如 Claude Code、Cursor、Gemini CLI），Agent 将全自动完成环境就绪、自动识别手机品牌、安全备份、分批清理和效果汇报。

---

### 方式二：手动极速执行

在终端中进入项目目录，直接运行主脚本（脚本会自动识别手机品牌并加载对应的 `rules/<品牌>/` 规则）：

```bash
# 1. 探测已连接设备信息与匹配规则
python3 tools/phone.py --probe

# 2. 执行一键清理（自动配置环境 -> 匹配品牌 -> 创建备份 -> 停用广告服务 -> 优化设置 -> 屏蔽摇一摇）
tools/clean.sh
```

---

## 🔄 如何一键恢复？（后悔药）

如果你打算换机、售后保修，或者某些功能你想要找回，随时可以无损复原：

```bash
tools/restore.sh
```
恢复脚本会做三件事：
1. 从 `backup/` 中读取最近一次操作的快照，把停用的所有系统包重新 `enable` 恢复；
2. 将全局 Private DNS 模式与个性化广告开关恢复为系统默认；
3. 将第三方 App 的传感器访问权限重新放开（`allow`）。

---

## 🛠️ 如何同步社区最新规则库？

我们提供了内置同步工具，后续你可以随时从全球开源社区（UAD-NG）同步最新的机型包名：
```bash
python3 tools/sync_uad.py
```
它会自动重新拉取 UAD-NG 的更新，并自动归类刷新到各品牌的 `debloat.txt` 中。
