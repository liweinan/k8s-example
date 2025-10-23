#!/bin/bash

# Sidecar 模式测试脚本

echo "=== Kubernetes Sidecar 模式测试 ==="

# 定义 k 函数（如果不存在）
if ! type k &> /dev/null; then
    k() {
        sudo k8s kubectl "$@"
    }
fi

# 设置 kubectl 命令
KUBECTL_CMD="k"

# 检查 kubectl 是否可用（兼容命令、函数、别名等）
if ! type $KUBECTL_CMD &> /dev/null; then
    echo "错误: $KUBECTL_CMD 未找到（可能是命令、函数或别名）"
    exit 1
fi

# 部署资源
echo "1. 部署 Pod 和 Service..."
$KUBECTL_CMD apply -f deployment.yaml
$KUBECTL_CMD apply -f service.yaml

# 等待 Pod 就绪
echo "2. 等待 Pod 启动..."
$KUBECTL_CMD wait --for=condition=Ready pod/sidecar-example --timeout=60s

if [ $? -ne 0 ]; then
    echo "错误: Pod 启动超时"
    $KUBECTL_CMD describe pod sidecar-example
    exit 1
fi

# 获取 Service IP
SERVICE_IP=$($KUBECTL_CMD get svc sidecar-example-service -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SERVICE_IP"

# 测试主应用
echo "3. 测试主应用..."
echo "测试主应用根路径:"
curl -s --max-time 10 http://$SERVICE_IP:8080/ | jq .

echo -e "\n测试主应用健康检查:"
curl -s --max-time 10 http://$SERVICE_IP:8080/health | jq .

# 测试 Sidecar
echo -e "\n4. 测试 Sidecar..."
echo "测试 Sidecar 根路径:"
curl -s --max-time 10 http://$SERVICE_IP:8081/ | jq .

echo -e "\n测试 Sidecar 日志收集:"
curl -s --max-time 10 http://$SERVICE_IP:8081/logs | jq .

echo -e "\n测试 Sidecar 指标:"
curl -s --max-time 10 http://$SERVICE_IP:8081/metrics | jq .

# 检查共享存储
echo -e "\n5. 检查共享存储中的日志文件:"
$KUBECTL_CMD exec sidecar-example -c main-app -- ls -la /shared/logs/ 2>/dev/null || echo "日志目录不存在"

# 显示容器日志
echo -e "\n6. 显示容器日志:"
echo "主应用容器日志:"
$KUBECTL_CMD logs sidecar-example -c main-app --tail=5

echo -e "\nSidecar 容器日志:"
$KUBECTL_CMD logs sidecar-example -c sidecar --tail=5

# 测试容器间通信
echo -e "\n7. 测试容器间通信:"
echo "从 Sidecar 容器访问主应用:"
$KUBECTL_CMD exec sidecar-example -c sidecar -- curl -s http://localhost:8080/health | jq .

echo -e "\n从主应用容器访问 Sidecar:"
$KUBECTL_CMD exec sidecar-example -c main-app -- curl -s http://localhost:8081/ | jq .

echo -e "\n=== 测试完成 ==="
echo "要清理资源，请运行:"
echo "k delete -f service.yaml"
echo "k delete -f deployment.yaml"
