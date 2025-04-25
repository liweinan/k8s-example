# 以下是极简的 Kubernetes 部署 Nginx 服务的配置说明，包含 Deployment、Service 和 Ingress，端口使用 8080

**完整说明**:

以下是用于在 Kubernetes 集群中部署极简 Nginx 服务的 YAML 配置，包含 Deployment、Service 和 Ingress，使用 8080 端口。配置旨在提供基本的
Nginx 服务，通过 ClusterIP 类型的 Service 暴露服务，并通过 Ingress 提供外部访问入口。

1. **Deployment (nginx-deployment)**:
    - 名称：`nginx-deployment`，运行 1 个副本（可根据需要调整）。
    - 使用官方 `nginx:latest` 镜像，容器监听 8080 端口。
    - 通过标签 `app: nginx` 关联 Pod，确保 Service 和 Deployment 正确绑定。

2. **Service (nginx-service)**:
    - 名称：`nginx-service`，类型为 `ClusterIP`，适用于集群内部访问。
    - 通过标签选择器 `app: nginx` 绑定到 Deployment 的 Pod。
    - Service 监听 8080 端口，并将流量转发到 Pod 的 8080 端口。

3. **Ingress (nginx-ingress)**:
    - 名称：`nginx-ingress`，用于外部访问。
    - 配置 HTTP 路径 `/`（前缀匹配），将请求转发到 `nginx-service` 的 8080 端口。
    - 使用注解 `nginx.ingress.kubernetes.io/rewrite-target: /` 确保路径重写正确。
    - 需集群中已安装 Ingress Controller（如 nginx-ingress）以处理 Ingress 规则。

**部署步骤**:

1. 将上述 YAML 配置保存到文件，例如 `nginx-k8s-deployment.yaml`。
2. 确保 Kubernetes 集群已安装并配置好 Ingress Controller（如 nginx-ingress）。
3. 执行以下部署命令：
   ```bash
   kubectl apply -f nginx-k8s-deployment.yaml
   ```
   此命令将创建 Deployment、Service 和 Ingress 资源。

**访问说明**:

- 部署完成后，确认 Ingress Controller 的 IP 地址或域名。
- 配置 DNS 或本地 hosts 文件，将域名（如 `example.com`）解析到 Ingress Controller 的 IP。
- 通过浏览器访问 `http://<域名>:8080/`，即可看到 Nginx 欢迎页面。
- 若无域名，可直接使用 `kubectl port-forward` 或集群 IP 测试。

**销毁步骤**:
若需清理部署的资源，执行以下命令：

```bash
kubectl delete -f nginx-k8s-deployment.yaml
```

此命令将删除 Deployment、Service 和 Ingress 资源，清理所有相关对象。

**注意事项**:

- 确保集群中 Ingress Controller 正常运行，否则 Ingress 无法生效。
- 可根据需求调整副本数（`replicas`）、镜像版本或添加其他 Ingress 注解（如 TLS 配置）。
- 如果需要 HTTPS，需为 Ingress 添加 TLS 配置并提供证书。
- 部署前建议检查 YAML 文件格式，确保语法正确。

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
---
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
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
    paths:
      - path: /
        pathType: Prefix
        backend:
        service:
        name: nginx-service
        port:
        number: 8080
```

