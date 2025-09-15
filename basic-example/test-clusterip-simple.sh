#!/bin/bash

# ClusterIP Service 测试脚本（简化版）
# 用于测试集群内部访问nginx服务

echo "=== ClusterIP Service 测试脚本 ==="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 设置kubectl命令（根据您的环境调整）
KUBECTL_CMD="sudo k8s kubectl"

# 检查kubectl是否可用
if ! $KUBECTL_CMD version --client &> /dev/null; then
    echo -e "${RED}错误: kubectl 命令未找到或无法访问${NC}"
    echo -e "${YELLOW}请确保k8s命令可用: sudo k8s kubectl version${NC}"
    exit 1
fi

echo -e "${GREEN}使用kubectl命令: $KUBECTL_CMD${NC}"
echo

echo -e "${BLUE}1. 检查nginx deployment状态...${NC}"
$KUBECTL_CMD get deployment nginx-deployment
echo

echo -e "${BLUE}2. 检查nginx pods状态...${NC}"
$KUBECTL_CMD get pods -l app=nginx
echo

echo -e "${BLUE}3. 创建ClusterIP Service...${NC}"
$KUBECTL_CMD apply -f clusterip-service.yaml
echo

echo -e "${BLUE}4. 验证ClusterIP Service状态...${NC}"
$KUBECTL_CMD get svc nginx-clusterip
echo

echo -e "${BLUE}5. 查看Service详细信息...${NC}"
$KUBECTL_CMD describe svc nginx-clusterip
echo

echo -e "${BLUE}6. 检查Service的Endpoints...${NC}"
$KUBECTL_CMD get endpoints nginx-clusterip
echo

echo -e "${BLUE}7. 创建测试Pod并测试ClusterIP访问...${NC}"
echo "正在创建测试Pod..."

# 创建测试Pod并执行测试
$KUBECTL_CMD run clusterip-test --image=busybox --rm -it --restart=Never -- /bin/sh -c "
echo '=== 在测试Pod内部执行测试 ==='
echo
echo '1. 测试DNS解析:'
nslookup nginx-clusterip
echo
echo '2. 测试网络连通性:'
nc -zv nginx-clusterip 80
echo
echo '3. 测试HTTP访问:'
wget -qO- http://nginx-clusterip
echo
echo '4. 测试完整域名访问:'
wget -qO- http://nginx-clusterip.default.svc.cluster.local
echo
echo '5. 查看DNS配置:'
cat /etc/resolv.conf
echo
echo '=== 测试完成 ==='
"

echo
echo -e "${BLUE}8. 清理测试资源...${NC}"
$KUBECTL_CMD delete svc nginx-clusterip
echo

echo -e "${GREEN}=== ClusterIP Service 测试完成 ===${NC}"
echo
echo -e "${YELLOW}说明:${NC}"
echo "- ClusterIP Service只能在集群内部访问"
echo "- 外部无法直接访问ClusterIP Service"
echo "- 使用Service名称进行DNS解析"
echo "- 支持负载均衡到多个Pod"
