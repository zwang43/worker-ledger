#!/bin/bash

# 检查oMLX服务状态

echo "🔍 检查oMLX服务状态..."

# 检查oMLX服务
if curl -s http://127.0.0.1:8080/health > /dev/null; then
    echo "✅ oMLX服务运行正常"
else
    echo "❌ oMLX服务未运行"
fi

# 检查桥接服务
if curl -s http://127.0.0.1:8899/health > /dev/null; then
    echo "✅ 桥接服务运行正常"
else
    echo "❌ 桥接服务未运行"
fi

# 检查模型文件
if [[ -d "~/.omlx/models" ]]; then
    echo "✅ 模型文件存在"
    ls -la ~/.omlx/models/ | head -5
else
    echo "❌ 模型文件不存在"
fi
