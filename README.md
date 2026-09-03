# 打工人小账本 · 原生 macOS App

> 由原「记账工作台融合档案（浏览器/Electron 版）」迁移重写：界面与本地账本改为 SwiftUI + SwiftData，AI 记账桥接继续复用原 Python 桥接，数据不出本机。

## 这是什么

- **技术栈**：SwiftUI（macOS 15+）、SwiftData、Swift Charts；Python 3 仅作 AI 桥接 sidecar。
- **功能**：首页 KPI/快捷记账、记账增删改、月度总结、真实时薪、自由基金、洞察/情景模拟、月度账单报告、AI 记账、浅色/深色主题、JSON 导入导出与自动备份。
- **数据位置**：`~/Library/Application Support/cn.ledger.workerapp/`，不再与项目文件夹绑定。

## 构建与运行

```bash
# 1) 需要 Xcode 26+，可用下面命令指定（如已用 Xcode 打开则无需）
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 2) 生成工程（仅当 project.yml 或文件结构变化时需要 xcodegen）
brew install xcodegen   # 首次
xcodegen generate

# 3) 运行（开发调试）
open LedgerApp.xcodeproj
# 或在命令行构建：
xcodebuild -project LedgerApp.xcodeproj -scheme LedgerApp -configuration Debug build

# 4) 测试
xcodebuild -project LedgerApp.xcodeproj -scheme LedgerApp -configuration Debug test
```

> 若桌面目录的文件同步元数据导致 `codesign` 报 “resource fork / Finder information”，把 `-derivedDataPath` 指到 `/private/tmp/ledger-build` 再构建即可。

## 旧数据迁移

首次启动时若本机仍存在：

- `账本数据/backups/*.json`，或
- `archive/legacy-2026-09-04/账本数据/backups/*.json`

App 会自动提示导入最新备份（兼容裸 state JSON 与 `{appId:"worker-ledger",version:1,state:{...}}` 导出格式）。也可以在任何时候用“设置 → 导入 JSON”手动导入。

## 旧版归档

旧浏览器/Electron 实现与过程资料统一保留在 `archive/legacy-2026-09-04/`（源码、测试、截图、schema 快照、技术文档与备份数据）；更早的 2026-08-31 本地化尝试保留在 `archive/` 根层。该目录仅供回退/查阅，不再参与新 App 构建。
