Video: https://www.bilibili.com/video/BV13DdoYhE1F/?vd_source=8199c71e52e7af8b17093229c514230d

---

```bash
$ sudo k8s kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.152.183.101   192.168.1.200   80:30236/TCP,443:32580/TCP   10d
ingress-nginx-controller-admission   ClusterIP      10.152.183.135   <none>          443/TCP                      10d
```

---

应用配置：

```bash
$ sudo k8s kubectl apply -f nginx-k8s-deployment.yaml
configmap/nginx-config created
deployment.apps/nginx-deployment created
service/nginx-service created
Warning: annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
ingress.networking.k8s.io/nginx-ingress created
```

---

访问服务：

```bash
$ curl http://192.168.1.200
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

---

删除service:

```bash
$ sudo k8s kubectl delete -f nginx-k8s-deployment.yaml
configmap "nginx-config" deleted
deployment.apps "nginx-deployment" deleted
service "nginx-service" deleted
ingress.networking.k8s.io "nginx-ingress" deleted
```

---

确认删除：

```bash
$ curl http://192.168.1.200
<html>
<head><title>503 Service Temporarily Unavailable</title></head>
<body>
<center><h1>503 Service Temporarily Unavailable</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

---

## 通过path访问群集内部两个不同服务

```bash
anan@think:~/works/k8s-example/ingress-example$ sudo k8s kubectl apply -f multi-service-ingress-by-path.yaml
deployment.apps/nginx-deployment created
service/nginx-service created
deployment.apps/other-deployment created
service/other-service created
Warning: annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
ingress.networking.k8s.io/multi-service-ingress created
```

---

```bash
anan@think:~/works/k8s-example/ingress-example$ curl -H "Host: example.com" http://192.168.1.200/nginx
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
---

```bash
anan@think:~/works/k8s-example/ingress-example$ curl -H "Host: example.com" http://192.168.1.200/other
Hello from Other Service!
```

---

```bash
$ sudo k8s kubectl delete -f multi-service-ingress-by-path.yaml

deployment.apps "nginx-deployment" deleted
service "nginx-service" deleted
deployment.apps "other-deployment" deleted
service "other-service" deleted
ingress.networking.k8s.io "multi-service-ingress" deleted
```

---

## 通过子域名访问群集内的不同服务

```bash
$ sudo k8s kubectl apply -f subdomain-ingress.yaml
deployment.apps/nginx-deployment created
service/nginx-service created
deployment.apps/other-deployment created
service/other-service created
Warning: annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
ingress.networking.k8s.io/subdomain-ingress created
```

---

```bash
anan@think:~/works/k8s-example/ingress-example$ curl -H "Host: nginx.example.com" http://192.168.1.200
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

---


```bash
anan@think:~/works/k8s-example/ingress-example$ curl -H "Host: other.example.com" http://192.168.1.200
Hello from Other Service!
```

---

```bash
$ sudo k8s kubectl delete -f subdomain-ingress.yaml
deployment.apps "nginx-deployment" deleted
service "nginx-service" deleted
deployment.apps "other-deployment" deleted
service "other-service" deleted
ingress.networking.k8s.io "subdomain-ingress" deleted
```