#!/bin/bash

# oMLX + 记账工作台集成安装脚本

set -e

echo "🚀 开始安装oMLX + 记账工作台集成..."

# 检查系统要求
check_requirements() {
    echo "📋 检查系统要求..."
    
    # 检查是否为Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        echo "❌ 错误: 此脚本仅支持Apple Silicon Mac"
        exit 1
    fi
    
    # 检查Python版本
    if ! command -v python3 &> /dev/null; then
        echo "❌ 错误: 未找到Python3"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [[ "$python_version" < "3.8" ]]; then
        echo "❌ 错误: 需要Python 3.8或更高版本，当前版本: $python_version"
        exit 1
    fi
    
    echo "✅ 系统要求检查通过"
}

# 安装oMLX
install_omlx() {
    echo "📦 安装oMLX..."
    
    if [[ -d "omlx" ]]; then
        echo "📂 oMLX目录已存在，跳过克隆"
    else
        git clone https://github.com/jundot/omlx.git
    fi
    
    cd omlx
    pip install -e .
    
    echo "✅ oMLX安装完成"
}

# 创建启动脚本
create_scripts() {
    echo "📝 创建启动脚本..."
    
    cat > start-omlx.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "🚀 启动oMLX服务..."
cd omlx
omlx serve --host 127.0.0.1 --port 8080 &
OMLX_PID=$!

echo "🔗 启动桥接服务..."
cd ..
python omlx-bridge.py &
BRIDGE_PID=$!

echo "✅ 服务启动完成!"
echo "oMLX PID: $OMLX_PID"
echo "Bridge PID: $BRIDGE_PID"
echo ""
echo "📱 打开记账应用: open worker_ledger_local_enhanced.html"
echo ""
echo "🛑 停止服务: ./stop-omlx.sh"
SCRIPT_EOF

    cat > stop-omlx.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "🛑 停止服务..."
pkill -f "omlx serve"
pkill -f "omlx-bridge.py"
echo "✅ 服务已停止"
SCRIPT_EOF

    chmod +x start-omlx.sh
    chmod +x stop-omlx.sh
    echo "✅ 启动脚本创建完成"
}

# 主安装流程
main() {
    echo "🎯 开始oMLX + 记账工作台集成安装..."
    
    check_requirements
    install_omlx
    create_scripts
    
    echo ""
    echo "🎉 安装完成!"
    echo ""
    echo "📋 使用方法:"
    echo "1. 启动服务: ./start-omlx.sh"
    echo "2. 打开记账应用: open worker_ledger_local_enhanced.html"
    echo "3. 停止服务: ./stop-omlx.sh"
    echo ""
    echo "📖 详细文档请查看: README-omlx-integration.md"
}

# 运行主函数
main "$@"
