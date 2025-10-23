#!/bin/bash

# 构建 Sidecar 示例的 Docker 镜像

echo "=== 构建 Sidecar 示例 Docker 镜像 ==="

# 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装或不在 PATH 中"
    exit 1
fi

# 代理设置说明
echo "注意: 如果遇到网络问题，请配置 Docker 代理:"
echo "  export HTTP_PROXY=http://your-proxy:port"
echo "  export HTTPS_PROXY=http://your-proxy:port"
echo ""

# 构建主应用镜像
echo "1. 构建主应用镜像..."
# 如果需要代理，取消注释下面这行并设置正确的代理地址
docker build --build-arg HTTP_PROXY=http://squid.corp.redhat.com:3128 --build-arg HTTPS_PROXY=http://squid.corp.redhat.com:3128 -f Dockerfile.main-app -t sidecar-main-app:latest .
# docker build -f Dockerfile.main-app -t sidecar-main-app:latest .

if [ $? -ne 0 ]; then
    echo "错误: 主应用镜像构建失败"
    echo "提示: 如果遇到网络问题，请配置代理或使用 --build-arg 参数"
    exit 1
fi

# 构建 Sidecar 镜像
echo "2. 构建 Sidecar 镜像..."
# 如果需要代理，取消注释下面这行并设置正确的代理地址
docker build --build-arg HTTP_PROXY=http://squid.corp.redhat.com:3128 --build-arg HTTPS_PROXY=http://squid.corp.redhat.com:3128 -f Dockerfile.sidecar -t sidecar-sidecar:latest .
# docker build -f Dockerfile.sidecar -t sidecar-sidecar:latest .

if [ $? -ne 0 ]; then
    echo "错误: Sidecar 镜像构建失败"
    echo "提示: 如果遇到网络问题，请配置代理或使用 --build-arg 参数"
    exit 1
fi

# 显示构建的镜像
echo "3. 构建完成，显示镜像列表:"
docker images | grep sidecar

echo -e "\n=== 镜像构建完成 ==="
echo "现在可以使用以下命令部署:"
echo "kubectl apply -f deployment.yaml"
echo "kubectl apply -f service.yaml"
