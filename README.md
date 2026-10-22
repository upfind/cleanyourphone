# CleanYourPhone 📱

> 免 Root、零刷机，基于 ADB 与规则库驱动的 Android 手机一键去广告与系统纯净优化工具。

借鉴 [CleanYourTV](https://github.com/Gathin23/cleanyourtv) 的设计哲学，CleanYourPhone 旨在通过纯本地脚本与 AI 协同，解决智能手机系统中泛滥的开机广告、负一屏资讯、锁屏壁纸营销以及第三方 App 恶劣的“摇一摇”流氓开屏跳转。

---

## ✨ 核心特性

- **🛡️ 纯净安全，100% 可逆**：
  - **免 Root**：仅需开启系统的 USB 调试；
  - **停用而非卸载**：使用 `pm disable-user --user 0` 冻结系统服务，不修改 `/system` 分区，不破坏 OTA 系统更新，不会导致系统崩溃；
  - **自动状态快照**：操作前自动备份原始状态，通过 `tools/restore.sh` 随时一键原样复原。
- **🚀 三层立体去广告策略**（首发支持小米 MIUI / HyperOS）：
  1. **系统级臃肿与广告服务清理（Debloat）**：一键停用 MSA（系统广告分发中心）、Analytics 数据收集、锁屏画报、快应用等流氓常驻服务；
  2. **系统设置级广告关闭（Settings Tweaks）**：批量写入底层系统设置，关闭个性化广告推荐与 OAID 追踪，并注入全局 AdGuard DoT 加密去广告 DNS；
  3. **“摇一摇”流氓跳转彻底封杀（Sensor Blocker）**：通过 Android 原生 `appops` 精准限制微信、淘宝、知乎、微博、B站等常见 App 获取加速度计/陀螺仪数据，在不影响 App 正常使用的前提下终结“手抖即跳转广告”。
- **🤖 完美支持 AI 协作**：
  - 内置 [`PROMPT.md`](PROMPT.md)，将手机连上电脑后，直接把提示词发给 AI 助手（Claude Code、Cursor、Gemini CLI 等），Agent 会全自动探测、备份、执行并生成报告。

---

## 📁 目录结构

```text
cleanyourphone/
├── README.md                      # 项目说明文档
├── PROMPT.md                      # 供 AI Agent 自动执行的操作提示词
├── rules/                         # 规则配置库（规则与执行引擎彻底解耦）
│   └── xiaomi/
│       ├── debloat.txt            # 系统级广告与臃肿组件列表
│       ├── settings.conf          # 系统广告推荐开关与 DoT DNS 配置
│       └── shake_apps.txt         # 常见含“摇一摇”广告的第三方 App 清单
├── tools/                         # 工具链
│   ├── phone.py                   # 极简设备探针与 ADB 工具
│   ├── clean.sh                   # 一键清理执行主脚本（含备份、三阶段清理）
│   └── restore.sh                 # 一键完整状态还原脚本
└── backup/                        # 本地自动备份目录（自动被 git 忽略）
```

---

## 🚀 快速开始

### 准备工作
1. **电脑环境**：确保电脑已安装 `adb`（Android Platform Tools），在终端输入 `adb version` 可正常输出。
2. **手机设置**（以小米 / Redmi 为例）：
   - 打开「设置 → 我的设备 → 全部参数与信息」，连续点击「OS 版本」或「MIUI 版本」7 次，开启开发者模式；
   - 返回「设置 → 更多设置 → 开发者选项」，开启 **USB 调试**（建议同时开启“USB 调试（安全设置）”，部分机型权限修改需要）；
   - 用数据线将手机连接电脑，在手机屏幕弹出的授权弹窗中勾选“始终允许”并点确定。

---

### 方式一：让 AI Agent 帮你跑（最省心）

直接将 [`PROMPT.md`](PROMPT.md) 中的提示词复制发给你的 AI 编程助手（如 Claude Code、Cursor、Gemini CLI），Agent 将全自动完成连接探测、安全备份、分批清理和效果汇报。

---

### 方式二：手动极速执行（适合开发者）

在终端中进入项目目录，执行主脚本：

```bash
# 1. 探测已连接设备信息
python3 tools/phone.py --probe

# 2. 执行一键清理（自动创建备份 -> 停用广告服务 -> 优化设置 -> 屏蔽摇一摇）
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

## 🛡️ 安全底线说明

本项目遵循严格的白名单与安全底线：
- **绝对不触碰**：手机通话短信通信（RIL）、微信/支付宝指纹与安全支付环境、NFC 交通卡门禁、系统安全中心核心、小米官方服务推送框架（xmsf）。
- **零卸载**：所有系统包全部使用用户级停用（`pm disable-user --user 0`），绝不调用破坏性的 `pm uninstall`。
