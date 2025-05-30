# **Deploying a Minimal Kubernetes Service with NodePort Access**

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/liweinan/k8s-example)

This guide walks you through deploying a simple Nginx web server on Kubernetes and exposing it via **NodePort** for
external access.

---

## **Prerequisites**

✅ A running Kubernetes cluster (Minikube, Kind, or cloud-based like EKS/GKE)  
✅ `kubectl` installed and configured

---

## **Step 1: Create a Deployment**

Deploy a simple **Nginx** container using a `Deployment`:

### **deployment.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
            - containerPort: 80
```

**Apply the deployment:**

```bash
kubectl apply -f deployment.yaml
```

**Verify the pod is running:**

```bash
kubectl get pods
```

Expected output:

```
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-5c689d88bb-r2xvq   1/1     Running   0          10s
```

---

## **Step 2: Expose the Service via NodePort**

Now, expose the deployment using a **NodePort** service:

### **service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80          # Service port (cluster-internal)
      targetPort: 80    # Pod port (matches `containerPort`)
      nodePort: 30000   # Manually chosen port (30000-32767)
```

**Apply the service:**

```bash
kubectl apply -f service.yaml
```

**Check the service:**

```bash
kubectl get svc
```

Expected output:

```
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx-service   NodePort   10.96.123.123   <none>        80:30000/TCP   5s
```

---

## **Step 3: Access the Service**

### **If using Minikube/Kind:**

```bash
minikube service nginx-service --url  # Automatically opens in browser
```

or

```bash
curl http://$(minikube ip):30000
```

### **If using a cloud provider (e.g., AWS/GCP):**

Find a worker node’s **public IP** and access:

```bash
curl http://<NODE_PUBLIC_IP>:30000
```

> **Note:** Ensure security groups/firewalls allow traffic on port `30000`.

---

## **Step 4: Verify Nginx is Running**

You should see the default Nginx welcome page:

```
Welcome to nginx!
...
```

---

## **Step 5: Clean Up**

```bash
kubectl delete -f deployment.yaml -f service.yaml
```

---

## **Key Concepts**

| Component | Purpose |
|-----------|---------|
| **Deployment** | Manages pod replicas (ensures availability). |
| **Service (NodePort)** | Exposes pods on a static port across all cluster nodes. |
| **nodePort** | External port (30000-32767) accessible on worker nodes. |

---

## **Troubleshooting**

❌ **"Connection refused"?**  
→ Check if the pod is running (`kubectl get pods`).  
→ Ensure `nodePort` is within `30000-32767`.

❌ **No response from `curl`?**  
→ Check firewall rules (cloud providers often block NodePort by default).

---

### **Next Steps**

- Try **LoadBalancer** (for cloud providers).
- Use **Ingress** for HTTP/HTTPS routing.

Let me know if you need further customizations! 🚀

---

https://documentation.ubuntu.com/canonical-kubernetes/main/snap/howto/networking/proxy/

---

# **Getting the Node IP in MicroK8s (Canonical Kubernetes)**

To get the **Node IP** (the IP address of your MicroK8s node), you can use several methods:

---

## **Method 1: Using `kubectl` (Recommended)**

```bash
microk8s kubectl get nodes -o wide
```

**Output Example:**

```
NAME      STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE       KERNEL-VERSION     CONTAINER-RUNTIME
ubuntu    Ready    <none>   2d    v1.28.1   192.168.1.100   <none>        Ubuntu 22.04   5.15.0-76-generic  containerd://1.7.2
```

- **`INTERNAL-IP`** is your node's IP (e.g., `192.168.1.100`).

---

## **Method 2: Using `hostname` (If Node IP = Host IP)**

```bash
hostname -I | awk '{print $1}'
```

**Output Example:**

```
192.168.1.100
```

---

## **Method 3: Using `microk8s inspect`**

```bash
microk8s inspect | grep -A5 "Network"
```

**Output Example:**

```
Network:
  Host: 192.168.1.100
  Service subnet: 10.152.183.0/24
  Pod subnet: 10.1.0.0/16
```

- **`Host`** is your node's IP.

---

## **Method 4: Using `ifconfig` or `ip`**

```bash
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1
```

**Output Example:**

```
192.168.1.100
10.0.2.15
```

- The first non-loopback IP (`192.168.1.100`) is usually your node's IP.

---

## **Method 5: Using `kubectl describe node`**

```bash
microk8s kubectl describe node | grep "InternalIP"
```

**Output Example:**

```
InternalIP:  192.168.1.100
```

---

## **When to Use Which Method?**

| Method | Best For | Notes |
|--------|----------|-------|
| `kubectl get nodes -o wide` | Most reliable (K8s-native) | Shows `INTERNAL-IP` |
| `hostname -I` | Quick check (if host = node) | Works if no NAT |
| `microk8s inspect` | Debugging MicroK8s network | Shows host IP |
| `ip addr` | Manual network inspection | Multiple IPs may appear |
| `kubectl describe node` | Detailed node info | Includes `InternalIP` |

---

## **Common Use Cases**

1. **Accessing a `NodePort` Service**
    - If you exposed a service on `NodePort`, use the node IP to access it:
      ```
      http://<NODE_IP>:30000
      ```

2. **Joining Nodes in HA Mode**
    - When adding nodes to a cluster, you need the primary node's IP:
      ```bash
      microk8s add-node  # On the primary node
      microk8s join <PRIMARY_NODE_IP>:25000/<TOKEN>  # On worker nodes
      ```

3. **Debugging Network Issues**
    - Check if the node IP is reachable:
      ```bash
      ping <NODE_IP>
      ```

---

## **Troubleshooting**

❌ **No `INTERNAL-IP` in `kubectl get nodes`?**

- Ensure `kubelet` is running:
  ```bash
  sudo systemctl status snap.microk8s.daemon-kubelet
  ```
- Check network plugins:
  ```bash
  microk8s enable metallb  # If using LoadBalancer
  ```

❌ **Multiple IPs? Which one to use?**

- Prefer the **private IP** (e.g., `192.168.x.x`, `10.x.x.x`) over public IPs.

---

### **Final Tip**

For most cases, **`microk8s kubectl get nodes -o wide`** is the best way to get the node IP. Let me know if you need
further help! 🚀


---

# **How to Log Into a Kubernetes Pod (Shell Access)**

To log into a running Kubernetes pod, you can use `kubectl exec`. Here are the most common methods:

---

## **1. Basic Shell Access**

### **Start an Interactive Shell**

```bash
kubectl exec -it <pod-name> -- /bin/bash
```

- **`-it`** = Interactive terminal
- **`/bin/bash`** = Default shell (use `/bin/sh` if Bash is unavailable)

**Example:**

```bash
kubectl exec -it nginx-pod-123 -- /bin/bash
```

### **If the Pod Has No Bash**

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

---

## **2. Specify Container (Multi-Container Pods)**

If the pod has multiple containers, specify which one to access:

```bash
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
```

**Example:**

```bash
kubectl exec -it myapp-pod -c sidecar-container -- /bin/sh
```

---

## **3. Run a Single Command Instead of Shell**

```bash
kubectl exec <pod-name> -- <command>
```

**Examples:**

```bash
kubectl exec nginx-pod -- ls /var/log
kubectl exec redis-pod -- redis-cli ping
```

---

## **4. Debugging Tools (If No Shell Exists)**

If the pod lacks `bash`/`sh`, use debugging images like `busybox`:

```bash
kubectl debug -it <pod-name> --image=busybox --target=<container-name> -- /bin/sh
```

**Example:**

```bash
kubectl debug -it nginx-pod --image=busybox --target=nginx -- /bin/sh
```

---

## **5. Using `kubectl attach` (For Running Processes)**

Attach to an existing process (e.g., a running service):

```bash
kubectl attach -it <pod-name>
```

**Note:** Only works if the pod has an interactive process.

---

## **6. Temporary Debug Pod (Ephemeral Containers)**

For pods that can't be exec'd into (e.g., crash loops):

```bash
kubectl debug <pod-name> -it --image=alpine --share-processes --copy-to=debug-pod
```

**Example:**

```bash
kubectl debug nginx-pod -it --image=alpine --share-processes --copy-to=nginx-debug
```

---

## **Troubleshooting**

❌ **"Error: Unable to use a TTY"**  
→ Remove `-it`:

```bash
kubectl exec <pod-name> -- /bin/bash
```

❌ **"OCI runtime exec failed: exec failed"**  
→ The container may not have a shell. Use `kubectl debug` instead.

❌ **Pod is CrashLooping**  
→ Use an ephemeral debug container:

```bash
kubectl debug <pod-name> -it --image=busybox --copy-to=debug-pod
```

---

## **Summary Table**

| Method | Command | Use Case |
|--------|---------|----------|
| **Basic shell** | `kubectl exec -it <pod> -- /bin/bash` | Most common |
| **Multi-container** | `kubectl exec -it <pod> -c <container> -- /bin/sh` | Sidecars |
| **Run command** | `kubectl exec <pod> -- ls /tmp` | Quick checks |
| **Debug tool** | `kubectl debug -it <pod> --image=busybox -- /bin/sh` | No shell |
| **Attach** | `kubectl attach -it <pod>` | Attach to process |

---

### **Pro Tips**

1. **Shortcut**: Alias `kubectl` to `k` for faster access:
   ```bash
   alias k='kubectl'
   k exec -it nginx-pod -- bash
   ```
2. **Pod Autocomplete**: Enable it for easier pod name typing:
   ```bash
   source <(kubectl completion bash)
   ```

Let me know if you need help debugging a specific pod! 🐞

---

# **Default Container Selection When Logging Into a Pod**

When you run `kubectl exec -it <pod> -- /bin/bash` **without specifying a container**, Kubernetes follows these rules to
determine which container to log into:

## **1. Single-Container Pods**

- If the pod has **only one container**, that container is automatically selected.  
  **Example:**
  ```bash
  kubectl exec -it mypod -- /bin/bash  # Logs into the only container
  ```

## **2. Multi-Container Pods**

If the pod has **multiple containers**, Kubernetes selects the **first container** (alphabetically by name) unless:

- The pod has a **`kubectl.kubernetes.io/default-container` annotation** (Kubernetes v1.22+).
- You explicitly specify a container with `-c <container-name>`.

### **Example: Pod with Two Containers**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: app       # Alphabetically first ("a" comes before "log")
      image: nginx
    - name: log-agent
      image: fluentd
```

Running:

```bash
kubectl exec -it mypod -- /bin/bash
```

→ Logs into **`app`** (first container in alphabetical order).

---

## **3. How to Control the Default Container**

### **Option 1: Use `-c` to Specify Container**

```bash
kubectl exec -it mypod -c log-agent -- /bin/sh
```

### **Option 2: Set a Default Container (Kubernetes v1.22+)**

Add an annotation to the pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
  annotations:
    kubectl.kubernetes.io/default-container: "log-agent"  # Forces default
spec:
  containers:
    - name: app
      image: nginx
    - name: log-agent
      image: fluentd
```

Now:

```bash
kubectl exec -it mypod -- /bin/sh  # Logs into `log-agent`
```

### **Option 3: Use `kubectl.kubernetes.io/default-container` in Commands**

```bash
kubectl exec -it mypod --container=log-agent -- /bin/sh
```

---

## **Key Takeaways**

| Scenario | Behavior |
|----------|----------|
| **Single-container pod** | Automatically logs into that container. |
| **Multi-container pod** | Picks the **first container alphabetically** (unless default is set). |
| **Explicit selection** | Use `-c <container>` to override. |
| **K8s ≥v1.22** | Use `kubectl.kubernetes.io/default-container` annotation. |

---

## **Troubleshooting**

❌ **"Default container not found"**  
→ Check container names:

```bash
kubectl get pod mypod -o jsonpath='{.spec.containers[*].name}'
```

❌ **"No such container"**  
→ Verify the container exists:

```bash
kubectl describe pod mypod | grep -A10 "Containers:"
```

---

### **Best Practice**

Always **specify the container** (`-c`) in multi-container pods to avoid surprises:

```bash
kubectl exec -it mypod -c log-agent -- /bin/sh
``` 

Let me know if you need help debugging a specific pod! 🚀
