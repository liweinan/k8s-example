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

---

The issue you're encountering is that the Ingress resource shows port 80 instead of the expected 8080. This is expected
behavior because Kubernetes Ingress typically exposes ports 80 (HTTP) or 443 (HTTPS) by default, as these are the
standard ports handled by the Ingress Controller (e.g., nginx-ingress). The port specified in the Ingress
configuration (8080 in your Service) is used to route traffic to the backend Service, not to change the external port
exposed by the Ingress Controller.

In your configuration, the Ingress correctly routes external HTTP requests (on port 80) to the `nginx-service` on port

8080. The `PORTS` column in `kubectl get ingress` reflects the port on which the Ingress Controller listens (80), not
      the backend Service port (8080).

### Explanation of Your Setup

- **Ingress Configuration**: Your Ingress forwards requests from `/` to the `nginx-service` on port 8080.
- **Service Configuration**: The `nginx-service` (ClusterIP) listens on port 8080 and forwards traffic to the Nginx
  container's port 8080.
- **Ingress Controller**: The Ingress Controller (e.g., nginx-ingress) listens on port 80 (or 443 for HTTPS) and proxies
  requests to the Service based on the Ingress rules.
- The `kubectl get ingress` output showing `PORTS 80` indicates the Ingress Controller's listening port, which is
  correct and does not affect your backend Service's port (8080).

### Verification Steps

To confirm that your setup is working as intended:

1. **Check Ingress Details**:
   ```bash
   kubectl describe ingress nginx-ingress
   ```
   Look for the `Rules` section to ensure the path `/` points to `nginx-service:8080`.

2. **Check Service**:
   ```bash
   kubectl get svc nginx-service
   ```
   Verify that the Service is running and exposes port 8080.

3. **Test Access**:
    - If you have a domain configured, access `http://<your-domain>/`. The Ingress Controller should proxy requests to
      the Nginx Service on port 8080.
    - If no domain is set up, use `kubectl port-forward` to test locally:
      ```bash
      kubectl port-forward svc/nginx-service 8080:8080
      ```
      Then open `http://localhost:8080` in a browser to confirm the Nginx welcome page.

4. **Check Ingress Controller Logs**:
   If the Ingress isn't working, check the Ingress Controller's logs for errors:
   ```bash
   kubectl logs -n <ingress-controller-namespace> <ingress-controller-pod-name>
   ```
   Replace `<ingress-controller-namespace>` and `<ingress-controller-pod-name>` with the appropriate values (e.g.,
   `ingress-nginx` namespace).

### If You Want Ingress to Listen on Port 8080

If your goal is to have the Ingress Controller itself listen on port 8080 (instead of 80), you need to configure the
Ingress Controller to use a non-standard port. This is not typically recommended, as Ingress Controllers are designed to
use 80/443, but it can be done by modifying the Ingress Controller's configuration.

#### Steps to Change Ingress Controller Port

1. **Edit Ingress Controller Service**:
    - Identify the Service used by your Ingress Controller (e.g., `ingress-nginx-controller` in the `ingress-nginx`
      namespace):
      ```bash
      kubectl get svc -n ingress-nginx
      ```
    - Edit the Service to change the port from 80 to 8080:
      ```bash
      kubectl edit svc ingress-nginx-controller -n ingress-nginx
      ```
      Update the `port` field under `ports` where `name: http`:
      ```yaml
      ports:
      - name: http
        port: 8080
        targetPort: 80
        protocol: TCP
      ```
      This makes the Ingress Controller listen on port 8080 externally but still proxies to the internal port (80) of
      the controller.

2. **Restart Ingress Controller**:
   After editing, the Ingress Controller pods may need to restart to apply changes:
   ```bash
   kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
   ```

3. **Verify Ingress Port**:
   Check the Ingress again:
   ```bash
   kubectl get ingress
   ```
   The `PORTS` column should still show 80 (as this is a Kubernetes API limitation), but accessing the Ingress
   Controller's IP on port 8080 should now work.

4. **Access Test**:
   Access `http://<ingress-controller-ip>:8080/`. If your Ingress Controller is exposed via a LoadBalancer or NodePort,
   use the external IP or node IP with port 8080.

#### Caveats

- Changing the Ingress Controller to listen on 8080 is non-standard and may conflict with other services or expectations
  in your cluster.
- Some cloud providers or Ingress Controllers may restrict port changes or require additional configuration.
- Ensure your firewall or security groups allow traffic on port 8080 if using a cloud provider.

### Alternative: Keep Port 80 and Adjust Expectations

If the goal is simply to ensure the backend Service uses 8080 (which your current setup already does), you don't need to
change the Ingress Controller's port. The Ingress Controller can listen on 80 and still route traffic to your Service's
8080 port. Update your DNS or hosts file to point to the Ingress Controller's IP, and access the service via
`http://<your-domain>/`. This is the standard and recommended approach.

### Fixing Potential Issues

If the Ingress isn't routing traffic correctly to port 8080, consider these checks:

- **Ingress Controller Installation**: Ensure an Ingress Controller (e.g., nginx-ingress) is installed and running:
  ```bash
  kubectl get pods -n ingress-nginx
  ```
  If not installed, deploy it (example for nginx-ingress):
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
  ```

- **Annotations**: Verify the `nginx.ingress.kubernetes.io/rewrite-target: /` annotation is correctly applied. If using
  a different Ingress Controller, you may need different annotations.

- **Service Port Mapping**: Double-check the Service port configuration:
  ```bash
  kubectl describe svc nginx-service
  ```
  Ensure `Port: 8080` maps to `TargetPort: 8080`.

- **Nginx Container Port**: Ensure the Nginx container is configured to listen on 8080. The default Nginx image listens
  on port 80, not 8080. You need to customize the Nginx configuration to listen on 8080.

#### Update Nginx to Listen on 8080

The `nginx:latest` image by default listens on port 80. To make it listen on 8080, you need to modify the Nginx
configuration inside the container. Here's how to update your Deployment:

1. Create a custom Nginx configuration file (`nginx.conf`):
   ```nginx
   server {
       listen 8080;
       location / {
           root /usr/share/nginx/html;
           index index.html index.htm;
       }
   }
   ```

2. Create a ConfigMap to store the Nginx configuration:
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

3. Update the Deployment to use the ConfigMap:
   Modify your Deployment in the YAML to mount the ConfigMap and use the custom configuration:
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

4. Apply the Updated Configuration:
   Save the updated YAML (including ConfigMap, Deployment, Service, and Ingress) to `nginx-k8s-deployment.yaml` and
   apply:
   ```bash
   kubectl apply -f nginx-k8s-deployment.yaml
   ```

### Updated Full YAML

Here’s the complete updated YAML with the Nginx configuration for port 8080:

```yaml
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
---
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

```

### Deployment and Cleanup Commands
1. **Deploy**:
   ```bash
   kubectl apply -f nginx-k8s-deployment.yaml
   ```

2. **Cleanup**:
   ```bash
   kubectl delete -f nginx-k8s-deployment.yaml
   ```

### Final Notes

- The Ingress Controller will still listen on port 80 (or 443 for HTTPS) unless explicitly reconfigured to use 8080, as
  described above.
- The updated YAML ensures the Nginx container listens on 8080, matching your Service and Ingress configuration.
- If you still see issues, check the Nginx pod logs:
  ```bash
  kubectl logs -l app=nginx
  ```
- Ensure your Ingress Controller is compatible with your Kubernetes version and properly configured.

If you need further assistance or want to force the Ingress Controller to use port 8080, let me know, and I can provide
additional guidance!


---

The issue you're encountering is that, even after deleting the `nginx-deployment`, `nginx-service`, and `nginx-ingress`
resources, you still see an Nginx response (a 404 page) when accessing `http://192.168.1.200`. This is because the
response is coming from the **Ingress Controller** itself (specifically, the `ingress-nginx-controller` service in the
`ingress-nginx` namespace), not from your previously deployed Nginx application.

Here’s a detailed explanation and steps to resolve or clarify the situation:

---

### Why This Happens

1. **Ingress Controller's Default Behavior**:
    - The `ingress-nginx-controller` service (type `LoadBalancer`, exposed via MetalLB at `192.168.1.200`) is running an
      Nginx-based Ingress Controller.
    - When you access `http://192.168.1.200`, you're hitting the Ingress Controller's Nginx instance, which listens on
      port 80 by default (as shown in `PORT(S) 80:30236/TCP`).
    - Since you deleted the `nginx-ingress` resource, there are no active Ingress rules to route traffic to your
      `nginx-service`. As a result, the Ingress Controller returns its default backend response, which is an Nginx 404
      page.

2. **MetalLB and External IP**:
    - MetalLB assigns the external IP `192.168.1.200` to the `ingress-nginx-controller` service, making it accessible
      from outside the cluster.
    - This IP is tied to the Ingress Controller, not your deleted `nginx-service`.

3. **No Residual Resources**:
    - You successfully deleted the `nginx-deployment`, `nginx-service`, and `navbar-ingress` resources, so they are no
      longer active.
    - The 404 response is not from your application but from the Ingress Controller's default backend.

---

### Verification

To confirm that the response is from the Ingress Controller:

1. **Check Running Pods**:
   Ensure no residual pods from your `nginx-deployment` are running:
   ```bash
   kubectl get pods -A -l app=nginx
   ```
   If no pods are listed, your application is fully deleted.

2. **Check Ingress Resources**:
   Verify no Ingress resources remain:
   ```bash
   kubectl get ingress -A
   ```
   If no `nginx-ingress` is listed, your Ingress is deleted.

3. **Inspect Ingress Controller Logs**:
   Check the logs of the Ingress Controller to see the 404 response:
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
   ```
   Look for entries indicating a 404 response for requests to `192.168.1.200`.

4. **Check Default Backend**:
   The Ingress Controller may have a default backend that serves the 404 page. To inspect:
   ```bash
   kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=default-backend
   ```
   If a default backend pod exists, it’s likely serving the 404 page.

---

### Resolving or Adjusting the Behavior

Depending on your goal, here are a few options:

#### Option 1: Accept the 404 as Expected Behavior

- The 404 response is the default behavior of the Ingress Controller when no Ingress rules match the request.
- If you don’t need to serve anything at `http://192.168.1.200` right now, this is fine. When you redeploy an Ingress
  resource (e.g., `nginx-ingress`), it will override the default 404 response and route traffic to your service.
- No action is needed unless you want to customize the default response (see Option 2).

#### Option 2: Customize the Default Backend

To replace the default 404 page with a custom response (e.g., a different page or service):

1. **Create a Custom Default Backend**:
   Create a simple Deployment and Service to serve a custom page:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: custom-default-backend
     namespace: ingress-nginx
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: custom-default-backend
     template:
       metadata:
         labels:
           app: custom-default-backend
       spec:
         containers:
         - name: backend
           image: nginx:latest
           ports:
           - containerPort: 80
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: custom-default-backend
     namespace: ingress-nginx
   spec:
     selector:
       app: custom-default-backend
     ports:
     - protocol: TCP
       port: 80
       targetPort: 80
   ```

2. **Configure Ingress Controller to Use Custom Backend**:
   Edit the Ingress Controller’s configuration to use the custom backend. This can be done by updating the `ConfigMap`
   for `ingress-nginx`:
   ```bash
   kubectl edit configmap -n ingress-nginx ingress-nginx-controller
   ```
   Add or update the `data` section:
   ```yaml
   data:
     custom-http-errors: "404,403,500,503"
     default-backend-service: "ingress-nginx/custom-default-backend"
   ```

3. **Apply and Test**:
   Apply the custom backend:
   ```bash
   kubectl apply -f custom-default-backend.yaml
   ```
   Restart the Ingress Controller to apply changes:
   ```bash
   kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
   ```
   Test by accessing `http://192.168.1.200`. You should see the default Nginx welcome page (or customize the content in
   the backend).

#### Option 3: Disable the Ingress Controller

If you don’t need the Ingress Controller running (e.g., temporarily), you can scale it down or delete it:

1. **Scale Down Ingress Controller**:
   ```bash
   kubectl scale deployment -n ingress-nginx ingress-nginx-controller --replicas=0
   ```
   This stops the Ingress Controller pods, and `http://192.168.1.200` will no longer respond.

2. **Delete Ingress Controller**:
   If you want to completely remove the Ingress Controller:
   ```bash
   kubectl delete -n ingress-nginx deploy/ingress-nginx-controller svc/ingress-nginx-controller
   ```
   Note: This will also remove the MetalLB-assigned IP (`192.168.1.200`) until the service is recreated.

   To reinstall later, reapply the nginx-ingress deployment:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   ```

#### Option 4: Redeploy Your Nginx Application

If you want to restore your Nginx application and have it respond at `http://192.168.1.200:8080`, reapply the updated
YAML configuration from our previous discussion. However, note that the Ingress Controller will still listen on port
80 (not 8080) unless reconfigured.

Here’s a recap of the corrected YAML (with Nginx configured to listen on 8080):

```yaml
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
---
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

```

**Deploy**:
```bash
kubectl apply -f nginx-k8s-deployment.yaml
```

**Test**:
Access `http://192.168.1.200/`. The Ingress Controller (on port 80) will route traffic to your `nginx-service` on port
8080, and you should see the Nginx welcome page.

**Cleanup** (if needed):

```bash
kubectl delete -f nginx-k8s-deployment.yaml
```

#### Option 5: Make Ingress Controller Listen on Port 8080

If you specifically want the Ingress Controller to listen on port 8080 (instead of 80), you can modify the
`ingress-nginx-controller` Service:

1. **Edit the Service**:
   ```bash
   kubectl edit svc -n ingress-nginx ingress-nginx-controller
   ```
   Change the HTTP port from 80 to 8080:
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

2. **Restart Ingress Controller**:
   ```bash
   kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
   ```

3. **Test**:
   Access `http://192.168.1.200:8080/`. The Ingress Controller will now listen on 8080, and requests will be routed to
   your `nginx-service` (if redeployed).

4. **Note**:
    - MetalLB will still assign `192.168.1.200`, but the port will be 8080.
    - Ensure your firewall or network allows traffic on port 8080.
    - This is non-standard, so confirm it aligns with your requirements.

---

### Recommended Action

Since the 404 page is coming from the Ingress Controller’s default backend and your application resources are
successfully deleted, the simplest solution depends on your goal:

- If you want to restore your Nginx service, redeploy the YAML above and access it via `http://192.168.1.200/` (Ingress
  Controller on port 80 routing to Service on 8080).
- If you want to eliminate the 404 page, configure a custom default backend (Option 2) or scale down the Ingress
  Controller (Option 3).
- If you specifically need the Ingress Controller on port 8080, follow Option 5.

For most use cases, redeploying the application (Option 4) is the best approach, as it restores your intended
functionality without altering the standard Ingress Controller behavior.

---

### Debugging Tips

If you encounter issues:

1. **Check Ingress Controller Status**:
   ```bash
   kubectl get pods -n ingress-nginx
   ```
   Ensure the Ingress Controller pods are running without errors.

2. **Test Service Directly** (if redeployed):
   Use `kubectl port-forward` to bypass the Ingress Controller:
   ```bash
   kubectl port-forward svc/nginx-service 8080:8080
   ```
   Access `http://localhost:8080` to verify the Nginx service.

3. **Check MetalLB**:
   Ensure MetalLB is assigning the IP correctly:
   ```bash
   kubectl get ipaddresspool -n metallb-system
   kubectl get l2advertisement -n metallb-system
   ```

4. **Network Access**:
   Verify that `192.168.1.200` is reachable and no firewall is blocking port 80 (or 8080 if reconfigured).

---

If you need further assistance, such as customizing the default backend, changing the Ingress Controller port, or
debugging specific errors, please let me know!