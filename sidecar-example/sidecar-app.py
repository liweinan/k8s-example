#!/usr/bin/env python3
"""
Sidecar 容器 - 日志收集和监控
这个容器负责收集主应用的日志，并提供监控功能
"""

import os
import time
import json
import http.server
import socketserver
from datetime import datetime
from pathlib import Path

class SidecarHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "service": "sidecar",
                "message": "Hello from sidecar container!",
                "timestamp": datetime.now().isoformat(),
                "pid": os.getpid()
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        elif self.path == '/logs':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            # 读取主应用的日志
            log_file = "/shared/logs/main-app.log"
            logs = []
            if os.path.exists(log_file):
                with open(log_file, "r") as f:
                    logs = f.readlines()[-10:]  # 获取最后10行日志
            
            response = {
                "service": "sidecar",
                "logs": [log.strip() for log in logs],
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        elif self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            # 模拟收集的指标
            metrics = {
                "service": "sidecar",
                "metrics": {
                    "log_lines_processed": get_log_count(),
                    "uptime_seconds": int(time.time() - start_time),
                    "main_app_health": check_main_app_health()
                },
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(metrics, indent=2).encode())
            
        else:
            self.send_response(404)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {"error": "Not found"}
            self.wfile.write(json.dumps(response).encode())

def get_log_count():
    """获取处理的日志行数"""
    log_file = "/shared/logs/main-app.log"
    if os.path.exists(log_file):
        with open(log_file, "r") as f:
            return len(f.readlines())
    return 0

def check_main_app_health():
    """检查主应用的健康状态"""
    try:
        import urllib.request
        response = urllib.request.urlopen("http://localhost:8080/health", timeout=5)
        return response.status == 200
    except:
        return False

def collect_logs():
    """持续收集和处理日志"""
    log_file = "/shared/logs/main-app.log"
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    print("Sidecar: Starting log collection...")
    
    while True:
        if os.path.exists(log_file):
            with open(log_file, "r") as f:
                lines = f.readlines()
                for line in lines:
                    if line.strip():
                        # 在这里可以添加日志处理逻辑，比如发送到外部系统
                        print(f"Sidecar: Processing log - {line.strip()}")
        
        time.sleep(5)  # 每5秒检查一次新日志

if __name__ == "__main__":
    start_time = time.time()
    
    # 启动日志收集线程
    import threading
    log_thread = threading.Thread(target=collect_logs, daemon=True)
    log_thread.start()
    
    # 启动 HTTP 服务器
    PORT = 8081
    print(f"Sidecar starting on port {PORT}")
    
    with socketserver.TCPServer(("", PORT), SidecarHandler) as httpd:
        print(f"Sidecar server running at http://localhost:{PORT}")
        print("Available endpoints:")
        print("  / - Sidecar info")
        print("  /logs - View collected logs")
        print("  /metrics - View metrics")
        httpd.serve_forever()
