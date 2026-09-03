# 打工人小账本 · 项目总结

## 一、项目定位

「打工人小账本」是一个**纯本地 macOS 记账工作台**：记录支出、管理月度总结与自由基金、计算真实时薪、提供情景洞察，并接入本机 oMLX 微调模型实现“口语 → 结构化记账”。

- 旧形态：单文件 HTML/JavaScript（浏览器版）+ Electron 封装 + Python AI 桥接
- 现形态：**SwiftUI 原生 macOS App + SwiftData 持久化 + Python 桥接 sidecar**
- GitHub：https://github.com/zwang43/worker-ledger （public）
- 本地路径：`/Users/zhengwang/github_repos/worker-ledger/`

## 二、技术架构

| 层 | 技术 | 位置 |
|---|---|---|
| UI | SwiftUI `NavigationSplitView`，简体中文，浅/深主题 | `LedgerApp/Views/` |
| 持久化 | SwiftData（@Model），JSON 兼容导入导出 | `LedgerApp/Models/` |
| 领域公式 | 21.75 工作日/真实时薪/自由基金/三情景 | `LedgerApp/Support/LedgerMath.swift` |
| AI 桥接 | Python HTTP sidecar，动态端口，模型注册表 | `LedgerApp/Resources/bridge/` |
| 工程生成 | XcodeGen（`project.yml` → `.xcodeproj`） | 仓库根目录 |
| 测试 | XCTest：公式、导入校验、迁移、月度报告 | `LedgerAppTests/` |

### 数据模型（与旧 localStorage 一对一映射）

- `ExpenseRecord`：支出流水
- `MonthlySummaryRecord`：月度收入/固定/弹性/结余
- `LedgerProfile` / `FreedomPlan` / `LedgerSettings`：单例设置
- `MonthlyReportRecord`：生成的 Markdown 月度报告

数据默认存于 `~/Library/Application Support/cn.ledger.workerapp/`。

## 三、主要功能

1. 首页：今日/本月支出、真实时薪、自由基金进度、快捷记账、最近记录
2. 记账：增删改、等价工时展示、分页加载、AI 口语记账（解析→预览→确认落库）
3. 月度总结：收入 − 固定支出 − 弹性支出 = 结余，最近 6 个完整月平均
4. 真实时薪：名义/真实时薪、差距方向、每年投入时间
5. 自由基金：目标进度、安全垫 3/6/12 个月、累计曲线、预计达成日期
6. 洞察：白干时间、支出折算工作日、存款排行、通勤/加班/涨薪三情景
7. 月度报告：默认生成上一已结束自然月，可手选任意年月，Markdown 预览/保存/历史
8. 设置：主题、模型注册表管理、导入导出 JSON、自动备份（保留最近 3 份）、清除示例数据

## 四、AI 记账与 oMLX

- 桥接脚本来自原 `expense-portable` 体系，复用微调模型 `Qwen3.5-4B-expense-MLX-4bit`。
- App 启动时以**动态空闲端口**拉起 sidecar，UI 通过该端口调用 `/health` 与 `/parse`。
- 模型注册表写在 Application Support 下，热切换模型无需重启桥接。
- 相对日期策略：**默认使用系统时钟**；按分句喂给模型，每句单独计算“今天/昨天/前天/大前天”，避免多笔混合日期被统一覆盖。
- 已实测：单句与多句相对日期均能正确归入 2026-09-x；oMLX 离线时返回明确错误而非静默成功。

## 五、数据迁移

- 旧版备份格式：裸 `state` JSON 或 `{appId:"worker-ledger", version:1, state:{...}}`。
- 首启自动扫描旧归档备份并弹窗确认导入；也可在“设置 → 导入 JSON”手动导入。
- 保留旧分类 `吃饭/房租` 兼容，未知分类清洗为 `其他`。
- 约束沿用：支出 ≤ 2000 条、月度总结 ≤ 240 条、导入文件 ≤ 2MB、重复 id/month 拒绝。

## 六、构建与测试

```bash
# 生成工程
xcodegen generate

# 构建
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project LedgerApp.xcodeproj -scheme LedgerApp -configuration Release build

# 测试（12 项：公式/导入/报告/迁移）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project LedgerApp.xcodeproj -scheme LedgerApp -configuration Debug test
```

打包发布产物在 `dist/打工人小账本.app`（.gitignore 已排除 dist/）。

## 七、工程与归档约定

- 所有完成项目统一放在 `/Users/zhengwang/github_repos/`，见仓库根 `AGENTS.md`。
- `archive/legacy-2026-09-04/` 保存旧浏览器/Electron 源码与过程资料，仅供回退查阅。
- `~/github_repos/sync_all_repos.sh` 可一键双向同步/自动上传新项目（新建仓库默认 public，可按需修改脚本顶部变量）。

## 八、已知注意点

- 旧桥接二进制已随仓库更新；若未来修改 `LedgerApp/Resources/bridge/*.py`，需重新打包 `bridge-bin/ai_bridge.bin` 并重建 App。
- 本仓库用 XcodeGen 管理工程文件；改 `project.yml` 后执行 `xcodegen generate`。
- GitHub 同步需 `gh` 有效登录；本执行环境偶发 443 网络抖动，失败时重试即可。

*总结日期：2026-09-04*
