#!/bin/bash
# ==========================================================
#  启动 AI 记账桥接服务 (打工人小账本 ↔ oMLX 微调模型)
#  双击运行即可, 保持窗口开启; Ctrl+C 或关窗口停止。
# ==========================================================
cd "$(dirname "$0")" || exit 1

# 1) 检查 oMLX 与微调模型是否就绪(只提示, 不阻塞)
KEY=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.omlx/settings.json'))).get('auth',{}).get('api_key',''))" 2>/dev/null)
MODELS=$(curl -s -m 5 -H "Authorization: Bearer $KEY" http://127.0.0.1:8000/v1/models 2>/dev/null)
if echo "$MODELS" | grep -q "Qwen3.5-4B-expense-MLX-4bit"; then
  echo "[OK] oMLX 已就绪, 微调模型在线"
else
  echo "[!!] 未检测到微调模型 Qwen3.5-4B-expense-MLX-4bit"
  echo "     请先打开 oMLX 加载该模型, 再重新运行本脚本"
  echo "     (模型离线时, 工作台的 AI 记账框会提示「本地 AI 未启动」)"
fi

echo ""
echo "启动桥接服务 http://127.0.0.1:8899 ..."
echo "----------------------------------------------"
python3 ai_bridge.py
