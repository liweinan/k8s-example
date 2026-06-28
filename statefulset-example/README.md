# StatefulSet 手把手示例：Pod IP 会变，DNS 名不变

在 [vagrant-demo](../../vagrant-demo/) 单节点 kubeadm 集群上演示 StatefulSet 的核心特性：**Pod 名字和 DNS 域名稳定**，即使删除 Pod 后 IP 变了，仍可通过同一域名访问。

## 前提

- 集群已就绪（`kubectl get nodes` 显示 `Ready`）
- 已配置 kubeconfig：

```bash
export KUBECONFIG=/Volumes/ExternalData/vagrant-demo/kubeconfig/config
# 或本项目路径：
# export KUBECONFIG=../../vagrant-demo/kubeconfig/config

kubectl get nodes
```

## 架构

```
                    Headless Service (web-headless)
                    clusterIP: None
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
      web-0             web-1             web-2
   (Pod IP 会变)     (Pod IP 会变)     (Pod IP 会变)
         │                 │                 │
   web-0.web-headless   web-1.web-headless   web-2.web-headless
   .default.svc...      .default.svc...      .default.svc...
         ↑
    DNS 名固定，始终指向当前 web-0 的 Pod IP
```

| 对比 | Deployment | StatefulSet |
|------|------------|-------------|
| Pod 名 | 随机后缀 `nginx-7d8f9-abc12` | 固定序号 `web-0`、`web-1` |
| 网络标识 | 靠 Service 负载均衡 | 每个 Pod 有独立稳定 DNS |
| 删除 Pod 后 | 新 Pod 新名字 | **同名 Pod 重建** |

## 文件说明

| 文件 | 作用 |
|------|------|
| `headless-service.yaml` | Headless Service（`clusterIP: None`），为每个 Pod 注册 DNS A 记录 |
| `statefulset.yaml` | 3 副本 nginx StatefulSet |
| `test.sh` | 一键演示：创建 → 删 Pod → 验证 DNS |

---

## 手把手操作

### 第 1 步：进入示例目录

```bash
cd k8s-example/statefulset-example
```

### 第 2 步：创建 Headless Service

```bash
kubectl apply -f headless-service.yaml
kubectl get svc web-headless
```

预期：`CLUSTER-IP` 为 `None`。

### 第 3 步：创建 StatefulSet

```bash
kubectl apply -f statefulset.yaml
kubectl get statefulset web
```

观察 Pod **按顺序**启动（先 `web-0`，再 `web-1`，再 `web-2`）：

```bash
kubectl get pods -l app=web -w
# Ctrl+C 退出 watch

# 或等待 3 个副本全部 Ready
kubectl wait --for=jsonpath='{.status.readyReplicas}'=3 statefulset/web --timeout=180s
```

全部 Running 后查看 IP：

```bash
kubectl get pods -l app=web -o wide
```

示例输出：

```
NAME    READY   STATUS    RESTARTS   AGE   IP             NODE
web-0   1/1     Running   0          30s   192.168.1.10   k8s-master
web-1   1/1     Running   0          20s   192.168.1.11   k8s-master
web-2   1/1     Running   0          10s   192.168.1.12   k8s-master
```

（IP 因 Calico 分配而异，以实际为准。）

### 第 4 步：理解稳定 DNS 名

每个 Pod 的 DNS 格式：

```
<pod名>.<service名>.<命名空间>.svc.cluster.local
```

本例中：

| Pod | DNS 名 |
|-----|--------|
| web-0 | `web-0.web-headless.default.svc.cluster.local` |
| web-1 | `web-1.web-headless.default.svc.cluster.local` |
| web-2 | `web-2.web-headless.default.svc.cluster.local` |

在集群内测试解析（临时 debug Pod）：

```bash
kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 \
  -- nslookup web-0.web-headless.default.svc.cluster.local
```

`Address` 应与 `kubectl get pod web-0 -o wide` 中的 `IP` 一致。

### 第 5 步：停掉 Pod（删除 web-0）

```bash
# 记录当前 IP
kubectl get pod web-0 -o wide

OLD_IP=$(kubectl get pod web-0 -o jsonpath='{.status.podIP}')
echo "删除前 IP: $OLD_IP"

# 删除 Pod（StatefulSet 会自动重建同名 Pod）
kubectl delete pod web-0

# 等待重建
kubectl wait --for=condition=Ready pod/web-0 --timeout=120s
kubectl get pod web-0 -o wide
```

### 第 6 步：对比 IP 与 DNS

```bash
NEW_IP=$(kubectl get pod web-0 -o jsonpath='{.status.podIP}')
echo "删除后 IP: $NEW_IP"
echo "DNS 名不变: web-0.web-headless.default.svc.cluster.local"
```

- **Pod 名**：仍是 `web-0`（不是随机新名字）
- **Pod IP**：通常已变化（`$OLD_IP` ≠ `$NEW_IP`）
- **DNS 名**：仍是 `web-0.web-headless.default.svc.cluster.local`

再次解析 DNS，确认指向**新 IP**（CoreDNS 可能延迟几秒更新）：

```bash
kubectl run dns-test2 --rm -i --restart=Never --image=busybox:1.36 \
  -- sh -c 'nslookup web-0.web-headless.default.svc.cluster.local && wget -qO- http://web-0.web-headless.default.svc.cluster.local/ | head -5'
```

若 `nslookup` 仍指向旧 IP，等 5～10 秒再试一次。

### 第 7 步：一键跑完整演示（可选）

```bash
chmod +x test.sh
./test.sh
```

---

## 与 Deployment 的对比实验（可选）

若用 Deployment，删 Pod 后名字会变：

```bash
kubectl create deployment demo --image=nginx:1.25-alpine
kubectl get pods -l app=demo
# 记下名字，例如 demo-6d8f9c-abc12

kubectl delete pod demo-6d8f9c-abc12
kubectl get pods -l app=demo
# 新 Pod 名字不同，例如 demo-6d8f9c-xyz99

kubectl delete deployment demo
```

StatefulSet 则始终保留 `web-0` 这个名字。

---

## 清理

```bash
kubectl delete -f statefulset.yaml
kubectl delete -f headless-service.yaml
```

---

## 常见问题

| 现象 | 处理 |
|------|------|
| Pod 一直 Pending | `kubectl describe pod web-0`；确认节点 Ready |
| 镜像拉取失败 | 在 VM 内开代理：`../../vagrant-demo/bin/guest-proxy.sh on` |
| `nslookup` 失败 | 确认 CoreDNS 运行：`kubectl get pods -n kube-system -l k8s-app=kube-dns` |

## 相关文档

- [vagrant-demo 快速开始](../../vagrant-demo/README.md)
- [Master 节点构成](../../vagrant-demo/docs/master-node.md)
