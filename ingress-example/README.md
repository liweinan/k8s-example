# Kubernetes Ingress 完整指南

本指南提供了在 Kubernetes 集群中使用 Ingress Controller 和 MetalLB 的完整解决方案，包括安装、配置、部署和故障排除。

**视频教程**: https://www.bilibili.com/video/BV13DdoYhE1F/?vd_source=8199c71e52e7af8b17093229c514230d

## 📋 目录

- [概述](#概述)
- [架构分析](#架构分析)
- [前置条件](#前置条件)
- [安装和配置](#安装和配置)
- [快速开始](#快速开始)
- [示例部署](#示例部署)
- [MetalLB 深度分析](#metallb-深度分析)
- [故障排除](#故障排除)
- [清理资源](#清理资源)
- [扩展和优化](#扩展和优化)

## 概述

本示例演示了如何在 Kubernetes 集群中使用 Ingress Controller 和 MetalLB 来暴露服务。MetalLB 是一个用于裸机 Kubernetes 集群的负载均衡器实现，它通过标准路由协议为 LoadBalancer 类型的服务分配外部 IP 地址。

### 主要特性

- **MetalLB 负载均衡**: 为裸机集群提供 LoadBalancer 功能
- **Ingress 路由**: 支持路径和子域名路由
- **多服务部署**: 演示单服务和多服务部署模式
- **完整配置**: 包含详细的安装和配置说明

## 架构分析

### 网络流量路径

```
外部请求 → 192.168.1.200:80 → ingress-nginx-controller → Ingress 规则 → 后端服务
```

### 组件关系

1. **MetalLB**: 为 Ingress Controller 分配外部 IP 地址
2. **Ingress Controller**: 处理外部请求并路由到后端服务
3. **应用服务**: 使用 ClusterIP 类型，通过 Ingress 暴露

### MetalLB 配置分析

项目中的 MetalLB 配置包含两个主要组件：

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.250  # 使用您的本地网络可用IP段
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
```

**配置组件详解**:

- **IPAddressPool**: 定义可分配给 LoadBalancer 服务的 IP 地址池
- **L2Advertisement**: 配置 L2 模式下的地址通告，使用 ARP/NDP 协议

## 前置条件

在开始之前，请确保：

1. **Kubernetes 集群已运行**
   ```bash
   kubectl cluster-info
   ```

2. **网络环境准备**
   - 确保 IP 地址段 `192.168.1.200-192.168.1.250` 在您的网络中可用
   - 检查防火墙设置，确保端口 80 和 443 可访问

## 安装和配置

### 步骤 1: 安装 MetalLB

```bash
# 安装 MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# 等待 MetalLB 组件启动
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# 应用 MetalLB 配置
kubectl apply -f metallb-config.yaml
```

### 步骤 2: 安装 Ingress Controller

```bash
# 安装 nginx-ingress-controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 等待 Ingress Controller 启动
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 步骤 3: 验证安装

```bash
# 检查 MetalLB 状态
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system

# 检查 Ingress Controller 状态
kubectl get svc -n ingress-nginx
```

应该看到类似输出：
```bash
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.152.183.101   192.168.1.200   80:30236/TCP,443:32580/TCP   10d
ingress-nginx-controller-admission   ClusterIP      10.152.183.135   <none>          443/TCP                      10d
```

## 快速开始

### 获取外部 IP

```bash
# 获取 Ingress Controller 的外部 IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
```

## 示例部署

### 示例 1: 基础 Nginx 服务

#### 部署服务
```bash
# 应用配置
kubectl apply -f nginx-k8s-deployment.yaml
```

#### 验证部署
```bash
# 检查资源状态
kubectl get pods -l app=nginx
kubectl get svc nginx-service
kubectl get ingress nginx-ingress

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
```

#### 访问服务
```bash
# 使用 curl 访问服务
curl http://192.168.1.200

# 或者使用动态获取的 IP
curl http://$EXTERNAL_IP
```

**预期输出**: 应该看到 Nginx 欢迎页面

#### 清理资源
```bash
kubectl delete -f nginx-k8s-deployment.yaml
```

### 示例 2: 路径路由

本示例演示如何通过不同路径访问多个服务。

#### 部署服务
```bash
# 应用配置
kubectl apply -f multi-service-ingress-by-path.yaml
```

#### 验证部署
```bash
# 检查所有资源状态
kubectl get pods -l app=nginx
kubectl get pods -l app=other-app
kubectl get svc
kubectl get ingress multi-service-ingress

# 等待所有 Pod 就绪
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
kubectl wait --for=condition=ready pod -l app=other-app --timeout=60s
```

#### 访问服务

**访问 Nginx 服务**:
```bash
curl -H "Host: example.com" http://192.168.1.200/nginx
```
**预期输出**: Nginx 欢迎页面

**访问其他服务**:
```bash
curl -H "Host: example.com" http://192.168.1.200/other
```
**预期输出**: `Hello from Other Service!`

#### 清理资源
```bash
kubectl delete -f multi-service-ingress-by-path.yaml
```

### 示例 3: 子域名路由

本示例演示如何通过不同子域名访问多个服务。

#### 部署服务
```bash
# 应用配置
kubectl apply -f subdomain-ingress.yaml
```

#### 验证部署
```bash
# 检查所有资源状态
kubectl get pods -l app=nginx
kubectl get pods -l app=other-app
kubectl get svc
kubectl get ingress subdomain-ingress

# 等待所有 Pod 就绪
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
kubectl wait --for=condition=ready pod -l app=other-app --timeout=60s
```

#### 访问服务

**通过 nginx.example.com 访问**:
```bash
curl -H "Host: nginx.example.com" http://192.168.1.200
```
**预期输出**: Nginx 欢迎页面

**通过 other.example.com 访问**:
```bash
curl -H "Host: other.example.com" http://192.168.1.200
```
**预期输出**: `Hello from Other Service!`

#### 清理资源
```bash
kubectl delete -f subdomain-ingress.yaml
```

## MetalLB 深度分析

### 与 Ingress Controller 的集成

从实际部署可以看到：

```bash
$ kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.152.183.101   192.168.1.200   80:30236/TCP,443:32580/TCP   10d
ingress-nginx-controller-admission   ClusterIP      10.152.183.135   <none>          443/TCP                      10d
```

**关键信息**:
- `ingress-nginx-controller` 服务类型为 `LoadBalancer`
- MetalLB 为其分配了外部 IP `192.168.1.200`
- 服务暴露端口：80 (HTTP) 和 443 (HTTPS)

### 实际应用场景分析

#### 单服务部署

在 `nginx-k8s-deployment.yaml` 中：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: ClusterIP  # 注意：这里使用 ClusterIP，不是 LoadBalancer
```

**分析**:
- 应用服务使用 `ClusterIP` 类型，不直接暴露到外部
- 通过 Ingress 控制器进行外部访问
- MetalLB 只为 Ingress Controller 分配 IP，应用服务通过 Ingress 规则路由

#### 多服务路径路由

在 `multi-service-ingress-by-path.yaml` 中：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-service-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /nginx
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
          - path: /other
            pathType: Prefix
            backend:
              service:
                name: other-service
                port:
                  number: 9090
```

**访问方式**:
```bash
curl -H "Host: example.com" http://192.168.1.200/nginx
curl -H "Host: example.com" http://192.168.1.200/other
```

#### 子域名路由

在 `subdomain-ingress.yaml` 中：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: subdomain-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: nginx.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
    - host: other.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: other-service
                port:
                  number: 9090
```

**访问方式**:
```bash
curl -H "Host: nginx.example.com" http://192.168.1.200
curl -H "Host: other.example.com" http://192.168.1.200
```

### MetalLB 的优势和特点

#### 优势

1. **简化部署**: 无需云提供商的负载均衡器
2. **成本效益**: 在裸机环境中提供 LoadBalancer 功能
3. **标准兼容**: 使用标准的 Kubernetes LoadBalancer 接口
4. **灵活配置**: 支持多种 IP 分配策略

#### 网络模式

项目中使用的是 **L2 模式**：
- 使用 ARP/NDP 协议进行地址通告
- 适合本地网络环境
- 配置简单，无需特殊网络设备

#### IP 分配策略

- **地址池**: 192.168.1.200-192.168.1.250
- **分配方式**: 按需分配，先到先得
- **持久性**: IP 地址在服务删除前保持分配

## 故障排除

### 常见问题

#### 1. 服务无法访问
```bash
# 检查 Pod 状态
kubectl get pods -A

# 检查服务状态
kubectl get svc -A

# 检查 Ingress 状态
kubectl get ingress -A

# 查看 Pod 日志
kubectl logs -l app=nginx
```

#### 2. MetalLB 问题
```bash
# 检查 MetalLB 状态
kubectl get pods -n metallb-system

# 检查 IP 地址池
kubectl get ipaddresspool -n metallb-system

# 查看 MetalLB 日志
kubectl logs -n metallb-system -l app=metallb
```

#### 3. Ingress Controller 问题
```bash
# 检查 Ingress Controller 状态
kubectl get pods -n ingress-nginx

# 查看 Ingress Controller 日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# 检查 Ingress Controller 配置
kubectl describe svc -n ingress-nginx ingress-nginx-controller
```

#### 4. 网络连通性测试
```bash
# 测试端口连通性
telnet 192.168.1.200 80

# 或者使用 nc
nc -zv 192.168.1.200 80
```

### 调试命令

#### 查看详细资源信息
```bash
# 查看 Pod 详细信息
kubectl describe pod -l app=nginx

# 查看服务详细信息
kubectl describe svc nginx-service

# 查看 Ingress 详细信息
kubectl describe ingress nginx-ingress
```

#### 端口转发测试
```bash
# 直接测试服务（绕过 Ingress）
kubectl port-forward svc/nginx-service 8080:8080

# 在另一个终端测试
curl http://localhost:8080
```

### 特殊问题处理

#### Nginx 容器端口配置问题

默认的 `nginx:latest` 镜像监听端口 80，如果您的配置使用 8080 端口，需要自定义 Nginx 配置：

1. **创建自定义 Nginx 配置**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: nginx-config
   data:
     nginx.conf: |
       server {
           listen 8080;
           location / {
               root /usr/share/nginx/html;
               index index.html index.htm;
           }
       }
   ```

2. **更新 Deployment**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx-deployment
     labels:
       app: nginx
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: nginx
     template:
       metadata:
         labels:
           app: nginx
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           ports:
           - containerPort: 8080
           volumeMounts:
           - name: nginx-config
             mountPath: /etc/nginx/conf.d/default.conf
             subPath: nginx.conf
         volumes:
         - name: nginx-config
           configMap:
             name: nginx-config
   ```

#### Ingress Controller 端口配置

如果需要 Ingress Controller 监听非标准端口（如 8080），可以修改服务配置：

```bash
# 编辑 Ingress Controller 服务
kubectl edit svc -n ingress-nginx ingress-nginx-controller
```

修改端口配置：
```yaml
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 80
    protocol: TCP
  - name: https
    port: 443
    targetPort: 443
    protocol: TCP
```

## 清理资源

### 清理所有示例资源
```bash
# 清理示例 1
kubectl delete -f nginx-k8s-deployment.yaml

# 清理示例 2
kubectl delete -f multi-service-ingress-by-path.yaml

# 清理示例 3
kubectl delete -f subdomain-ingress.yaml
```

### 清理基础设施（可选）
```bash
# 删除 Ingress Controller
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 删除 MetalLB
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
kubectl delete -f metallb-config.yaml
```

## 扩展和优化

### 高可用性

1. **多节点部署**: 在多个节点上部署 MetalLB 控制器
2. **故障转移**: 配置适当的故障转移机制
3. **监控告警**: 设置监控和告警系统

### 性能优化

1. **IP 池管理**: 合理规划 IP 地址池大小
2. **负载均衡**: 考虑使用 BGP 模式获得更好的负载均衡效果
3. **缓存优化**: 优化 Ingress Controller 的缓存配置

### 生产环境建议

1. **备份配置**: 定期备份 MetalLB 配置
2. **版本管理**: 使用版本控制管理配置文件
3. **文档维护**: 维护详细的部署和运维文档
4. **安全考虑**: 
   - 网络隔离：MetalLB 分配的 IP 直接暴露在外部网络
   - 访问控制：建议配置适当的网络安全策略
   - 监控：监控 MetalLB 和 Ingress Controller 的状态

### 适用场景

这种架构特别适合：
- 本地开发环境
- 私有云部署
- 边缘计算场景
- 成本敏感的生产环境

## 总结

通过 MetalLB + Ingress Controller 的组合，可以在没有云提供商负载均衡器的环境中实现完整的 Kubernetes 服务暴露方案。本指南提供了从安装到部署的完整流程，以及深入的故障排除和优化建议。

## 📚 相关资源

- [MetalLB 官方文档](https://metallb.universe.tf/)
- [NGINX Ingress Controller 文档](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes Ingress 文档](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## 📁 文件说明

- `metallb-config.yaml` - MetalLB 配置文件
- `nginx-k8s-deployment.yaml` - 基础 Nginx 服务配置
- `multi-service-ingress-by-path.yaml` - 路径路由示例
- `subdomain-ingress.yaml` - 子域名路由示例

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个示例。

## 📄 许可证

本项目采用 MIT 许可证。
