#!/bin/bash

# Sidecar 模式测试脚本

echo "=== Kubernetes Sidecar 模式测试 ==="

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl 未安装或不在 PATH 中"
    exit 1
fi

# 部署资源
echo "1. 部署 Pod 和 Service..."
kubectl apply -f sidecar-pod.yaml
kubectl apply -f service.yaml

# 等待 Pod 就绪
echo "2. 等待 Pod 启动..."
kubectl wait --for=condition=Ready pod/sidecar-example --timeout=60s

if [ $? -ne 0 ]; then
    echo "错误: Pod 启动超时"
    kubectl describe pod sidecar-example
    exit 1
fi

# 获取 Pod IP
POD_IP=$(kubectl get pod sidecar-example -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"

# 测试主应用
echo "3. 测试主应用..."
echo "测试主应用根路径:"
curl -s http://$POD_IP:8080/ | jq .

echo -e "\n测试主应用健康检查:"
curl -s http://$POD_IP:8080/health | jq .

# 测试 Sidecar
echo -e "\n4. 测试 Sidecar..."
echo "测试 Sidecar 根路径:"
curl -s http://$POD_IP:8081/ | jq .

echo -e "\n测试 Sidecar 日志收集:"
curl -s http://$POD_IP:8081/logs | jq .

echo -e "\n测试 Sidecar 指标:"
curl -s http://$POD_IP:8081/metrics | jq .

# 检查共享存储
echo -e "\n5. 检查共享存储中的日志文件:"
kubectl exec sidecar-example -c main-app -- ls -la /shared/logs/ 2>/dev/null || echo "日志目录不存在"

# 显示容器日志
echo -e "\n6. 显示容器日志:"
echo "主应用容器日志:"
kubectl logs sidecar-example -c main-app --tail=5

echo -e "\nSidecar 容器日志:"
kubectl logs sidecar-example -c sidecar --tail=5

# 测试容器间通信
echo -e "\n7. 测试容器间通信:"
echo "从 Sidecar 容器访问主应用:"
kubectl exec sidecar-example -c sidecar -- curl -s http://localhost:8080/health | jq .

echo -e "\n从主应用容器访问 Sidecar:"
kubectl exec sidecar-example -c main-app -- curl -s http://localhost:8081/ | jq .

echo -e "\n=== 测试完成 ==="
echo "要清理资源，请运行:"
echo "kubectl delete -f service.yaml"
echo "kubectl delete -f sidecar-pod.yaml"
