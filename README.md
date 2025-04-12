# **Deploying a Minimal Kubernetes Service with NodePort Access**

This guide walks you through deploying a simple Nginx web server on Kubernetes and exposing it via **NodePort** for external access.

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
# k8s-example
# k8s-example
