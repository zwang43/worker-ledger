#!/usr/bin/env python3
"""
oMLX桥接服务
用于连接记账应用和oMLX AI服务
"""

import json
import logging
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import requests
import toml
import os
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('omlx-bridge.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class OMLXBridgeHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # 加载配置
        self.config = self.load_config()
        super().__init__(*args, **kwargs)
    
    def load_config(self):
        """加载配置文件"""
        config_path = os.path.join(os.path.dirname(__file__), 'omlx-config.toml')
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                return toml.load(f)
        except FileNotFoundError:
            logger.error(f"配置文件未找到: {config_path}")
            return self.get_default_config()
        except Exception as e:
            logger.error(f"加载配置文件失败: {e}")
            return self.get_default_config()
    
    def get_default_config(self):
        """获取默认配置"""
        return {
            'bridge': {
                'host': '127.0.0.1',
                'port': 8899,
                'omlx_url': 'http://127.0.0.1:8080',
                'timeout': 30
            },
            'prompt': {
                'system': """你是一个专业的记账助手，专门帮助用户识别和记录支出信息。
请从用户的自然语言描述中提取以下信息：
1. 金额（数字）
2. 分类（如：吃饭、交通、购物、娱乐、医疗、教育等）
3. 日期（如果没有明确说明，使用今天）
4. 描述（详细说明）

请以JSON格式返回，包含以下字段：
- action: "add"（添加支出）
- amount: 数字（金额）
- category: 字符串（分类）
- date: 字符串（日期，格式：YYYY-MM-DD）
- description: 字符串（描述）

示例：
输入："今天午餐花了35元，包括一杯咖啡和一份便当"
输出：
{
  "action": "add",
  "amount": 35,
  "category": "吃饭",
  "date": "2026-08-31",
  "description": "午餐，包括一杯咖啡和一份便当"
}"""
            }
        }
    
    def do_GET(self):
        """处理GET请求"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/health':
            self.send_health_check()
        else:
            self.send_error(404, f"未找到路径: {path}")
    
    def do_POST(self):
        """处理POST请求"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/parse':
            self.handle_parse()
        else:
            self.send_error(404, f"未找到路径: {path}")
    
    def send_health_check(self):
        """健康检查"""
        try:
            # 检查oMLX服务是否可用
            omlx_url = self.config['bridge']['omlx_url']
            response = requests.get(f"{omlx_url}/health", timeout=5)
            
            if response.status_code == 200:
                self.send_json_response({
                    'status': 'ok',
                    'message': 'oMLX服务正常',
                    'timestamp': datetime.now().isoformat()
                })
            else:
                self.send_json_response({
                    'status': 'error',
                    'message': 'oMLX服务异常',
                    'timestamp': datetime.now().isoformat()
                }, 500)
        except Exception as e:
            logger.error(f"健康检查失败: {e}")
            self.send_json_response({
                'status': 'error',
                'message': f'无法连接到oMLX服务: {str(e)}',
                'timestamp': datetime.now().isoformat()
            }, 500)
    
    def handle_parse(self):
        """处理文本解析请求"""
        try:
            # 读取请求体
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # 解析JSON
            data = json.loads(post_data.decode('utf-8'))
            text = data.get('text', '')
            
            if not text:
                self.send_json_response({
                    'status': 'error',
                    'message': '文本内容不能为空'
                }, 400)
                return
            
            logger.info(f"解析文本: {text}")
            
            # 调用oMLX服务
            result = self.call_omlx_service(text)
            
            self.send_json_response({
                'status': 'success',
                'result': result,
                'timestamp': datetime.now().isoformat()
            })
            
        except json.JSONDecodeError:
            self.send_json_response({
                'status': 'error',
                'message': '无效的JSON格式'
            }, 400)
        except Exception as e:
            logger.error(f"解析请求失败: {e}")
            self.send_json_response({
                'status': 'error',
                'message': f'解析失败: {str(e)}'
            }, 500)
    
    def call_omlx_service(self, text):
        """调用oMLX服务"""
        try:
            omlx_url = self.config['bridge']['omlx_url']
            prompt = self.config['prompt']['system']
            
            # 构建请求
            request_data = {
                'model': self.config.get('server', {}).get('model', 'qwen2.5-coder-7b-instruct-q4'),
                'messages': [
                    {'role': 'system', 'content': prompt},
                    {'role': 'user', 'content': text}
                ],
                'max_tokens': self.config.get('server', {}).get('max_tokens', 1000),
                'temperature': self.config.get('server', {}).get('temperature', 0.1)
            }
            
            # 发送请求到oMLX
            response = requests.post(
                f"{omlx_url}/v1/chat/completions",
                json=request_data,
                timeout=self.config['bridge']['timeout']
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                
                # 尝试解析JSON响应
                try:
                    return json.loads(content)
                except json.JSONDecodeError:
                    # 如果不是JSON格式，尝试提取信息
                    return self.extract_info_from_text(content, text)
            else:
                logger.error(f"oMLX服务返回错误: {response.status_code}")
                return {
                    'action': 'error',
                    'message': f'oMLX服务错误: {response.status_code}'
                }
                
        except Exception as e:
            logger.error(f"调用oMLX服务失败: {e}")
            return {
                'action': 'error',
                'message': f'AI服务错误: {str(e)}'
            }
    
    def extract_info_from_text(self, content, original_text):
        """从文本中提取信息（备用方案）"""
        # 简单的信息提取逻辑
        import re
        
        # 提取金额
        amount_match = re.search(r'(\d+(?:\.\d{1,2})?)', original_text)
        amount = float(amount_match.group(1)) if amount_match else 0
        
        # 提取分类（简单匹配）
        categories = ['吃饭', '交通', '购物', '娱乐', '医疗', '教育', '住房', '其他']
        category = '其他'
        for cat in categories:
            if cat in original_text:
                category = cat
                break
        
        # 提取日期
        import datetime
        date = datetime.datetime.now().strftime('%Y-%m-%d')
        
        return {
            'action': 'add',
            'amount': amount,
            'category': category,
            'date': date,
            'description': original_text
        }
    
    def send_json_response(self, data, status_code=200):
        """发送JSON响应"""
        response = json.dumps(data, ensure_ascii=False, indent=2)
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))
    
    def log_message(self, format, *args):
        """自定义日志消息"""
        logger.info(f"{self.address_string()} - {format % args}")

def main():
    """主函数"""
    config = OMLXBridgeHandler('').load_config()
    bridge_config = config['bridge']
    
    server_address = (bridge_config['host'], bridge_config['port'])
    httpd = HTTPServer(server_address, OMLXBridgeHandler)
    
    logger.info(f"oMLX桥接服务启动在 {bridge_config['host']}:{bridge_config['port']}")
    logger.info(f"oMLX服务地址: {bridge_config['omlx_url']}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("服务正在关闭...")
        httpd.server_close()

if __name__ == '__main__':
    main()
