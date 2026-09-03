#!/bin/bash

# Worker Ledger AI oMLX 安装脚本

set -e

echo "🚀 开始安装 oMLX..."

# 检查系统要求
check_requirements() {
    echo "📋 检查系统要求..."
    
    # 检查是否为Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        echo "❌ 错误: 此脚本仅支持 Apple Silicon Mac"
        exit 1
    fi
    
    # 检查Python版本
    if ! command -v python3 &> /dev/null; then
        echo "❌ 错误: 未找到 Python3"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [[ "$python_version" < "3.8" ]]; then
        echo "❌ 错误: 需要 Python 3.8 或更高版本，当前版本: $python_version"
        exit 1
    fi
    
    echo "✅ 系统要求检查通过"
}

# 安装oMLX
install_omlx() {
    echo "📦 安装 oMLX..."
    
    if [[ -d "omlx" ]]; then
        echo "📂 oMLX 目录已存在，跳过克隆"
    else
        git clone https://github.com/jundot/omlx.git
    fi
    
    cd omlx
    pip3 install -e .
    
    echo "✅ oMLX 安装完成"
}

# 创建配置文件
create_config() {
    echo "⚙️  创建配置文件..."
    
    # 创建 oMLX 配置目录
    mkdir -p ~/.omlx
    
    # 创建简单的配置文件
    cat > ~/.omlx/config.toml << CONFIG_EOF
[server]
host = "127.0.0.1"
port = 8080
model = "qwen2.5-coder-7b-instruct-q4"
max_tokens = 1000
temperature = 0.1

[logging]
level = "INFO"
file = "~/.omlx/logs/omlx.log"
CONFIG_EOF
    
    echo "✅ 配置文件创建完成"
}

# 主安装流程
main() {
    echo "🎯 开始 oMLX 安装..."
    
    check_requirements
    install_omlx
    create_config
    
    echo ""
    echo "🎉 oMLX 安装完成!"
    echo ""
    echo "📋 使用方法:"
    echo "1. 启动应用: npm start"
    echo "2. 或直接运行: ./scripts/dev.sh"
    echo ""
    echo "📖 更多信息请查看 README.md"
}

# 运行主函数
main "$@"
