# Worker Ledger AI - Mac App

## 📋 项目概述

Worker Ledger AI 是一个基于 oMLX 的本地化 AI 记账工作台 Mac 应用。它提供了原生的 Mac 体验，同时支持本地 AI 智能记账功能。

## 🚀 功能特点

- 🎯 **本地化 AI 记账**: 基于 oMLX 的智能支出识别
- 🍎 **原生 Mac 体验**: 原生 Mac 应用界面和交互
- 🔒 **数据隐私保护**: 所有 AI 处理在本地完成
- 🚀 **一键启动**: 自动化服务管理和启动
- 📊 **智能分析**: 支出分类、统计和趋势分析
- 🎨 **现代化界面**: 原生 Mac 设计语言

## 📦 系统要求

- **硬件**: Apple Silicon Mac (M1/M2/M3)
- **系统**: macOS 12.0+
- **内存**: 至少 8GB RAM（推荐 16GB+）
- **存储**: 至少 5GB 可用空间
- **Python**: 3.8+（用于 oMLX）

## 🛠️ 安装步骤

### 1. 克隆项目

```bash
git clone <repository-url>
cd mac-app
```

### 2. 安装 oMLX

```bash
./scripts/install-omlx.sh
```

### 3. 安装应用依赖

```bash
npm install
```

### 4. 复制应用文件

```bash
# 确保原始文件在正确位置
cp ../worker_ledger_local_enhanced.html src/
```

## 🚀 使用方法

### 开发模式

```bash
# 启动开发环境
./scripts/dev.sh

# 或直接使用 npm
npm start
```

### 构建应用

```bash
# 构建生产版本
npm run build

# 构建并创建分发包
npm run dist
```

### 运行应用

1. 打开 Finder
2. 进入 `dist/` 目录
3. 双击 `Worker Ledger AI.app` 启动应用

## 📖 应用界面

### 主界面
- 📊 **总览页面**: 本月收入/支出/结余统计
- ⚙️ **个人设置**: 月薪、工作成本、时间配置
- 💰 **手动记账**: 日期、分类、金额录入
- 🤖 **AI 记账**: 自然语言识别支出
- 📋 **历史记录**: 按时间排序的支出记录
- 🔧 **工具箱**: 数据导出/导入/备份

### 系统托盘
- 🎯 **显示/隐藏应用**: 快速切换应用界面
- 🚀 **启动/停止 AI 服务**: 管理 AI 服务
- 🔍 **检查服务状态**: 实时监控服务状态
- ⚙️ **设置**: 应用配置
- ℹ️ **关于**: 应用信息

## 🎯 AI 记账功能

### 支持的自然语言描述
- "今天午餐花了35元，包括一杯咖啡和一份便当"
- "下班打车花了28元"
- "买书花了129元"

### 自动识别信息
- 💰 **金额提取**: 自动识别支出金额
- 📂 **分类识别**: 智能分类到吃饭、交通、购物等
- 📅 **日期处理**: 自动识别或使用当前日期
- 📝 **描述生成**: 生成详细的支出描述

## 🔧 配置文件

### oMLX 配置 (`~/.omlx/config.toml`)
```toml
[server]
host = "127.0.0.1"
port = 8080
model = "qwen2.5-coder-7b-instruct-q4"
max_tokens = 1000
temperature = 0.1
```

### 应用配置
- **服务端口**: oMLX (8080), 桥接 (8899)
- **默认模型**: qwen2.5-coder-7b-instruct-q4
- **超时设置**: 30 秒
- **日志级别**: INFO

## 🛠️ 开发指南

### 项目结构
```
mac-app/
├── src/
│   ├── main.js          # Electron 主进程
│   ├── preload.js       # 预加载脚本
│   └── index.html       # 备用界面
├── resources/
│   ├── omlx-bridge.py  # 桥接服务
│   └── entitlements.mac.plist  # 权限配置
├── scripts/
│   ├── build.sh         # 构建脚本
│   ├── dev.sh          # 开发脚本
│   └── install-omlx.sh # oMLX 安装脚本
├── package.json         # 应用配置
└── README.md           # 说明文档
```

### 开发环境设置
```bash
# 安装依赖
npm install

# 启动开发环境
npm start

# 构建应用
npm run build

# 运行测试
npm test
```

### 构建发布版本
```bash
# 构建应用
npm run build

# 创建分发包
npm run dist

# 清理构建文件
npm run clean
```

## 🔍 故障排除

### 常见问题

1. **应用无法启动**
   ```bash
   # 检查 Node.js 版本
   node --version
   
   # 重新安装依赖
   npm install
   ```

2. **oMLX 服务无法启动**
   ```bash
   # 检查 oMLX 安装
   omlx --version
   
   # 重新安装 oMLX
   ./scripts/install-omlx.sh
   ```

3. **AI 服务连接失败**
   ```bash
   # 检查服务状态
   ./scripts/check-services.sh
   
   # 重新启动服务
   npm start
   ```

4. **应用构建失败**
   ```bash
   # 清理构建文件
   npm run clean
   
   # 重新构建
   npm run build
   ```

### 日志文件
- **应用日志**: `~/Library/Logs/Worker Ledger AI/`
- **oMLX 日志**: `~/.omlx/logs/`
- **桥接服务日志**: 应用内显示

## 📊 性能优化

### 模型选择
| 模型 | 大小 | 推理速度 | 准确率 | 适用场景 |
|------|------|----------|--------|----------|
| qwen2.5-coder-7b | 4.1GB | 中等 | 高 | 推荐 |
| qwen2.5-coder-1.5b | 1.2GB | 快 | 中 | 快速响应 |
| mistral-7b | 4.3GB | 中等 | 高 | 英文场景 |

### 参数调优
```toml
# 更快的响应
temperature = 0.1
max_tokens = 500

# 更准确的响应
temperature = 0.3
max_tokens = 1000
```

## 🔄 更新和维护

### 更新应用
```bash
# 拉取最新代码
git pull

# 重新安装依赖
npm install

# 重新构建
npm run build
```

### 更新 oMLX
```bash
# 进入 oMLX 目录
cd omlx

# 更新代码
git pull

# 重新安装
pip install -e .
```

## 📞 技术支持

### 获取帮助
- 查看 [oMLX 官方文档](https://github.com/jundot/omlx)
- 提交问题到项目仓库
- 查看应用日志文件

### 开发资源
- [Electron 文档](https://www.electronjs.org/docs)
- [oMLX 文档](https://github.com/jundot/omlx)
- [Node.js 文档](https://nodejs.org/docs)

---

🎉 **祝您使用愉快！**
