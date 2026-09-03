# 打工人小账本 — 纯本地版档案

「打工人小账本」原先部署在 WorkBuddy 平台（云端三张数据表 + 跨设备同步），本档案是它的**纯本地运行版**：同一个应用（`worker_ledger.html`），去掉平台依赖后直接在浏览器打开使用，数据存浏览器 localStorage；AI 记账由本机 oMLX 微调模型经桥接服务完成，数据不出本机。

## 目录结构

| 文件 | 说明 |
|---|---|
| `worker_ledger.html` | 应用本体（单文件，全内联）。离线打开即完整可用：记账、月度总结、自由基金、真实时薪、AI 记账 |
| `ai_bridge.py` | AI 记账桥接服务（127.0.0.1:8899），连接工作台与本地模型 |
| `omlx_expense_bridge.py` | 桥接的解析模块（`bookkeep()` 口语→结构化 JSON，19 类分类） |
| `启动AI记账桥接.command` | 双击启动桥接（含 oMLX 就绪检测） |
| `技术日志文稿.md` | 融合架构、契约、坑的完整技术记录（权威参考） |
| `原始工作日志_2026-08-31.md` | 当日平台侧工作日志原始副本 |
| `数据表schema_*.json` ×3 | 原云端三张表的 schema 快照（迁移/对照用） |
| `archive/` | 已归档的本地化初版尝试，勿使用（见其中 README） |

## 快速开始

**不用 AI 记账**：直接双击打开 `worker_ledger.html` 即可，无需任何服务。

**使用 AI 记账**（自然语言→自动记账）：

1. 打开 oMLX（菜单栏应用），确认已加载微调模型 `Qwen3.5-4B-expense-MLX-4bit`
   （oMLX 默认接口 `http://127.0.0.1:8000`，可用 `curl http://127.0.0.1:8000/v1/models` 验证）
2. 双击 `启动AI记账桥接.command`，保持窗口开启（或终端运行 `python3 ai_bridge.py`）
3. 浏览器打开 `worker_ledger.html` →「AI 记账」页 → 输入口语（如"今天买咖啡花了25"）→ 解析 → 预览确认 → 记入

> 相对日期（今天/昨天/前天/大前天）由桥接服务按系统时钟确定性换算，不依赖模型猜测，跨天使用不会记错；明文日期（如"8月30号"）由模型解析。
> 注意：桥接默认开启"思考"模式（准但慢，约 30–60 秒/句）。追求速度可 `OMLX_THINK=0 python3 ai_bridge.py` 启动。

**AI 记账报「本地 AI 未启动」时排查**：oMLX 是否打开并加载了微调模型 → 桥接窗口是否开着 → `curl http://127.0.0.1:8899/health` 看 `online`/`loaded` 字段。

## 从云端迁移历史数据

真实账本数据在 WorkBuddy 云端（协作态：`https://www.workbuddy.cn/space/d/4mNEfNUZ799yw6Gdx6oqre`），迁移到本地两步：

1. 在**平台版**页面打开「导出 JSON」（工具区），得到一份 `{appId:"worker-ledger", version:1, state:{…}}` 格式的文件
2. 本地打开 `worker_ledger.html`，用「导入 JSON」选该文件

导入会做完整校验（appId、字段类型、重复 ID、2MB 上限），失败不会覆盖现有数据。若平台版本较旧没有导出按钮，可在平台页面的浏览器控制台执行 `copy(JSON.stringify({appId:'worker-ledger',version:1,state:JSON.parse(localStorage.getItem('wb_workspace_worker_ledger_state_v1'))}))` 后直接粘贴存盘。

> 档案内的 `数据表schema_*.json` 是云端三张表（流水/月度总结/个人设置）的字段快照，如需反向同步回云端可对照使用。

## 数据安全

- 数据存于**当前浏览器的 localStorage**（键 `wb_workspace_worker_ledger_state_v1`）：清浏览器数据、换浏览器/换机都会丢，请定期用「导出 JSON」备份
- file:// 打开与 https 打开属于不同源，localStorage 互不相通
- AI 记账过程中，账单文本只发往本机 127.0.0.1，不出网

## 技术细节

桥接契约（`{ok, records[]}`）、CORS/PNA 三重拦截、真实时薪公式（21.75 天/月）、分类降维映射（19 类→6 类）等，全部见 `技术日志文稿.md`。模型侧依赖 GitHub 仓库 `expense-portable`（本机 `/Users/zhengwang/github_repos/expense-portable/`），本档案已收编其桥接两件套的副本；如需终端记账入口、LoRA 微调数据飞轮等完整能力，回原仓库。
