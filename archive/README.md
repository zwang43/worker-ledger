# archive/ — 2026-08-31 下午的「本地化初版」尝试（已归档）

> ⚠️ 这些文件**不是**本档案的可用版本，仅作过程资料保留。日常使用请回到上级目录，用 `worker_ledger.html` + `启动AI记账桥接.command`。

## 这批文件是怎么来的

2026-08-31 下午，在既有云端工作台（见上级 `技术日志文稿.md`）之外，另起了一轮"纯本地化"尝试，从零重写了前端、桥接服务和 Electron 壳。这批产物**没有基于真实验证过的架构**，与第一代存在系统性冲突：

| 维度 | 第一代（真架构，上级目录） | 本批产物（已归档） |
|---|---|---|
| 桥接契约 | `{ok, records[]}`，端到端验证过 | `{status, result{}}`，与两个自带前端也对不上 |
| oMLX 端口 | `127.0.0.1:8000` | `127.0.0.1:8080` |
| 模型 | `Qwen3.5-4B-expense-MLX-4bit`（LoRA 微调，19 类） | `qwen2.5-coder-7b-instruct-q4`（通用代码模型） |
| CORS/PNA | 完整（含 Chrome PNA 头） | 完全缺失，浏览器会拦截 |
| 前端功能 | 增删改、月度总结、自由基金、真实时薪、AI 预览确认 | 大量丢失，AI 记账无确认直接落库 |

## 各文件问题速记（如需复活先修这些）

- `omlx-bridge.py` — 契约错误；单线程阻塞健康检查；兜底正则会把文本里任意数字当金额；日志路径依赖 CWD。
- `worker_ledger_local*.html` — UTC 日期 bug（东八区凌晨记成昨天）；innerHTML XSS；`Date.now()` 主键批量添加会撞；导入无结构校验；时薪公式退化。
- `mac-app/` — `postinstall` 无限递归；`^latest` 依赖 + ESM-only 包 `require()` 报错；`icon.icns` 不存在；加载路径与 dev.sh 复制目标不一致；preload 暴露未注册的 IPC。
- `check-omlx.sh` — `"~/.omlx/models"` 引号内波浪号不展开，恒为 false。
- `setup-omlx.sh` — Python 版本字符串比较误拒 3.10+；`omlx download` / git clone 安装方式与 oMLX 实际发行方式（Homebrew/DMG 菜单栏应用）不符。
- `Dockerfile*` / `docker-compose.yml`（mac-app 内）— Alpine + X11 跑 Electron GUI 不成立；8080 端口与 oMLX 配置冲突。

## 结论

纯本地方案的正确路径是复用第一代：云端版 `worker_ledger.html` 本身离线即可完整运行，AI 记账配合真桥接（上级目录的 `ai_bridge.py`）即通。本批文件不再维护。
