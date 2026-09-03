#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI桥接服务测试脚本
模拟ai_bridge.py的核心功能
"""

import json
import re
from datetime import datetime, timedelta

class MockAIBridge:
    def __init__(self):
        self.port = 8899
        self.model = "Qwen3.5-4B-expense-MLX-4bit"
        self.online = True
        self.loaded = True
        
        # 相对日期解析规则
        self.relative_date_rules = [
            (re.compile(r"大前天"), 3),
            (re.compile(r"前天"), 2),
            (re.compile(r"昨天|昨晚"), 1),
            (re.compile(r"今天|今晚|今早|今日|早上|上午|中午|下午|晚上"), 0),
        ]
    
    def _resolve_relative_date(self, text, today=None):
        """解析相对日期（确定性，不依赖模型）"""
        today = today or datetime.now().date()
        for pattern, offset in self.relative_date_rules:
            if pattern.search(text):
                return (today - timedelta(days=offset)).isoformat()
        return None
    
    def _fixup_records(self, original_text, recs):
        """模型输出后处理: 相对日期确定性覆盖"""
        fixed_date = self._resolve_relative_date(original_text)
        for r in recs:
            if not isinstance(r, dict):
                continue
            if fixed_date:
                r["date"] = fixed_date
        return recs
    
    def bookkeep(self, text, think=True):
        """解析口语记账"""
        if not text or not text.strip():
            return None, "输入为空"
        
        # 模拟解析结果
        today = datetime.now().strftime("%Y-%m-%d")
        resolved_date = self._resolve_relative_date(text)
        if resolved_date:
            today = resolved_date
        
        # 提取金额
        amount = 0
        amount_match = re.search(r'(\d+(?:\.\d+)?)', text)
        if amount_match:
            amount = float(amount_match.group(1))
        
        # 分类映射
        category_map = {
            '咖啡': '吃饭', '午餐': '吃饭', '吃饭': '吃饭', '餐厅': '吃饭',
            '打车': '交通', '地铁': '交通', '公交': '交通', '交通': '交通',
            '书': '购物', '购物': '购物', '买': '购物',
            '电影': '娱乐', '娱乐': '娱乐', '游戏': '娱乐'
        }
        
        # 确定分类
        category = "其他"
        for keyword, cat in category_map.items():
            if keyword in text:
                category = cat
                break
        
        # 生成描述
        description = text.replace(str(amount), '').strip()
        if category == "吃饭":
            description = "餐饮"
        elif category == "交通":
            description = "交通"
        elif category == "购物":
            description = "购物"
        elif category == "娱乐":
            description = "娱乐"
        else:
            description = "其他"
        
        records = [{
            "action": "add",
            "amount": amount,
            "category": category,
            "description": description,
            "date": today,
            "payment": "现金"
        }]
        
        return self._fixup_records(text, records), None
    
    def health_check(self):
        """健康检查"""
        return {
            "ok": True,
            "bridge": True,
            "online": self.online,
            "model": self.model,
            "loaded": self.loaded,
            "models": [self.model]
        }
    
    def parse_text(self, text, think=True):
        """解析文本"""
        if not text or not text.strip():
            return {"ok": False, "error": "输入为空"}
        
        recs, err = self.bookkeep(text, think=think)
        if err:
            return {"ok": False, "error": err}
        
        return {"ok": True, "records": recs}

def test_ai_bridge():
    """测试AI桥接服务"""
    print("=== AI桥接服务测试 ===")
    
    bridge = MockAIBridge()
    
    # 测试健康检查
    print("\n1. 健康检查")
    health = bridge.health_check()
    print(f"✓ 健康检查: {json.dumps(health, ensure_ascii=False, indent=2)}")
    
    # 测试文本解析
    print("\n2. 文本解析测试")
    test_cases = [
        "今天买咖啡花了25",
        "昨天打车花了35.5",
        "前天买书花了89",
        "今天午餐加咖啡32",
        "大前天看电影45",
        "无效输入",
        ""  # 空输入
    ]
    
    for i, text in enumerate(test_cases, 1):
        print(f"\n测试用例 {i}: '{text}'")
        result = bridge.parse_text(text)
        
        if result["ok"]:
            record = result["records"][0]
            print(f"✓ 解析成功: {record['amount']} {record['category']} {record['date']}")
        else:
            print(f"✗ 解析失败: {result['error']}")
    
    # 测试相对日期解析
    print("\n3. 相对日期解析测试")
    date_tests = [
        ("今天", datetime.now().strftime("%Y-%m-%d")),
        ("昨天", (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")),
        ("前天", (datetime.now() - timedelta(days=2)).strftime("%Y-%m-%d")),
        ("大前天", (datetime.now() - timedelta(days=3)).strftime("%Y-%m-%d")),
    ]
    
    for text, expected in date_tests:
        resolved = bridge._resolve_relative_date(text)
        status = "✓" if resolved == expected else "✗"
        print(f"{status} '{text}' -> {resolved} (期望: {expected})")
    
    # 测试分类映射
    print("\n4. 分类映射测试")
    category_tests = [
        ("买咖啡", "吃饭"),
        ("打车上班", "交通"),
        ("买书", "购物"),
        ("看电影", "娱乐"),
        ("交话费", "其他"),
    ]
    
    for text, expected in category_tests:
        # 模拟分类提取
        category = "其他"
        category_map = {
            '咖啡': '吃饭', '打车': '交通', '书': '购物', '电影': '娱乐'
        }
        for keyword, cat in category_map.items():
            if keyword in text:
                category = cat
                break
        
        status = "✓" if category == expected else "✗"
        print(f"{status} '{text}' -> {category} (期望: {expected})")
    
    print("\n=== AI桥接服务测试完成 ===")

if __name__ == "__main__":
    test_ai_bridge()
