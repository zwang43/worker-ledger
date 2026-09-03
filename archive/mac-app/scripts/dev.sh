#!/bin/bash

# Worker Ledger AI Mac App 开发脚本

set -e

echo "🔧 启动 Worker Ledger AI 开发环境..."

# 检查是否在正确的目录
if [[ ! -f "package.json" ]]; then
    echo "❌ 错误: 请在 mac-app 目录中运行此脚本"
    exit 1
fi

# 安装依赖（如果需要）
if [[ ! -d "node_modules" ]]; then
    echo "📦 安装依赖..."
    npm install
fi

# 复制应用文件
echo "📁 复制应用文件..."
if [[ -f "../../worker_ledger_local_enhanced.html" ]]; then
    cp "../../worker_ledger_local_enhanced.html" "src/"
    echo "✅ 记账应用文件已复制"
else
    echo "⚠️  警告: 未找到 worker_ledger_local_enhanced.html 文件"
fi

# 设置开发环境变量
export NODE_ENV=development

# 启动应用
echo "🚀 启动开发环境..."
echo "💡 提示: 按 Ctrl+C 停止应用"
echo ""

npm start
