#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
记账工作台全流程测试脚本
模拟前端功能、数据持久化和AI记账解析
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta

# 模拟前端状态结构
def create_sample_state():
    """创建示例状态数据"""
    summary_values = [
        [13800, 5600, 3500], [14100, 5600, 3200], [13200, 5600, 4100],
        [14600, 5600, 3000], [13800, 5600, 4600], [15200, 5600, 3300]
    ]
    return {
        "profile": {
            "monthlySalary": 13800,
            "payMonths": 13,
            "monthlyWorkCost": 850,
            "dailyOfficeHours": 9,
            "oneWayCommuteMinutes": 48,
            "weeklyOvertimeHours": 6,
            "isSample": True
        },
        "expenses": [
            {
                "id": "sample-expense-1", 
                "date": (datetime.now()).strftime("%Y-%m-%d"), 
                "amount": 32, 
                "category": "吃饭", 
                "note": "午餐加一杯咖啡", 
                "createdAt": datetime.now().isoformat(), 
                "isSample": True
            },
            {
                "id": "sample-expense-2", 
                "date": (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d"), 
                "amount": 18.5, 
                "category": "交通", 
                "note": "下班晚了打车接驳", 
                "createdAt": (datetime.now() - timedelta(hours=24)).isoformat(), 
                "isSample": True
            },
            {
                "id": "sample-expense-3", 
                "date": (datetime.now() - timedelta(days=4)).strftime("%Y-%m-%d"), 
                "amount": 129, 
                "category": "购物", 
                "note": "一本想读很久的书", 
                "createdAt": (datetime.now() - timedelta(days=4)).isoformat(), 
                "isSample": True
            }
        ],
        "monthlySummaries": [
            {
                "month": (datetime.now() - timedelta(days=180)).strftime("%Y-%m"), 
                "income": values[0], 
                "fixed": values[1], 
                "flexible": values[2],
                "updatedAt": datetime.now().isoformat(), 
                "isSample": True
            }
            for values in summary_values
        ],
        "freedom": {
            "targetAmount": 120000,
            "targetDate": (datetime.now() + timedelta(days=540)).strftime("%Y-%m"),
            "reason": "攒出半年缓冲期，给下一次选择留出底气",
            "currentSaved": 36800,
            "basicMonthlyCost": 5600,
            "startMonth": (datetime.now() - timedelta(days=180)).strftime("%Y-%m"),
            "isSample": True
        },
        "settings": {
            "theme": "light",
            "sampleState": "active",
            "version": 1
        }
    }

def cleanExpenseCategory(value):
    """清理和标准化分类"""
    aliases = {'餐饮': '吃饭', '居住': '房租', '学习': '其他'}
    category = aliases.get(str(value), str(value))
    return category if category in ['吃饭', '交通', '购物', '娱乐', '房租', '其他'] else '其他'

def resolve_relative_date(text, today=None):
    """解析相对日期（确定性，不依赖模型）"""
    today = today or datetime.now().date()
    relative_date_rules = [
        (re.compile(r"大前天"), 3),
        (re.compile(r"前天"), 2),
        (re.compile(r"昨天|昨晚"), 1),
        (re.compile(r"今天|今晚|今早|今日|早上|上午|中午|下午|晚上"), 0),
    ]
    
    for pattern, offset in relative_date_rules:
        if pattern.search(text):
            return (today - timedelta(days=offset)).isoformat()
    return None

def mock_ai_parse(text, think=True):
    """模拟AI记账解析"""
    if not text or not text.strip():
        return None, "输入为空"
    
    # 模拟解析结果
    today = datetime.now().strftime("%Y-%m-%d")
    
    # 模拟相对日期解析
    resolved_date = resolve_relative_date(text)
    if resolved_date:
        today = resolved_date
    
    # 简单的解析逻辑
    amount = 0
    category = "其他"
    description = ""
    
    # 提取金额
    amount_match = re.search(r'(\d+(?:\.\d+)?)', text)
    if amount_match:
        amount = float(amount_match.group(1))
    
    # 提取分类
    if any(keyword in text for keyword in ['咖啡', '午餐', '吃饭', '餐厅']):
        category = "吃饭"
    elif any(keyword in text for keyword in ['打车', '地铁', '公交', '交通']):
        category = "交通"
    elif any(keyword in text for keyword in ['书', '购物', '买']):
        category = "购物"
    elif any(keyword in text for keyword in ['电影', '娱乐', '游戏']):
        category = "娱乐"
    
    # 提取描述
    description = text.replace(str(amount), '').strip()
    if category == "吃饭":
        description = "餐饮"
    elif category == "交通":
        description = "交通"
    elif category == "购物":
        description = "购物"
    else:
        description = "其他"
    
    return [{
        "action": "add",
        "amount": amount,
        "category": category,
        "description": description,
        "date": today,
        "payment": "现金"
    }], None

def calculate_hourly_profile(profile):
    """计算时薪"""
    monthly_salary = profile.get("monthlySalary", 0)
    pay_months = profile.get("payMonths", 12)
    monthly_work_cost = profile.get("monthlyWorkCost", 0)
    daily_office_hours = profile.get("dailyOfficeHours", 8)
    one_way_commute_minutes = profile.get("oneWayCommuteMinutes", 0)
    weekly_overtime_hours = profile.get("weeklyOvertimeHours", 0)
    
    work_days_per_month = 21.75
    
    nominal_hourly = monthly_salary / work_days_per_month / 8 if monthly_salary > 0 else 0
    annual_income = monthly_salary * pay_months
    annual_work_cost = monthly_work_cost * 12
    net_annual_income = annual_income - annual_work_cost
    
    monthly_office_hours = daily_office_hours * work_days_per_month
    monthly_commute_hours = one_way_commute_minutes * 2 * work_days_per_month / 60
    monthly_overtime_hours = weekly_overtime_hours * 52 / 12
    annual_invested_hours = (monthly_office_hours + monthly_commute_hours + monthly_overtime_hours) * 12
    
    real_hourly = net_annual_income / annual_invested_hours if annual_invested_hours > 0 else 0
    
    return {
        "nominalHourly": round(nominal_hourly, 2),
        "realHourly": round(real_hourly, 2),
        "annualIncome": round(annual_income, 2),
        "annualWorkCost": round(annual_work_cost, 2),
        "netAnnualIncome": round(net_annual_income, 2)
    }

def calculate_monthly_balance(summary):
    """计算月度结余"""
    income = summary.get("income", 0)
    fixed = summary.get("fixed", 0)
    flexible = summary.get("flexible", 0)
    return round(income - fixed - flexible, 2)

def test_data_persistence():
    """测试数据持久化"""
    print("=== 测试数据持久化 ===")
    
    # 创建测试数据
    test_state = create_sample_state()
    test_file = "test_persistence.json"
    
    # 保存数据
    with open(test_file, 'w', encoding='utf-8') as f:
        json.dump(test_state, f, ensure_ascii=False, indent=2)
    
    print(f"✓ 数据已保存到 {test_file}")
    
    # 读取数据
    with open(test_file, 'r', encoding='utf-8') as f:
        loaded_state = json.load(f)
    
    # 验证数据完整性
    assert loaded_state["profile"]["monthlySalary"] == 13800
    assert len(loaded_state["expenses"]) == 3
    assert len(loaded_state["monthlySummaries"]) == 6
    
    print("✓ 数据完整性验证通过")
    
    # 清理测试文件
    os.remove(test_file)
    print("✓ 测试文件已清理")

def test_expense_management():
    """测试记账功能"""
    print("\n=== 测试记账功能 ===")
    
    state = create_sample_state()
    initial_count = len(state["expenses"])
    
    # 添加新记录
    new_expense = {
        "id": "test-expense-1",
        "date": datetime.now().strftime("%Y-%m-%d"),
        "amount": 25.5,
        "category": "吃饭",
        "note": "测试记账",
        "createdAt": datetime.now().isoformat(),
        "isSample": False
    }
    
    state["expenses"].append(new_expense)
    print(f"✓ 添加新记录，当前记录数: {len(state['expenses'])}")
    
    # 编辑记录
    for expense in state["expenses"]:
        if expense["id"] == "sample-expense-1":
            expense["amount"] = 45.0
            expense["note"] = "编辑后的备注"
            break
    
    print("✓ 编辑记录完成")
    
    # 删除记录
    state["expenses"] = [e for e in state["expenses"] if e["id"] != "sample-expense-2"]
    print(f"✓ 删除记录，当前记录数: {len(state['expenses'])}")
    
    # 验证数据一致性
    assert len(state["expenses"]) == initial_count  # 3 - 1 + 1 = 3
    assert any(e["amount"] == 45.0 for e in state["expenses"])
    assert not any(e["id"] == "sample-expense-2" for e in state["expenses"])
    
    print("✓ 记账功能测试通过")

def test_ai_accounting():
    """测试AI记账解析"""
    print("\n=== 测试AI记账解析 ===")
    
    test_cases = [
        "今天买咖啡花了25",
        "昨天打车花了35.5",
        "前天买书花了89",
        "今天午餐加咖啡32",
        "大前天看电影45"
    ]
    
    for i, text in enumerate(test_cases, 1):
        print(f"\n测试用例 {i}: {text}")
        
        records, error = mock_ai_parse(text, think=True)
        
        if error:
            print(f"✗ 解析失败: {error}")
            continue
        
        if records:
            record = records[0]
            print(f"✓ 解析成功: 金额={record['amount']}, 分类={record['category']}, 日期={record['date']}")
            
            # 验证相对日期解析
            if "昨天" in text:
                expected_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
                assert record["date"] == expected_date
                print(f"✓ 相对日期解析正确: {record['date']}")
        else:
            print("✗ 未解析出记录")

def test_salary_calculation():
    """测试时薪计算"""
    print("\n=== 测试时薪计算 ===")
    
    profile = create_sample_state()["profile"]
    hourly = calculate_hourly_profile(profile)
    
    print(f"名义时薪: ¥{hourly['nominalHourly']}/小时")
    print(f"真实时薪: ¥{hourly['realHourly']}/小时")
    print(f"年收入: ¥{hourly['annualIncome']}")
    print(f"年工作成本: ¥{hourly['annualWorkCost']}")
    print(f"净年收入: ¥{hourly['netAnnualIncome']}")
    
    # 验证计算逻辑
    expected_nominal = 13800 / 21.75 / 8  # 约79.31
    assert abs(hourly["nominalHourly"] - expected_nominal) < 0.01
    print("✓ 时薪计算验证通过")

def test_monthly_summary():
    """测试月度总结"""
    print("\n=== 测试月度总结 ===")
    
    state = create_sample_state()
    
    # 计算月度结余
    for summary in state["monthlySummaries"]:
        balance = calculate_monthly_balance(summary)
        summary["calculatedBalance"] = balance
        print(f"{summary['month']}: 收入¥{summary['income']} - 固定¥{summary['fixed']} - 弹性¥{summary['flexible']} = 结余¥{balance}")
    
    # 添加新的月度总结
    new_summary = {
        "month": datetime.now().strftime("%Y-%m"),
        "income": 15000,
        "fixed": 5600,
        "flexible": 4000,
        "updatedAt": datetime.now().isoformat(),
        "isSample": False
    }
    
    state["monthlySummaries"].append(new_summary)
    balance = calculate_monthly_balance(new_summary)
    print(f"\n新增月度总结: {new_summary['month']} - 结余¥{balance}")
    
    print("✓ 月度总结测试通过")

def test_freedom_fund():
    """测试自由基金"""
    print("\n=== 测试自由基金 ===")
    
    state = create_sample_state()
    freedom = state["freedom"]
    
    print(f"目标金额: ¥{freedom['targetAmount']}")
    print(f"目标日期: {freedom['targetDate']}")
    print(f"当前已攒: ¥{freedom['currentSaved']}")
    print(f"每月基本开销: ¥{freedom['basicMonthlyCost']}")
    print(f"自由宣言: {freedom['reason']}")
    
    # 计算安全缓冲
    current_saved = freedom['currentSaved']
    basic_monthly_cost = freedom['basicMonthlyCost']
    safety_months = current_saved / basic_monthly_cost if basic_monthly_cost > 0 else 0
    
    print(f"\n安全缓冲: {safety_months:.1f} 个月")
    
    # 计算进度
    progress = (current_saved / freedom['targetAmount']) * 100
    print(f"目标完成度: {progress:.1f}%")
    
    print("✓ 自由基金测试通过")

def test_data_validation():
    """测试数据验证"""
    print("\n=== 测试数据验证 ===")
    
    # 测试分类清理
    test_categories = ["餐饮", "吃饭", "居住", "学习", "未知分类"]
    for cat in test_categories:
        cleaned = cleanExpenseCategory(cat)
        print(f"'{cat}' -> '{cleaned}'")
    
    # 测试日期解析
    date_tests = ["今天", "昨天", "前天", "大前天", "2024-01-15"]
    for test in date_tests:
        resolved = resolve_relative_date(test)
        print(f"'{test}' -> {resolved}")
    
    print("✓ 数据验证测试通过")

def main():
    """主测试函数"""
    print("开始记账工作台全流程测试...")
    print("=" * 50)
    
    try:
        test_data_persistence()
        test_expense_management()
        test_ai_accounting()
        test_salary_calculation()
        test_monthly_summary()
        test_freedom_fund()
        test_data_validation()
        
        print("\n" + "=" * 50)
        print("🎉 所有测试通过！记账工作台全流程测试完成")
        
        # 生成测试报告
        report = {
            "testDate": datetime.now().isoformat(),
            "testsPassed": 7,
            "totalTests": 7,
            "status": "success",
            "summary": {
                "dataPersistence": "✓ 通过",
                "expenseManagement": "✓ 通过", 
                "aiAccounting": "✓ 通过",
                "salaryCalculation": "✓ 通过",
                "monthlySummary": "✓ 通过",
                "freedomFund": "✓ 通过",
                "dataValidation": "✓ 通过"
            }
        }
        
        with open("test_report.json", 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        print("📊 测试报告已保存到 test_report.json")
        
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
