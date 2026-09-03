#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
omlx_expense_bridge.py — 用本地 oMLX 微调模型做「中文口语记账 → 结构化 JSON」解析。

模型: Qwen3.5-4B-expense-MLX-4bit (本机 oMLX 加载, 监听 http://127.0.0.1:8000)
实测: 8 条标准用例严格 6/8 (与 9B 基线一致), 体积仅 2.9GB, Mac 本地流畅。

为什么单独写这个桥而不是复用 ollama_bridge:
  - 微调模型用「训练时一致的压缩版 system prompt」(见 train_prompt.TRAIN_SYSTEM_PROMPT),
    不能用生产 bridge 的长提示词, 否则推理/训练不一致会掉点。
  - 微调模型在「思考模式开启」时解析最准, 这里默认 think=True。

用法:
    from omlx_expense_bridge import bookkeep
    recs = bookkeep("今天买咖啡花了25，微信支付")
    # -> [{"action":"add","amount":25.0,"category":"餐饮",
    #      "description":"咖啡","date":"2026-08-28","payment":"微信"}]

依赖: 仅标准库。system prompt 优先从 lora/train_prompt.py 导入(与训练一致),
       缺失时回退到内嵌副本。

记账 -> 备忘录同步(单向, 方案B):
    apply_to_tracker("今天买咖啡25微信", sync_notes=True)
    写入成功后自动刷新「全部账单」+ 当笔所属月份的「YYYY-MM 汇总」笔记;
    sync_full=True 时全量刷新所有月份。失败仅提示, 不影响记账。
    命令行: python3 omlx_expense_bridge.py "..."  (默认=解析+写入账本+同步备忘录;
             --parse-only 只解析; --no-sync 不同步备忘录; --no-think 关思考)
"""
import os
import re
import json
import sys

OMLX_BASE = os.environ.get("OMLX_BASE", "http://127.0.0.1:8000/v1")
EXPENSE_MODEL = os.environ.get("EXPENSE_MODEL", "Qwen3.5-4B-expense-MLX-4bit")

# ---- system prompt 档案 ----
# finetune-compressed: 与微调训练一致 (lora/train_prompt.py), 微调模型必须用它
_TRAIN_PROMPT = (
    "你是记账助手。今天【今天】(【星期】)。用户口语描述消费, 你只输出 JSON 指令, 多笔分行。\n"
    "格式: {\"action\":\"add\",\"amount\":25.0,\"category\":\"餐饮\",\"description\":\"咖啡\","
    "\"date\":\"【今天】\",\"payment\":\"微信\"}\n"
    "分类只选: 餐饮,交通,购物,房租/水电,通讯/网络,娱乐,医疗,教育,旅行,人情,工作,宠物,健身,美妆,"
    "快递/物流,投资,储蓄,收入,其他 (无法判断用\"其他\")\n"
    "规则: amount 取原句数字, 模糊如\"一百出头\"≈105/\"两块五\"=2.5 取近似; description 留消费对象不带金额; "
    "date 默认【今天】, 相对日期以【今天】和【上周五】推算; AA/分摊记自己那份; 多笔分行不合并; "
    "查账→{\"action\":\"summary\"} 或 {\"action\":\"stats\"}。只输出JSON。\n"
)

# generic-full: 未微调的通用模型用, 同一 JSON 契约但规则展开更细
_GENERIC_PROMPT = (
    "你是记账助手。今天是【今天】（【星期】），上周五是【上周五】。用户用中文口语描述消费或查询，"
    "你只输出 JSON 指令，每笔一行，不要输出任何其他文字。\n"
    "记账格式: {\"action\":\"add\",\"amount\":25.0,\"category\":\"餐饮\",\"description\":\"咖啡\","
    "\"date\":\"【今天】\",\"payment\":\"微信\"}\n"
    "分类只选: 餐饮,交通,购物,房租/水电,通讯/网络,娱乐,医疗,教育,旅行,人情,工作,宠物,健身,美妆,"
    "快递/物流,投资,储蓄,收入,其他（无法判断用\"其他\"）\n"
    "规则:\n"
    "1. amount 取原句数字；模糊金额取近似值，如\"一百出头\"≈105、\"两块五\"=2.5\n"
    "2. description 只写消费对象，不带金额\n"
    "3. date 默认【今天】；\"昨天/前天/大前天/上周五\"等相对日期按【今天】推算；明文日期如\"8月30号\"转成 YYYY-MM-DD\n"
    "4. AA/分摊只记自己那份\n"
    "5. 一句话多笔消费拆成多行 JSON，不合并\n"
    "6. 查账/统计请求输出 {\"action\":\"summary\"} 或 {\"action\":\"stats\"}，不要编造数字\n"
    "7. 工资/红包/退款等收入 category 填\"收入\"\n"
    "只输出 JSON。"
)

PROMPT_PROFILES = {
    "finetune-compressed": _TRAIN_PROMPT,
    "generic-full": _GENERIC_PROMPT,
}


def _fill_placeholders(text, now):
    week = "一二三四五六日"[now.weekday()]
    last_friday = now - timedelta(days=7) + timedelta(days=(4 - now.weekday()) % 7)
    return (text
            .replace("【今天】", now.strftime("%Y-%m-%d"))
            .replace("【星期】", f"星期{week}")
            .replace("【上周五】", last_friday.strftime("%Y-%m-%d")))


def build_system_prompt(now=None, profile="finetune-compressed"):
    """按档案生成 system prompt 并注入真实日期（占位符与训练一致）"""
    now = now or datetime.now()
    template = PROMPT_PROFILES.get(profile, _TRAIN_PROMPT)
    if template is _TRAIN_PROMPT:
        # 微调档案优先用训练脚本原版（保证完全一致），失败回退内嵌
        try:
            return _build_train(now)
        except Exception:
            pass
    return _fill_placeholders(template, now)


# 优先用训练脚本里的原版(保证完全一致), 失败则回退内嵌
try:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lora"))
    from train_prompt import build_train_system_prompt as _build_train  # noqa
except Exception:
    _build_train = None  # 回退内嵌
    from datetime import datetime, timedelta  # noqa
else:
    from datetime import datetime, timedelta  # noqa



def _api_key():
    """API key 优先级: EXPENSE_API_KEY/OMLX_API_KEY 环境变量 > 自动读 ~/.omlx/settings.json"""
    for env in ("EXPENSE_API_KEY", "OMLX_API_KEY"):
        k = os.environ.get(env, "").strip()
        if k:
            return k
    try:
        with open(os.path.expanduser("~/.omlx/settings.json")) as f:
            return json.load(f).get("auth", {}).get("api_key", "ollama")
    except Exception:
        return "ollama"


def _parse_output_all(text):
    """从模型输出提取所有合法 JSON 对象; 容忍 md 代码块/思考文本/多余内容"""
    text = (text or "").strip()
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if m:
        text = m.group(1).strip()
    # 去 <think>...</think>
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()
    dec = json.JSONDecoder()
    out, i = [], 0
    while i < len(text):
        if text[i] == "{":
            try:
                obj, end = dec.raw_decode(text[i:])
                if isinstance(obj, dict):
                    out.append(obj)
                i += end
                continue
            except Exception:
                pass
        i += 1
    return out


def bookkeep(text, think=True, model=None, endpoint=None, prompt_profile=None):
    """把一句口语记账解析成结构化 action 列表。

    text : 用户口语, 如 "今天买咖啡花了25，微信支付" / "昨天买菜30，前天打车15"
    think: 是否开启思考模式(微调模型默认开, 准确率最高)
    model: 覆盖默认模型 id（模型注册表切换入口）
    endpoint: 覆盖 oMLX 接口基址（默认 http://127.0.0.1:8000/v1）
    prompt_profile: prompt 档案, finetune-compressed(默认) / generic-full
    返回: [{"action":"add", ...}, ...]  (解析失败返回 [])
    """
    model = model or EXPENSE_MODEL
    base = (endpoint or OMLX_BASE).rstrip("/")
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": build_system_prompt(profile=prompt_profile or "finetune-compressed")},
            {"role": "user", "content": text},
        ],
        "stream": False,
        "temperature": 0.2,
        "max_tokens": int(os.environ.get("OMLX_MAX_TOKENS", "1024")),
    }
    # 微调模型按带思考模板训练, 关思考会明显掉点; 仅在显式 think=False 时关闭
    if not think:
        payload["chat_template_kwargs"] = {"enable_thinking": False}
    payload = json.dumps(payload).encode("utf-8")

    import urllib.request
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))  # 绕过系统代理, 直连本机
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + _api_key()})
    try:
        with opener.open(req, timeout=600 if think else 120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        msg = (data.get("choices") or [{}])[0].get("message", {})
        content = msg.get("content", "") or ""
        # 兼容 reasoning_content 字段
        if not content.strip():
            content = msg.get("reasoning_content", "") or ""
        return _parse_output_all(content)
    except Exception as e:
        print(f"[omlx_expense_bridge] 调用失败: {e}")
        return []


# ---------- 记账成功后自动同步到备忘录(单向: 账本 -> 备忘录) ----------
def sync_to_notes(full=False, months=None, verbose=True):
    """把最新记录同步到 macOS 备忘录(单向写入, 不从备忘录读回)。

    full=False: 刷新「全部账单」笔记(ledger) + months 指定的「YYYY-MM 汇总」笔记
                (months=None 时只刷全部账单; 传 ["2026-08"] 则连同该月汇总一起刷)
    full=True : 走 refresh(): 全部账单 + 全部有记录月份的汇总(全量)
    失败不影响记账主流程(备忘录自动化权限未授权时仅提示)。
    """
    try:
        import notes_bridge as nb
        if full:
            n, m = nb.refresh(months)
            msg = f"已同步到备忘录: 全部账单({n}笔) + {m} 个月度汇总"
        else:
            n = nb.ledger()
            extra = ""
            if months:
                m = nb.monthly_summary(months)
                extra = f" + {m} 个月度汇总"
            msg = f"已同步到备忘录: 全部账单({n}笔){extra}"
        if verbose:
            print(f"[omlx_expense_bridge] {msg}")
        return msg
    except Exception as e:
        err = f"⚠️ 同步备忘录失败(不影响记账): {e}"
        if verbose:
            print(f"[omlx_expense_bridge] {err}")
        return err


# ---------- 便捷: 直接把解析结果写进 expense_tracker.py ----------
def apply_to_tracker(text, tracker_script=None, think=True, sync_notes=True, sync_full=False,
                     cloud=True):
    """解析口语并调用 expense_tracker.py 写入(需按你实际 add 参数调整下方映射)。

    sync_notes : 写入成功后自动把最新记录同步到备忘录(单向写入, 不用模型读备忘录)
    sync_full  : False(默认)=全部账单 + 当笔所属月份的汇总; True=全量刷新(全部月份)
    cloud      : 写入本地账本后, 同时把记录入队到 cloud_sync 云端待同步队列
                 (离线安全、不阻塞; 之后由 WorkBuddy 跑 cloud_sync.py --flush 刷入资料库)
    返回: expense_tracker.py 的子进程输出 + 同步结果 + (可选)云端入队结果
    """
    recs = bookkeep(text, think=think)
    if not recs:
        return "⚠️ 未解析出记账内容"
    tracker_script = tracker_script or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "expense_tracker.py")
    from datetime import datetime as _dt
    results = []
    wrote = 0
    for r in recs:
        if r.get("action") != "add":
            continue
        # expense_tracker.py 的 add 是位置参数: add <金额> <分类> <描述|日期|支付…>
        # 剩余 token 由 CLI 自动识别(日期命中 YYYY-MM-DD / 支付命中 PAYMENT_WORDS / 其余作描述)
        amt = r.get("amount")
        if amt is None:
            results.append(f"⚠️ 跳过(缺金额): {json.dumps(r, ensure_ascii=False)}")
            continue
        args = ["add", str(amt), str(r.get("category", "其他"))]
        if r.get("description"):
            args.append(str(r.get("description")))
        d = r.get("date") or _dt.now().strftime("%Y-%m-%d")
        if d:
            args.append(str(d))
        if r.get("payment"):
            args.append(str(r.get("payment")))
        try:
            import subprocess
            rr = subprocess.run([sys.executable, tracker_script] + args,
                                capture_output=True, text=True, encoding="utf-8")
            out = (rr.stdout or rr.stderr or "").strip()
            results.append(out)
            if rr.returncode == 0:
                wrote += 1
        except Exception as e:
            results.append(f"⚠️ 写入失败: {e}")
    if sync_notes and wrote > 0:
        # 默认: 全部账单 + 当笔所属月份的汇总; sync_full=True 时全量刷新
        months = None
        if not sync_full:
            months = sorted({(r.get("date") or "")[:7] for r in recs
                             if r.get("action") == "add" and r.get("date")})
            months = months or None
        results.append(sync_to_notes(full=sync_full, months=months, verbose=False))
    if cloud and wrote > 0:
        # 终端记账 → 云端账本: 把解析结果入队到 cloud_sync 待同步队列(离线安全)
        try:
            import cloud_sync as _cs
            _n, _inc = _cs.enqueue(recs)
            results.append("已入队 %d 笔到云端待同步%s" % (
                _n, ("(收入 %d 笔请走月度总结)" % _inc) if _inc else ""))
        except Exception as e:
            results.append("⚠️ 云端入队失败(不影响本地记账): %s" % e)
    return "\n".join(results)


if __name__ == "__main__":
    import sys as _sys
    # CLI 参数: 默认 = 解析+写入账本+同步备忘录+入队云端(一站式)
    #   --parse-only 只解析不写入; --no-sync 写入但不同步备忘录; --no-think 关闭思考
    #   --no-cloud 写入但不入队云端(纯本地记账)
    argv = _sys.argv[1:]
    parse_only = "--parse-only" in argv
    sync = "--no-sync" not in argv
    cloud = "--no-cloud" not in argv
    argv = [a for a in argv if a not in ("--no-sync", "--parse-only", "--no-cloud")]
    think = "--no-think" not in argv
    argv = [a for a in argv if a not in ("--no-think",)]
    q = " ".join(argv) or "今天买咖啡花了25，微信支付"
    print("输入:", q)
    print("模型:", EXPENSE_MODEL, "| 思考:", think, "| 同步备忘录:", sync, "| 入队云端:", cloud)
    if parse_only:
        for rec in bookkeep(q, think=think):
            print("  →", json.dumps(rec, ensure_ascii=False))
    else:
        print(apply_to_tracker(q, think=think, sync_notes=sync, cloud=cloud))
