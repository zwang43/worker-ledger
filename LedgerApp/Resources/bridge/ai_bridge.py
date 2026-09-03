#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ai_bridge.py — 「打工人小账本」工作台 ↔ 本地 oMLX 微调模型的桥接服务。

职责单一: 只做「口语 → 结构化 JSON」解析, 不碰任何数据存储。
  工作台(浏览器) --POST /parse--> 本服务 --调 omlx_expense_bridge.bookkeep--> oMLX(:8000)
  工作台拿到 JSON 后自己走 pushExpense 写资料库云端。

为什么需要它:
  工作台部署在 HTTPS 域名(workbuddy.cn), 浏览器直接 fetch 本地 oMLX(:8000) 会被
  mixed content + CORS + Private Network Access(PNA) 三重拦截。
  本服务监听 127.0.0.1:8899, 返回完整的 CORS/PNA 头, 让 Mac 本机浏览器能直连。

启动:   python3 ai_bridge.py    (或双击「启动AI记账桥接.command」)
接口:
  GET  /health -> {"ok":true,"online":true,"model":"Qwen3.5-4B-expense-MLX-4bit"}
  POST /parse  body {"text":"昨天买菜30","think":true}
               -> {"ok":true,"records":[{"action":"add","amount":30.0,...}]}
               或 {"ok":false,"error":"..."}

依赖: 仅 Python 标准库 + 同目录 omlx_expense_bridge.py(也是标准库)。
日期策略: 模型推理时没有时钟, 无法可靠解析"今天/昨天"这类相对日期(其默认值来自训练期,
  换个日子连"今天"都会记错)。桥接层两步兜底:
  1) 调用前在口语前注入"（今天是YYYY年MM月DD日）", 给模型时钟上下文(辅助理解复杂表达);
  2) 返回后用系统时钟对命中相对时间词的记录确定性重算日期并覆盖(见 _resolve_relative_date)。
  明文日期(如"8月30号")不覆盖, 交由模型解析; 模型与权重不做任何改动。
环境变量:
  AI_BRIDGE_PORT  监听端口(默认 8899)
  OMLX_BASE       oMLX 接口基址(默认 http://127.0.0.1:8000/v1)
  OMLX_THINK      0=默认关思考(快但可能掉点), 1=默认开思考(准但慢)
"""
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

PORT = int(os.environ.get("AI_BRIDGE_PORT", "8899"))
OMLX_BASE = os.environ.get("OMLX_BASE", "http://127.0.0.1:8000/v1")

# 默认思考开关: 微调模型按带思考模板训练, 开思考最准; 关思考快约 10 倍
DEFAULT_THINK = os.environ.get("OMLX_THINK", "1") != "0"

# ---- 模型注册表（App 模式）----
# LEDGER_MODEL_REGISTRY 指向 model_registry.json; 每次请求时读取, 切换模型无需重启桥接。
# 无注册表时回退 env/默认值（CLI 模式完全兼容）。
def _load_registry():
    path = os.environ.get("LEDGER_MODEL_REGISTRY", "")
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("models"), list) and data["models"]:
            return data
    except Exception as e:
        sys.stderr.write("[ai_bridge] 模型注册表读取失败: %s\n" % e)
    return None


def _active_model():
    """返回当前激活模型配置: {name, endpoint, model, think, prompt_profile}"""
    reg = _load_registry()
    if reg:
        models = reg["models"]
        entry = next((m for m in models if m.get("id") == reg.get("active")), None) or models[0]
        return {
            "name": entry.get("name") or entry.get("modelId") or "未命名模型",
            "endpoint": (entry.get("endpoint") or OMLX_BASE).rstrip("/"),
            "model": entry.get("modelId") or getattr(bridge, "EXPENSE_MODEL", ""),
            "think": bool(entry.get("think", DEFAULT_THINK)),
            "prompt_profile": entry.get("promptProfile") or "finetune-compressed",
        }
    return {
        "name": getattr(bridge, "EXPENSE_MODEL", "?"),
        "endpoint": OMLX_BASE,
        "model": getattr(bridge, "EXPENSE_MODEL", ""),
        "think": DEFAULT_THINK,
        "prompt_profile": "finetune-compressed",
    }

try:
    import omlx_expense_bridge as bridge
    HAS_BRIDGE = True
except Exception as e:  # pragma: no cover
    bridge = None
    HAS_BRIDGE = False
    _IMPORT_ERR = str(e)


def _api_key():
    """复用 omlx_expense_bridge 的 key 读取逻辑, 失败回退默认值"""
    try:
        return bridge._api_key()
    except Exception:
        try:
            with open(os.path.expanduser("~/.omlx/settings.json")) as f:
                return json.load(f).get("auth", {}).get("api_key", "ollama")
        except Exception:
            return "ollama"


def _model_online(endpoint=None):
    """探测 oMLX 是否在线(以及已加载哪些模型)"""
    base = (endpoint or OMLX_BASE).rstrip("/")
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        req = urllib.request.Request(
            base + "/models",
            headers={"Authorization": "Bearer " + _api_key()})
        with opener.open(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        models = data.get("data", data if isinstance(data, list) else [])
        ids = [m.get("id", "") for m in models] if isinstance(models, list) else []
        return True, ids
    except Exception:
        return False, []


# ---- 相对日期兜底（确定性, 不依赖模型） ----
# 规则按顺序匹配, "大前天"必须先于"前天"（否则被"前天"截胡）;
# "昨天早上"会先命中"昨天"规则, 时段词(早上/中午/晚上)默认归"今天", 排在最后。
_RELATIVE_DATE_RULES = [
    (re.compile(r"大前天"), 3),
    (re.compile(r"前天"), 2),
    (re.compile(r"昨天|昨晚"), 1),
    (re.compile(r"今天|今晚|今早|今日|早上|上午|中午|下午|晚上"), 0),
]

_DATE_PREFIX_RE = re.compile(r"（今天是[^）]*）")
_ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_SEGMENT_SPLIT_RE = re.compile(r"[，,。;；、\s]+")


def _resolve_relative_date(text, today=None):
    """扫原始口语中的相对时间词, 用系统时钟算出确定日期; 无命中返回 None(不覆盖)。"""
    today = today or datetime.now().date()
    for pattern, offset in _RELATIVE_DATE_RULES:
        if pattern.search(text):
            return (today - timedelta(days=offset)).isoformat()
    return None


def _split_segments(text):
    """按常见分隔符把口语切成多个独立记账分句（逗号/空格/顿号/分号等）。"""
    return [s.strip() for s in _SEGMENT_SPLIT_RE.split(text or "") if s.strip()]


def _fixup_records(original_text, recs, force_date=False):
    """模型输出后处理:
    1) 该分句含相对时间词时, 用系统时钟算出的日期确定性覆盖本句所有记录;
       否则仅给缺日期/非法日期的记录补当天。
    2) 剥离模型可能回显的注入前缀。"""
    fallback_date = _resolve_relative_date(original_text)
    if fallback_date is None:
        fallback_date = datetime.now().date().isoformat()
    for r in recs:
        if not isinstance(r, dict):
            continue
        current = r.get("date")
        if force_date or not isinstance(current, str) or not _ISO_DATE_RE.match(current):
            r["date"] = fallback_date
        desc = r.get("description")
        if isinstance(desc, str) and "（今天是" in desc:
            cleaned = _DATE_PREFIX_RE.sub("", desc).strip()
            if cleaned:
                r["description"] = cleaned
    return recs


def _parse(text, think=None):
    if not HAS_BRIDGE:
        return None, "桥接模块加载失败: " + _IMPORT_ERR
    if not text or not text.strip():
        return None, "输入为空"
    cfg = _active_model()
    if think is None:
        think = cfg["think"]
    try:
        today_cn = datetime.now().strftime("%Y年%m月%d日")
        recs = []
        for segment in _split_segments(text):
            enriched = "（今天是%s）%s" % (today_cn, segment)
            segment_recs = bridge.bookkeep(
                enriched, think=think, model=cfg["model"],
                endpoint=cfg["endpoint"],
                prompt_profile=cfg["prompt_profile"])
            force = _resolve_relative_date(segment) is not None
            recs.extend(_fixup_records(segment, segment_recs, force_date=force))
    except Exception as e:
        return None, "解析异常: " + str(e)
    if not recs:
        # 解析为空: 可能是模型离线, 也可能真没听懂。离线时给出明确提示。
        online, _ = _model_online(cfg["endpoint"])
        if not online:
            return None, "本地模型离线，请先打开 oMLX 加载「%s」" % cfg["name"]
    return recs, None


class Handler(BaseHTTPRequestHandler):
    server_version = "ai-bridge/1.0"

    def _send_json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Access-Control-Max-Age", "86400")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/health"):
            cfg = _active_model()
            online, ids = _model_online(cfg["endpoint"])
            loaded = any(cfg["model"] in i for i in ids) if ids else False
            self._send_json(200, {
                "ok": True,
                "bridge": HAS_BRIDGE,
                "online": online,
                "model": cfg["model"],
                "active": cfg["name"],
                "promptProfile": cfg["prompt_profile"],
                "think": cfg["think"],
                "loaded": loaded,
                "models": ids,
            })
        else:
            self._send_json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if not self.path.startswith("/parse"):
            self._send_json(404, {"ok": False, "error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8")
            payload = json.loads(raw) if raw else {}
            text = payload.get("text", "")
            # think 未显式指定时由模型注册表决定（不同模型思考开关不同）
            think = payload.get("think")
        except Exception as e:
            self._send_json(400, {"ok": False, "error": "bad request: " + str(e)})
            return

        recs, err = _parse(text, think)
        if err:
            self._send_json(200, {"ok": False, "error": err})
            return
        self._send_json(200, {"ok": True, "records": recs})

    def log_message(self, fmt, *args):
        sys.stderr.write("[ai_bridge] %s\n" % (fmt % args))


def main():
    if not HAS_BRIDGE:
        print("⚠️ 未找到 omlx_expense_bridge.py, 请在本项目目录下运行。")
        print("  导入错误: %s" % _IMPORT_ERR)
        sys.exit(1)
    cfg = _active_model()
    online, ids = _model_online(cfg["endpoint"])
    print("=" * 52)
    print("  AI 记账桥接服务")
    print("  监听: http://127.0.0.1:%d" % PORT)
    print("  激活模型: %s (%s)" % (cfg["name"], cfg["model"]))
    print("  Prompt 档案: %s | 思考: %s" % (cfg["prompt_profile"], "开" if cfg["think"] else "关"))
    print("  oMLX 状态: %s" % ("在线" if online else "离线(请先打开 oMLX 加载模型)"))
    if ids:
        print("  已加载模型: %s" % ", ".join(ids))
    print("=" * 52)
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止。")
        srv.server_close()


if __name__ == "__main__":
    main()
