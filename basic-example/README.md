# Basic Nginx Deployment Example

这是一个基础的Kubernetes部署示例，展示如何使用Deployment和NodePort Service部署一个nginx web服务器。

## 文件说明

### deployment.yaml
- **类型**: Deployment
- **功能**: 创建和管理nginx Pod副本
- **配置**: 1个副本，使用nginx:latest镜像，暴露80端口

### service.yaml
- **类型**: Service (NodePort)
- **功能**: 将nginx服务暴露到集群外部
- **配置**: 通过节点端口30000访问nginx服务

### clusterip-service.yaml
- **类型**: Service (ClusterIP)
- **功能**: 在集群内部暴露nginx服务
- **配置**: 只能在集群内部访问，使用Service名称进行DNS解析

### test-clusterip.sh
- **类型**: 测试脚本
- **功能**: 自动化测试ClusterIP Service的访问
- **配置**: 创建测试Pod并验证集群内部访问

## 部署步骤

### 1. 部署nginx应用

```bash
# 创建Deployment
kubectl apply -f deployment.yaml

# 验证Deployment状态
kubectl get deployments
kubectl get pods -l app=nginx
```

**预期输出**:
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   1/1     1            1           30s

NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-7b4c8c4b5d-xxxxx   1/1     Running   0          30s
```

### 2. 创建NodePort Service

```bash
# 创建Service
kubectl apply -f service.yaml

# 验证Service状态
kubectl get services
kubectl get svc nginx-service
```

**预期输出**:
```
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx-service   NodePort    10.96.xxx.xxx  <none>        80:30000/TCP   10s
```

### 3. 获取节点IP地址

```bash
# 获取节点IP（用于外部访问）
kubectl get nodes -o wide

# 或者使用JSONPath直接获取IP
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
```

**预期输出**:
```
NAME    STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE
think   Ready    control-plane   1d    v1.28.2   192.168.0.123   <none>        Ubuntu 22.04.3 LTS
```

### 4. 访问nginx服务

#### 4.1 外部访问 (NodePort)

使用以下方式从集群外部访问nginx服务：

```bash
# 方式1: 通过节点IP和NodePort访问
curl http://192.168.0.123:30000

# 方式2: 在浏览器中访问
# http://192.168.0.123:30000
```

**预期输出**:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</html>
```

#### 4.2 集群内部访问 (ClusterIP)

```bash
# 创建ClusterIP Service
kubectl apply -f clusterip-service.yaml

# 方式1: 使用测试脚本（推荐）
./test-clusterip.sh

# 方式2: 手动创建测试Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-clusterip

# 方式3: 使用完整域名
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-clusterip.default.svc.cluster.local
```

**预期输出**:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</html>
```

## ClusterIP Service 测试

### 快速测试

```bash
# 使用自动化测试脚本（推荐）
./test-clusterip.sh
```

### 手动测试步骤

```bash
# 1. 创建ClusterIP Service
kubectl apply -f clusterip-service.yaml

# 2. 验证Service状态
kubectl get svc nginx-clusterip
kubectl describe svc nginx-clusterip

# 3. 创建测试Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# 4. 在Pod内部测试
# wget -qO- http://nginx-clusterip
# nslookup nginx-clusterip
# nc -zv nginx-clusterip 80
```

### 测试脚本功能

`test-clusterip.sh` 脚本会自动执行以下测试：

1. ✅ 检查nginx deployment状态
2. ✅ 检查nginx pods状态  
3. ✅ 创建ClusterIP Service
4. ✅ 验证Service状态
5. ✅ 检查Service的Endpoints
6. ✅ 创建测试Pod并执行内部访问测试
7. ✅ 清理测试资源

## 验证部署

### 检查Pod状态
```bash
# 查看Pod详细信息
kubectl describe pod -l app=nginx

# 查看Pod日志
kubectl logs -l app=nginx
```

### 检查Service状态
```bash
# 查看Service详细信息
kubectl describe service nginx-service

# 查看Service的Endpoints
kubectl get endpoints nginx-service
```

### 检查网络连通性
```bash
# 在集群内部测试Service访问
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://nginx-service

# 测试NodePort访问
curl -I http://192.168.0.123:30000
```

## 配置说明

### Deployment配置详解

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1                    # Pod副本数量
  selector:
    matchLabels:
      app: nginx                 # 选择器标签
  template:
    metadata:
      labels:
        app: nginx               # Pod标签
    spec:
      containers:
      - name: nginx
        image: nginx:latest      # 容器镜像
        ports:
        - containerPort: 80      # 容器端口
```

### Service配置详解

#### NodePort Service (service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort                 # Service类型
  selector:
    app: nginx                   # 选择器（匹配Pod标签）
  ports:
    - protocol: TCP
      port: 80                   # Service内部端口
      targetPort: 80             # Pod端口
      nodePort: 30000            # 节点端口（30000-32767）
```

#### ClusterIP Service (clusterip-service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
spec:
  type: ClusterIP                # Service类型（默认）
  selector:
    app: nginx                   # 选择器（匹配Pod标签）
  ports:
    - protocol: TCP
      port: 80                   # Service内部端口
      targetPort: 80             # Pod端口
```

## 常用操作

### 扩缩容
```bash
# 扩展到3个副本
kubectl scale deployment nginx-deployment --replicas=3

# 查看扩展后的状态
kubectl get pods -l app=nginx
```

### 更新镜像
```bash
# 更新到特定版本
kubectl set image deployment/nginx-deployment nginx=nginx:1.21

# 查看更新状态
kubectl rollout status deployment/nginx-deployment
```

### 回滚
```bash
# 查看部署历史
kubectl rollout history deployment/nginx-deployment

# 回滚到上一个版本
kubectl rollout undo deployment/nginx-deployment
```

## 清理资源

```bash
# 删除NodePort Service
kubectl delete -f service.yaml

# 删除ClusterIP Service
kubectl delete -f clusterip-service.yaml

# 删除Deployment
kubectl delete -f deployment.yaml

# 或者一次性删除所有资源
kubectl delete -f .
```

## 故障排除

### 常见问题

1. **Pod无法启动**
   ```bash
   # 查看Pod状态
   kubectl get pods -l app=nginx
   
   # 查看Pod事件
   kubectl describe pod -l app=nginx
   
   # 查看Pod日志
   kubectl logs -l app=nginx
   ```

2. **Service无法访问**
   ```bash
   # 检查Service和Pod标签是否匹配
   kubectl get pods --show-labels
   kubectl get service nginx-service -o yaml
   
   # 检查Endpoints
   kubectl get endpoints nginx-service
   ```

3. **NodePort无法访问**
   ```bash
   # 确认节点IP
   kubectl get nodes -o wide
   
   # 检查端口是否被占用
   netstat -tlnp | grep 30000
   
   # 检查防火墙设置
   sudo ufw status
   ```

### 调试命令

```bash
# 进入Pod内部调试
kubectl exec -it deployment/nginx-deployment -- /bin/bash

# 查看集群事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 查看Cilium网络状态（如果使用Cilium）
kubectl exec -n kube-system ds/cilium -- cilium status
```

## 网络架构

### NodePort 访问流程
```
外部客户端
    ↓
192.168.0.123:30000 (NodePort)
    ↓
Cilium eBPF (网络转发)
    ↓
nginx Pod (10.1.0.x:80)
```

### ClusterIP 访问流程
```
集群内部Pod
    ↓ DNS查询
CoreDNS (nginx-clusterip)
    ↓ 返回Service IP
nginx-clusterip (10.96.x.x)
    ↓ Cilium eBPF转发
nginx Pod (10.1.0.x:80)
```

## 注意事项

1. **端口范围**: NodePort端口必须在30000-32767范围内
2. **防火墙**: 确保节点防火墙允许NodePort端口访问
3. **网络策略**: 如果启用了网络策略，需要相应配置
4. **资源限制**: 生产环境建议设置资源限制和请求
5. **Service类型选择**:
   - **NodePort**: 适合开发/测试环境，外部访问
   - **ClusterIP**: 适合集群内部服务通信，更安全
6. **DNS解析**: ClusterIP Service支持多种域名格式访问

## 扩展阅读

- [Kubernetes Deployment文档](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Service文档](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Cilium网络文档](https://docs.cilium.io/)

---
*最后更新: 2025-09-09*
