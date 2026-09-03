#!/usr/bin/env python3
"""
oMLX桥接服务 - Mac应用版本
用于连接记账应用和oMLX AI服务
"""

import json
import logging
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import time

# 简化版本，仅提供基本功能
class SimpleBridgeHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_json_response({'status': 'ok', 'message': 'Bridge service running'})
        else:
            self.send_error(404)
    
    def do_POST(self):
        if self.path == '/parse':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))
                text = data.get('text', '')
                
                # 简单的文本解析
                result = {
                    'action': 'add',
                    'amount': self.extract_amount(text),
                    'category': self.extract_category(text),
                    'date': '2026-08-31',
                    'description': text
                }
                
                self.send_json_response({'status': 'success', 'result': result})
            except Exception as e:
                self.send_json_response({'status': 'error', 'message': str(e)}, 500)
        else:
            self.send_error(404)
    
    def extract_amount(self, text):
        import re
        match = re.search(r'(\d+(?:\.\d{1,2})?)', text)
        return float(match.group(1)) if match else 0
    
    def extract_category(self, text):
        categories = ['吃饭', '交通', '购物', '娱乐', '医疗', '教育', '住房', '其他']
        for cat in categories:
            if cat in text:
                return cat
        return '其他'
    
    def send_json_response(self, data, status_code=200):
        response = json.dumps(data, ensure_ascii=False)
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))

def main():
    host = '127.0.0.1'
    port = 8899
    
    server = HTTPServer((host, port), SimpleBridgeHandler)
    print(f"Bridge service running on {host}:{port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down bridge service...")
        server.server_close()

if __name__ == '__main__':
    main()
