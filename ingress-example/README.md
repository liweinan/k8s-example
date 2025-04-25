Video: https://www.bilibili.com/video/BV13DdoYhE1F/?vd_source=8199c71e52e7af8b17093229c514230d 

```bash
$ sudo k8s kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.152.183.101   192.168.1.200   80:30236/TCP,443:32580/TCP   10d
ingress-nginx-controller-admission   ClusterIP      10.152.183.135   <none>          443/TCP                      10d
```