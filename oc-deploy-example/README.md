# 在 OpenShift Local（CRC）上部署 Nginx 应用的简洁教程

本教程指导你在 macOS 上使用 OpenShift Local（CRC）部署一个 Nginx 应用，基于 OpenShift 4.18.2，在 `my-demo` 命名空间运行，通过
`127.0.0.1` 和 CRC 自动修改的 `/etc/hosts` 访问服务。教程包括代理配置、权限配置、正确的配置文件和访问 Service 的方式。

## 前提条件

- **环境**：macOS，安装了 CRC 和 `oc` CLI。
- **命名空间**：`my-demo`（已通过 `oc new-project my-demo` 创建）。
- **镜像**：`docker.io/library/nginx:latest`（无需认证）。
- **网络**：使用 `127.0.0.1`，CRC 自动更新 `/etc/hosts` 解析域名，代理为 `squid.corp.redhat.com:3128`。

## 目标

- 部署 Nginx Pod，状态为 `Running`。
- 配置 Service 和 Route，通过 `127.0.0.1` 访问服务。
- 确保代理和权限正确设置。

---

## 教程步骤

### 1. 代理配置

配置 CRC 和集群使用代理，确保镜像拉取正常。

#### 1.1 设置代理

```bash
export HTTP_PROXY=http://squid.corp.redhat.com:3128
export HTTPS_PROXY=http://squid.corp.redhat.com:3128
export NO_PROXY=localhost,127.0.0.1,.crc.testing,.apps-crc.testing
crc config set http-proxy $HTTP_PROXY
crc config set https-proxy $HTTPS_PROXY
crc config set no-proxy "$NO_PROXY"
```

#### 1.2 重启 CRC

```bash
crc stop
crc start
```

---

### 2. 权限配置

为 `developer` 用户和 `default` 服务账户授予必要权限，确保可以创建资源和使用 `anyuid` SCC。

#### 2.1 授予 `developer` 权限

为 `developer` 用户在 `my-demo` 命名空间绑定 `edit` 角色：

```bash
oc create rolebinding developer-edit --clusterrole=edit --user=developer -n my-demo
```

验证：

```bash
oc auth can-i create configmaps -n my-demo
oc auth can-i create pods -n my-demo
oc auth can-i create services -n my-demo
oc auth can-i create routes -n my-demo
```

- 预期：`yes`

#### 2.2 授予 `anyuid` SCC

以 `kubeadmin` 用户为 `default` 服务账户绑定 `anyuid` SCC：

```bash
oc login -u kubeadmin
oc adm policy add-scc-to-user anyuid -z default -n my-demo
oc login -u developer
```

验证：

```bash
oc describe clusterrolebinding | grep anyuid
```

- 确认包含 `system:serviceaccount:my-demo:default`。

---

### 3. 配置文件

以下是验证可运行的配置文件，用于部署 Nginx Pod、Service 和 Route。

#### 3.1 ConfigMap（`nginx-config.yaml`）

创建 Nginx 配置文件，监听 8080 端口：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: my-demo
data:
  nginx.conf: |
    worker_processes auto;
    events {
      worker_connections 1024;
    }
    http {
      include /etc/nginx/conf.d/*.conf;
    }
  default.conf: |
    server {
      listen 8080;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
      }
    }
```

应用：

```bash
oc apply -f nginx-config.yaml
```

#### 3.2 Pod（`nginx-pod.yaml`）

部署 Nginx Pod，使用 `anyuid` SCC 和 `emptyDir` 卷：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: my-demo
  labels:
    app: nginx
spec:
  securityContext:
    fsGroup: 101
  containers:
    - name: nginx
      image: docker.io/library/nginx:latest
      securityContext:
        runAsUser: 101
        runAsGroup: 101
      volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /run
      ports:
        - containerPort: 8080
  volumes:
    - name: nginx-config
      configMap:
        name: nginx-config
    - name: nginx-cache
      emptyDir: { }
    - name: nginx-run
      emptyDir: { }
```

应用：

```bash
oc apply -f nginx-pod.yaml
```

#### 3.3 Service（`nginx-service.yaml`）

暴露 Nginx Pod：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: my-demo
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

应用：

```bash
oc apply -f nginx-service.yaml
```

#### 3.4 Route（`nginx-route.yaml`）

创建外部路由：

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: nginx-route
  namespace: my-demo
spec:
  to:
    kind: Service
    name: nginx-service
  port:
    targetPort: 8080
  wildcardPolicy: None
```

应用：

```bash
oc apply -f nginx-route.yaml
```

---

### 4. 访问 Service

服务通过 `127.0.0.1` 访问，CRC 自动将路由主机名添加到 `/etc/hosts`。

#### 4.1 确认 `/etc/hosts`

检查 `/etc/hosts`：

```bash
cat /etc/hosts
```

- CRC 会自动添加：
  ```
  127.0.0.1        nginx-route-my-demo.apps-crc.testing
  ```
- 无需手动修改，CRC 在 Route 创建或集群启动时更新。

#### 4.2 访问路由

```bash
curl http://nginx-route-my-demo.apps-crc.testing
```

- 预期：返回 Nginx 欢迎页面：
  ```
  <!DOCTYPE html>
  <html>
  <head>
  <title>Welcome to nginx!</title>
  ...
  <h1>Welcome to nginx!</h1>
  ...
  </html>
  ```

#### 4.3 绕过代理

如果访问失败，确保代理不干扰：

```bash
unset HTTP_PROXY HTTPS_PROXY
curl http://nginx-route-my-demo.apps-crc.testing
```

或：

```bash
export NO_PROXY=localhost,127.0.0.1,.crc.testing,.apps-crc.testing
curl http://nginx-route-my-demo.apps-crc.testing
```

---

### 验证

```bash
oc get pods -n my-demo
oc get svc nginx-service -n my-demo
oc get route nginx-route -n my-demo
curl http://nginx-route-my-demo.apps-crc.testing
```

---

### 清理

```bash
oc login -u kubeadmin
oc adm policy remove-scc-from-user anyuid -z default -n my-demo
oc login -u developer
oc delete pod nginx-pod -n my-demo
oc delete svc nginx-service -n my-demo
oc delete route nginx-route -n my-demo
oc delete configmap nginx-config -n my-demo
oc delete rolebinding developer-edit -n my-demo
```

---

### 注意事项

- **代理**：确保 `NO_PROXY` 包含 `localhost`, `127.0.0.1`, `.crc.testing`, `.apps-crc.testing`，避免干扰本地访问。
- **权限**：`developer` 用户需 `edit` 角色，`default` 服务账户需 `anyuid` SCC。
- **域名**：CRC 自动管理 `/etc/hosts`，无需手动修改。
- **防火墙**：如访问失败，检查 macOS 防火墙：
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
  ```

---

### 总结

本教程提供了在 macOS 上使用 CRC 部署 Nginx 应用的完整流程，通过 `127.0.0.1` 和 CRC 自动更新的 `/etc/hosts`
访问服务。代理配置确保镜像拉取，权限配置支持 Pod 部署，配置文件经过验证，访问方式简单可靠。

如需进一步帮助，请提供：

- `oc get route -n my-demo` 输出。
- `/etc/hosts` 最新内容。
- `curl http://nginx-route-my-demo.apps-crc.testing` 的结果（若失败）。

祝你部署顺利！