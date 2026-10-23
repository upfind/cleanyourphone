# CleanYourPhone - AI Agent 操作提示词

将本文件内容复制并发送给具备终端 Shell 执行能力的 AI 编码助手（如 Claude Code, Gemini CLI, Cursor 等）。

---

我已经将我的 Android 手机（支持小米、OPPO、vivo、荣耀、三星等）通过 USB 数据线连接到电脑，并已开启「开发者选项 → USB 调试」。
请基于当前项目（CleanYourPhone）的代码和工具，帮我进行一次全面的手机广告清理与优化。

### 执行流程与安全规则：

1. **设备探针与品牌自动识别**：
   - 运行 `python3 tools/phone.py --probe` 检查已连接的设备信息；
   - 确认手机已被正确识别（支持 xiaomi, oppo, vivo, honor, samsung 等）。

2. **安全优先，绝不卸载**：
   - 严禁执行 `pm uninstall`，只能使用 `pm disable-user --user 0` 停用系统包；
   - 在执行任何改动前，确保自动建立好状态备份快照；
   - 绝不触碰核心通信（RIL/电话/短信）、安全中心、微信/支付宝支付环境和系统推送核心框架。

3. **执行一键清理流水线**：
   - 执行 `tools/clean.sh`；
   - 自动化完成：
     a. 自动路由加载 `rules/<手机品牌>/debloat.txt`，停用该品牌推荐停用的广告、遥测和臃肿服务；
     b. 根据 `rules/<手机品牌>/settings.conf` 关闭个性化广告推荐，并注入 AdGuard DoT 加密去广告 DNS；
     c. 扫描手机已安装的常见 App，根据 `rules/shake_apps.txt` 限制其加速度传感器权限，彻底封杀“摇一摇”开屏广告。

4. **汇报与收尾**：
   - 统计并向我汇报停用的系统广告包数量和限制摇一摇的应用数量；
   - 告知我如何使用 `tools/restore.sh` 随时进行一键全量恢复；
   - 提醒我在完成清理后，可根据需要前往设置中关闭 USB 调试。
