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
