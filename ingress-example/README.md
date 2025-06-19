# Kubernetes Ingress 示例

本示例演示了如何在 Kubernetes 集群中使用 Ingress Controller 和 MetalLB 来暴露服务。

**视频教程**: https://www.bilibili.com/video/BV13DdoYhE1F/?vd_source=8199c71e52e7af8b17093229c514230d

## 📋 目录

- [前置条件](#前置条件)
- [快速开始](#快速开始)
- [示例 1: 基础 Nginx 服务](#示例-1-基础-nginx-服务)
- [示例 2: 路径路由](#示例-2-路径路由)
- [示例 3: 子域名路由](#示例-3-子域名路由)
- [故障排除](#故障排除)
- [清理资源](#清理资源)

## 🔧 前置条件

在开始之前，请确保：

1. **Kubernetes 集群已运行**
   ```bash
   kubectl cluster-info
   ```

2. **MetalLB 已安装并配置**
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

3. **Ingress Controller 已安装**
   ```bash
   # 安装 nginx-ingress-controller
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   
   # 等待 Ingress Controller 启动
   kubectl wait --namespace ingress-nginx \
     --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller \
     --timeout=120s
   ```

4. **验证 Ingress Controller 状态**
   ```bash
   kubectl get svc -n ingress-nginx
   ```
   
   应该看到类似输出：
   ```bash
   NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
   ingress-nginx-controller             LoadBalancer   10.152.183.101   192.168.1.200   80:30236/TCP,443:32580/TCP   10d
   ingress-nginx-controller-admission   ClusterIP      10.152.183.135   <none>          443/TCP                      10d
   ```

## 🚀 快速开始

### 步骤 1: 验证环境
```bash
# 检查 MetalLB 状态
kubectl get pods -n metallb-system

# 检查 Ingress Controller 状态
kubectl get pods -n ingress-nginx

# 检查 IP 地址池
kubectl get ipaddresspool -n metallb-system
```

### 步骤 2: 获取外部 IP
```bash
# 获取 Ingress Controller 的外部 IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
```

## 📝 示例 1: 基础 Nginx 服务

### 部署服务
```bash
# 应用配置
kubectl apply -f nginx-k8s-deployment.yaml
```

### 验证部署
```bash
# 检查资源状态
kubectl get pods -l app=nginx
kubectl get svc nginx-service
kubectl get ingress nginx-ingress

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
```

### 访问服务
```bash
# 使用 curl 访问服务
curl http://192.168.1.200

# 或者使用动态获取的 IP
curl http://$EXTERNAL_IP
```

**预期输出**: 应该看到 Nginx 欢迎页面

### 清理资源
```bash
kubectl delete -f nginx-k8s-deployment.yaml
```

## 🌐 示例 2: 路径路由

本示例演示如何通过不同路径访问多个服务。

### 部署服务
```bash
# 应用配置
kubectl apply -f multi-service-ingress-by-path.yaml
```

### 验证部署
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

### 访问服务

#### 访问 Nginx 服务
```bash
curl -H "Host: example.com" http://192.168.1.200/nginx
```

**预期输出**: Nginx 欢迎页面

#### 访问其他服务
```bash
curl -H "Host: example.com" http://192.168.1.200/other
```

**预期输出**: `Hello from Other Service!`

### 清理资源
```bash
kubectl delete -f multi-service-ingress-by-path.yaml
```

## 🏷️ 示例 3: 子域名路由

本示例演示如何通过不同子域名访问多个服务。

### 部署服务
```bash
# 应用配置
kubectl apply -f subdomain-ingress.yaml
```

### 验证部署
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

### 访问服务

#### 通过 nginx.example.com 访问
```bash
curl -H "Host: nginx.example.com" http://192.168.1.200
```

**预期输出**: Nginx 欢迎页面

#### 通过 other.example.com 访问
```bash
curl -H "Host: other.example.com" http://192.168.1.200
```

**预期输出**: `Hello from Other Service!`

### 清理资源
```bash
kubectl delete -f subdomain-ingress.yaml
```

## 🔍 故障排除

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

## 🧹 清理资源

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

## 📚 相关资源

- [MetalLB 官方文档](https://metallb.universe.tf/)
- [NGINX Ingress Controller 文档](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes Ingress 文档](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## 📁 文件说明

- `metallb-config.yaml` - MetalLB 配置文件
- `nginx-k8s-deployment.yaml` - 基础 Nginx 服务配置
- `multi-service-ingress-by-path.yaml` - 路径路由示例
- `subdomain-ingress.yaml` - 子域名路由示例
- `INSTALL.md` - 详细安装说明
- `METALLB_ANALYSIS.md` - MetalLB 使用分析

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个示例。

## 📄 许可证

本项目采用 MIT 许可证。