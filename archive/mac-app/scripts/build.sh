#!/bin/bash

# Worker Ledger AI Mac App 构建脚本

set -e

echo "🚀 开始构建 Worker Ledger AI Mac 应用..."

# 检查必要工具
check_requirements() {
    echo "📋 检查构建要求..."
    
    if ! command -v node &> /dev/null; then
        echo "❌ 错误: 未找到 Node.js"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo "❌ 错误: 未找到 npm"
        exit 1
    fi
    
    echo "✅ 构建要求检查通过"
}

# 安装依赖
install_deps() {
    echo "📦 安装 Node.js 依赖..."
    npm install
    echo "✅ 依赖安装完成"
}

# 复制应用文件
copy_app_files() {
    echo "📁 复制应用文件..."
    
    # 复制记账应用文件
    if [[ -f "../../worker_ledger_local_enhanced.html" ]]; then
        cp "../../worker_ledger_local_enhanced.html" "src/"
        echo "✅ 记账应用文件已复制"
    else
        echo "⚠️  警告: 未找到 worker_ledger_local_enhanced.html 文件"
    fi
    
    # 复制其他资源文件
    if [[ -d "../../resources" ]]; then
        cp -r "../../resources/" "resources/"
        echo "✅ 资源文件已复制"
    fi
}

# 构建应用
build_app() {
    echo "🔨 构建应用..."
    
    # 清理之前的构建
    npm run clean
    
    # 构建应用
    npm run build
    
    echo "✅ 应用构建完成"
}

# 创建分发包
create_package() {
    echo "📦 创建分发包..."
    
    # 创建 DMG
    npm run build
    
    echo "✅ 分发包创建完成"
}

# 测试应用
test_app() {
    echo "🧪 测试应用..."
    
    # 检查构建产物
    if [[ -d "dist" ]]; then
        echo "✅ 构建产物存在"
        
        # 查找生成的 .app 文件
        app_file=$(find dist -name "*.app" -type d | head -1)
        if [[ -n "$app_file" ]]; then
            echo "✅ 找到应用文件: $app_file"
            
            # 检查应用包结构
            if [[ -f "$app_file/Contents/MacOS/Worker Ledger AI" ]]; then
                echo "✅ 应用可执行文件存在"
            else
                echo "❌ 应用可执行文件不存在"
            fi
        else
            echo "❌ 未找到 .app 文件"
        fi
    else
        echo "❌ 构建产物不存在"
    fi
}

# 显示结果
show_results() {
    echo ""
    echo "🎉 构建完成!"
    echo ""
    echo "📋 构建结果:"
    
    if [[ -d "dist" ]]; then
        echo "📁 构建目录: dist/"
        echo "📦 生成的文件:"
        find dist -name "*.dmg" -o -name "*.zip" | while read file; do
            echo "  - $file"
            echo "  大小: $(du -h "$file" | cut -f1)"
        done
    fi
    
    echo ""
    echo "🚀 使用方法:"
    echo "1. 打开 Finder"
    echo "2. 进入 dist/ 目录"
    echo "3. 双击 'Worker Ledger AI.app' 启动应用"
    echo ""
    echo "📖 更多信息请查看 README.md"
}

# 主函数
main() {
    echo "🎯 开始 Worker Ledger AI Mac 应用构建..."
    
    check_requirements
    install_deps
    copy_app_files
    build_app
    test_app
    show_results
}

# 运行主函数
main "$@"
