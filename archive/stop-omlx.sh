#!/bin/bash

echo "🛑 停止服务..."
pkill -f "omlx serve"
pkill -f "omlx-bridge.py"
echo "✅ 服务已停止"
