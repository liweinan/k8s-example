#!/bin/bash

# 设置脚本为出错时退出
set -e

# 清理现有镜像和 tar 文件
echo "清理现有 go-runner 镜像和 pod-test.tar..."
rm pod-test.tar 2>/dev/null || true
ctr image rm gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0 2>/dev/null || true

# 拉取 go-runner 镜像，仅限 linux/amd64 平台
echo "拉取 go-runner 镜像（仅限 linux/amd64 平台）..."
if ! ctr image pull --platform linux/amd64 gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0; then
    echo "错误：无法拉取 go-runner 镜像，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

# 验证镜像是否成功拉取
echo "验证 go-runner 镜像是否成功拉取..."
if ! ctr image ls | grep -q gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0; then
    echo "错误：go-runner 镜像未找到，尝试重新拉取..."
    ctr image rm gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0 2>/dev/null || true
    if ! ctr image pull --platform linux/amd64 gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0; then
        echo "错误：重新拉取 go-runner 镜像失败，请检查网络、代理设置或镜像是否存在。"
        exit 1
    fi
    if ! ctr image ls | grep -q gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0; then
        echo "错误：go-runner 镜像仍未找到，请检查 containerd 状态。"
        exit 1
    fi
fi

# 导出镜像到 pod-test.tar
echo "导出 go-runner 镜像到 pod-test.tar..."
ctr image export pod-test.tar gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0

# 导入镜像到 k8s.io 命名空间
echo "导入 pod-test.tar 到 k8s.io 命名空间..."
ctr -n k8s.io image import pod-test.tar

# 验证镜像是否成功导入
echo "验证镜像是否导入到 k8s.io 命名空间..."
ctr -n k8s.io image ls | grep gcr.io/k8s-staging-build-image/go-runner:v2.4.0-go1.22.12-bookworm.0 || { echo "错误：镜像未成功导入到 k8s.io 命名空间"; exit 1; }

# 清理 tar 文件
echo "清理 pod-test.tar..."
rm pod-test.tar

echo "go-runner 镜像处理完成！"
