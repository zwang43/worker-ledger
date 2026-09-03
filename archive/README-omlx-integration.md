# oMLX + 记账工作台集成说明

## 📋 项目概述

本项目将oMLX（Apple Silicon优化的LLM推理服务器）与记账工作台应用集成，实现本地化的AI记账功能。

## 🚀 快速开始

### 1. 环境要求

- **硬件**: Apple Silicon Mac (M1/M2/M3等)
- **系统**: macOS 12.0+
- **Python**: 3.8+
- **内存**: 至少8GB RAM（推荐16GB+）
- **存储**: 至少5GB可用空间

### 2. 安装oMLX

```bash
# 克隆oMLX仓库
git clone https://github.com/jundot/omlx.git
cd omlx

# 安装依赖
pip install -e .

# 验证安装
omlx --version
```

### 3. 下载模型

```bash
# 下载Qwen2.5-Coder模型（推荐）
omlx download qwen2.5-coder-7b-instruct-q4

# 或者下载其他模型
omlx download codellama-7b-instruct-q4
omlx download mistral-7b-instruct-v0.2-q4
```

### 4. 启动服务

```bash
# 1. 启动oMLX服务器
omlx serve --host 127.0.0.1 --port 8080

# 2. 在另一个终端启动桥接服务
cd /Users/zhengwang/Desktop/记账工作台融合档案_20260831
python omlx-bridge.py

# 3. 打开记账应用
open worker_ledger_local_enhanced.html
```

## 🔧 配置说明

### oMLX配置文件 (`omlx-config.toml`)

```toml
[server]
host = "127.0.0.1"
port = 8080
model = "qwen2.5-coder-7b-instruct-q4"
max_tokens = 1000
temperature = 0.1

[bridge]
host = "127.0.0.1"
port = 8899
omlx_url = "http://127.0.0.1:8080"
timeout = 30
```

### 桥接服务配置

桥接服务 (`omlx-bridge.py`) 负责：
- 接收记账应用的AI请求
- 调用oMLX API
- 解析并格式化响应
- 提供健康检查接口

## 📡 API接口

### 健康检查
```
GET http://127.0.0.1:8899/health
```

### 文本解析
```
POST http://127.0.0.1:8899/parse
Content-Type: application/json

{
  "text": "今天午餐花了35元，包括一杯咖啡和一份便当"
}
```

### 响应格式
```json
{
  "status": "success",
  "result": {
    "action": "add",
    "amount": 35,
    "category": "吃饭",
    "date": "2026-08-31",
    "description": "午餐，包括一杯咖啡和一份便当"
  },
  "timestamp": "2026-08-31T10:30:00.000Z"
}
```

## 🛠️ 故障排除

### 1. oMLX服务无法启动

```bash
# 检查端口是否被占用
lsof -i :8080

# 检查模型文件是否存在
ls -la ~/.omlx/models/

# 重新下载模型
omlx download qwen2.5-coder-7b-instruct-q4
```

### 2. 桥接服务连接失败

```bash
# 检查oMLX服务状态
curl http://127.0.0.1:8080/health

# 检查桥接服务日志
tail -f omlx-bridge.log
```

### 3. AI识别不准确

- 检查提示词配置
- 尝试不同的模型
- 调整temperature参数
- 查看日志了解详细错误

### 4. 内存不足

```bash
# 使用较小的模型
omlx download qwen2.5-coder-1.5b-instruct-q4

# 减少max_tokens
max_tokens = 500
```

## 📊 性能优化

### 1. 模型选择

| 模型 | 大小 | 推理速度 | 准确率 | 适用场景 |
|------|------|----------|--------|----------|
| qwen2.5-coder-7b | 4.1GB | 中等 | 高 | 推荐 |
| qwen2.5-coder-1.5b | 1.2GB | 快 | 中 | 快速响应 |
| mistral-7b | 4.3GB | 中等 | 高 | 英文场景 |
| codellama-7b | 4.2GB | 中等 | 中 | 代码场景 |

### 2. 参数调优

```toml
[server]
# 更快的响应
temperature = 0.1
max_tokens = 500

# 更准确的响应
temperature = 0.3
max_tokens = 1000
```

## 🔒 安全考虑

1. **本地部署**: 所有AI处理都在本地完成
2. **数据隐私**: 支出数据不离开本地设备
3. **网络隔离**: 桥接服务仅允许本地访问
4. **模型安全**: 使用可信的开源模型

## 📈 监控和日志

### 日志文件
- omlx-bridge.log: 桥接服务日志
- ~/.omlx/logs/: oMLX服务日志

### 监控指标
- 响应时间
- 请求成功率
- 内存使用情况
- 模型加载状态

## 🔄 更新和维护

### 更新oMLX
```bash
cd omlx
git pull
pip install -e .
```

### 更新桥接服务
```bash
# 重新启动服务
pkill -f omlx-bridge.py
python omlx-bridge.py
```

## 📞 技术支持

### 常见问题
1. **模型下载失败**: 检查网络连接和磁盘空间
2. **服务启动失败**: 检查端口占用和权限
3. **AI识别失败**: 检查提示词和模型配置
4. **性能问题**: 尝试使用更小的模型

### 获取帮助
- 查看 oMLX 官方文档: https://github.com/jundot/omlx
- 提交问题到项目仓库
- 查看日志文件排查问题

---

🎉 **祝您使用愉快！**
