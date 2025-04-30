```bash
$ sudo k8s kubectl apply -f simpleapp-crd.yaml
[sudo] password for anan:
customresourcedefinition.apiextensions.k8s.io/simpleapps.example.com created
```

---

```bash
$ sudo k8s kubectl get crd simpleapps.example.com
NAME                     CREATED AT
simpleapps.example.com   2025-04-30T03:19:40Z
```

---

```bash
$ sudo k8s kubectl apply -f simpleapp-instance.yaml
simpleapp.example.com/my-simple-app created
```

---

```bash
$ sudo k8s kubectl get sapp -n default
NAME            AGE
my-simple-app   6s
```

---

```bash
$ sudo k8s kubectl delete -f simpleapp-instance.yaml
sudo simpleapp.example.com "my-simple-app" deleted
```

---

```bash
$ sudo k8s kubectl delete -f simpleapp-crd.yaml
customresourcedefinition.apiextensions.k8s.io "simpleapps.example.com" deleted
```