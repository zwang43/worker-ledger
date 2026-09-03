#!/bin/bash

# 月度报告功能启动脚本
# 用于快速启动和配置月度报告功能

echo "正在启动月度报告功能..."

# 检查必要的文件是否存在
required_files=("monthly_report_generator.js" "worker_ledger.html" "monthly_report_config.json")

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "错误: 缺少必要的文件 $file"
        exit 1
    fi
done

# 检查浏览器是否打开
if pgrep -f "worker_ledger.html" > /dev/null; then
    echo "检测到记账工作台已在运行..."
else
    echo "正在打开记账工作台..."
    # 尝试在默认浏览器中打开HTML文件
    if command -v open >/dev/null 2>&1; then
        open "worker_ledger.html"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "worker_ledger.html"
    else
        echo "请手动打开 worker_ledger.html 文件"
    fi
fi

echo "月度报告功能已启动！"
echo ""
echo "使用说明："
echo "1. 在浏览器中打开记账工作台"
echo "2. 点击导航栏中的'报告配置'按钮进行设置"
echo "3. 点击'生成月度报告'手动生成报告"
echo "4. 点击'历史报告'查看已生成的报告"
echo ""
echo "功能特性："
echo "- 每月自动生成账单报告"
echo "- 支持手动生成指定月份报告"
echo "- 详细的财务分析和建议"
echo "- 历史报告管理和下载"
echo "- 灵活的配置选项"

# 等待用户确认
read -p "按 Enter 键继续..."
