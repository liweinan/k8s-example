# Kubernetes Sidecar 模式示例

这个示例演示了 Kubernetes 中的 Sidecar 模式，展示了如何在同一个 Pod 中运行主应用容器和辅助 Sidecar 容器。

## 什么是 Sidecar 模式？

Sidecar 模式是一种云原生设计模式，其中：
- **主应用容器**：提供核心业务功能
- **Sidecar 容器**：提供辅助功能（如日志收集、监控、安全等）
- 两个容器在同一个 Pod 中运行，共享网络和存储

## 示例架构

```
┌─────────────────────────────────────┐
│              Pod                    │
│  ┌─────────────────┐ ┌─────────────┐│
│  │   Main App      │ │   Sidecar   ││
│  │   (Port 8080)   │ │ (Port 8081) ││
│  │                 │ │             ││
│  │ - Web Server    │ │ - Logs      ││
│  │ - Business Logic│ │ - Monitoring││
│  │ - Health Check  │ │ - Metrics   ││
│  └─────────────────┘ └─────────────┘│
│           │               │         │
│           └───────┬───────┘         │
│                   │                 │
│            Shared Storage           │
│            (/shared/logs)           │
└─────────────────────────────────────┘
```

## 文件说明

- `main-app.py` - 主应用容器代码（Web 服务器）
- `sidecar-app.py` - Sidecar 容器代码（日志收集和监控）
- `Dockerfile.main-app` - 主应用 Dockerfile
- `Dockerfile.sidecar` - Sidecar Dockerfile
- `deployment.yaml` - Pod 部署清单
- `service.yaml` - Service 配置，暴露两个端口
- `build-images.sh` - 构建 Docker 镜像脚本
- `test.sh` - 自动化测试脚本

## 功能特性

### 主应用容器 (main-app)
- 监听端口 8080
- 提供 REST API 端点：
  - `GET /` - 主应用信息
  - `GET /health` - 健康检查
- 将日志写入共享存储卷

### Sidecar 容器 (sidecar)
- 监听端口 8081
- 提供监控端点：
  - `GET /` - Sidecar 信息
  - `GET /logs` - 查看收集的日志
  - `GET /metrics` - 查看指标
- 持续收集主应用的日志
- 监控主应用的健康状态

## 部署和使用

### 1. 构建 Docker 镜像

```bash
# 构建镜像
./build-images.sh
```

**注意**: 如果遇到网络问题，请配置代理：
```bash
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
./build-images.sh
```

或者修改 `build-images.sh` 中的构建命令，取消注释代理参数。

### 2. 部署到 Kubernetes

```bash
# 部署 Pod 和 Service
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 运行测试
./test.sh
```

### 3. 手动测试

```bash
# 获取 Pod IP
POD_IP=$(kubectl get pod sidecar-example -o jsonpath='{.status.podIP}')

# 测试主应用
curl http://$POD_IP:8080/
curl http://$POD_IP:8080/health

# 测试 Sidecar
curl http://$POD_IP:8081/
curl http://$POD_IP:8081/logs
curl http://$POD_IP:8081/metrics
```

### 4. 查看日志

```bash
# 查看主应用日志
kubectl logs sidecar-example -c main-app

# 查看 Sidecar 日志
kubectl logs sidecar-example -c sidecar

# 查看共享存储中的日志文件
kubectl exec sidecar-example -c main-app -- cat /shared/logs/main-app.log
```

## 关键概念演示

### 1. 共享网络
两个容器在同一个 Pod 中，可以通过 `localhost` 通信：
- Sidecar 容器可以通过 `http://localhost:8080` 访问主应用
- 主应用可以通过 `http://localhost:8081` 访问 Sidecar

### 2. 共享存储
两个容器共享 `/shared` 存储卷：
- 主应用将日志写入 `/shared/logs/main-app.log`
- Sidecar 容器读取这个文件进行日志处理

#### 数据流向图
```
主应用容器                    Sidecar 容器
     │                           |
     │ 写入日志                   | 读取日志
     ▼                           ▼
/shared/logs/main-app.log ←→ /shared/logs/main-app.log
     ▲                           ▲
     │                           │
     └─────── 共享存储卷 ─────────┘
```

### 3. 生命周期管理
- 两个容器同时启动和停止
- 如果主容器失败，整个 Pod 会重启
- 如果 Sidecar 容器失败，整个 Pod 也会重启

## 清理资源

```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
```

## 实际应用场景

这个示例展示了 Sidecar 模式的核心概念，在实际应用中，Sidecar 容器通常用于：

- **日志收集**：Fluentd、Logstash 等
- **服务网格**：Istio、Linkerd 等
- **监控**：Prometheus 指标收集
- **安全**：认证、授权、加密
- **网络代理**：流量管理、负载均衡

## 优势

1. **关注点分离**：业务逻辑与辅助功能分离
2. **可复用性**：同一个 Sidecar 可以用于多个应用
3. **独立升级**：可以独立更新 Sidecar 而不影响主应用
4. **技术栈无关**：Sidecar 可以用不同语言编写
5. **生产就绪**：使用 Docker 镜像，便于 CI/CD 和版本管理