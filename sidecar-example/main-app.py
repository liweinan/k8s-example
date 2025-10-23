#!/usr/bin/env python3
"""
主应用容器 - 一个简单的 Web 服务器
这个容器提供核心业务功能，监听 8080 端口
"""

import http.server
import socketserver
import json
import time
import os
from datetime import datetime

class MainAppHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "service": "main-app",
                "message": "Hello from main application!",
                "timestamp": datetime.now().isoformat(),
                "pid": os.getpid()
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "status": "healthy",
                "service": "main-app",
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        else:
            self.send_response(404)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {"error": "Not found"}
            self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        # 将日志写入共享卷，供 sidecar 容器读取
        log_file = "/shared/logs/main-app.log"
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        with open(log_file, "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"[{timestamp}] {format % args}\n")

if __name__ == "__main__":
    PORT = 8080
    print(f"Main application starting on port {PORT}")
    
    with socketserver.TCPServer(("", PORT), MainAppHandler) as httpd:
        print(f"Main app server running at http://localhost:{PORT}")
        httpd.serve_forever()
