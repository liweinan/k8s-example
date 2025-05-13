#!/bin/bash

# 设置脚本为出错时退出
set -e

# 定义 prow 命名空间
NAMESPACE="prow"

# 定义 prow-setup.yaml 文件路径
PROW_SETUP_FILE="./prow-setup.yaml"

# 定义 RBAC 文件路径
RBAC_FILE="./prow-rbac.yaml"

# 定义代理地址（默认值）
PROXY_IP=${1:-192.168.0.119}
PROXY_PORT=1080
PROXY="http://${PROXY_IP}:${PROXY_PORT}"

# 定义 NO_PROXY 设置，排除 Kubernetes API 服务器和服务 CIDR
NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# 定义等待超时时间（秒）
TIMEOUT=600  # 10 minutes to give Deck more time to start

# 打印开始信息
echo "开始清理 Prow 服务..."

# 创建 prow 命名空间（如果不存在）
echo "创建 prow 命名空间（如果不存在）..."
k8s kubectl get namespace $NAMESPACE &>/dev/null || k8s kubectl create namespace $NAMESPACE
echo "prow 命名空间已确保存在"

# 应用 RBAC 配置
echo "应用 RBAC 配置..."
if [ ! -f "$RBAC_FILE" ]; then
    echo "错误：$RBAC_FILE 文件不存在，请确保已创建该文件。"
    exit 1
fi
k8s kubectl apply -f "$RBAC_FILE"

# 验证 deck ServiceAccount 和 token Secret
echo "验证 deck ServiceAccount 是否创建..."
if ! k8s kubectl get serviceaccount -n $NAMESPACE deck --no-headers >/dev/null 2>&1; then
    echo "错误：deck ServiceAccount 未创建，请检查 prow-rbac.yaml 或集群状态。"
    k8s kubectl describe serviceaccount -n $NAMESPACE deck || echo "ServiceAccount 不存在。"
    exit 1
fi

echo "验证 deck-token Secret 是否创建..."
if ! k8s kubectl get secret -n $NAMESPACE deck-token --no-headers >/dev/null 2>&1; then
    echo "错误：deck-token Secret 未创建，请检查 prow-rbac.yaml 或集群状态。"
    k8s kubectl describe secret -n $NAMESPACE deck-token || echo "Secret 不存在。"
    exit 1
fi

# 删除所有 Deployment
echo "删除所有 Deployment..."
k8s kubectl delete deployment --all -n $NAMESPACE --ignore-not-found

# 删除所有 Service
echo "删除所有 Service..."
k8s kubectl delete service --all -n $NAMESPACE --ignore-not-found

# 删除所有 Pod
echo "删除所有 Pod..."
k8s kubectl delete pod --all -n $NAMESPACE --ignore-not-found

# 删除所有 ConfigMap（排除 kube-root-ca.crt）
echo "删除所有 ConfigMap（排除 kube-root-ca.crt）..."
CONFIGMAPS=$(k8s kubectl get configmap -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -v kube-root-ca.crt || true)
if [ -n "$CONFIGMAPS" ]; then
    echo "删除 ConfigMap：$CONFIGMAPS"
    k8s kubectl delete configmap $CONFIGMAPS -n $NAMESPACE
else
    echo "没有需要删除的 ConfigMap（已排除 kube-root-ca.crt）。"
fi

# 删除所有 Secret
echo "删除所有 Secret..."
k8s kubectl delete secret --all -n $NAMESPACE --ignore-not-found

# 删除旧的 CRD（如果存在）
echo "删除旧的 Prow CRD（如果存在）..."
k8s kubectl delete crd prowjobs.prow.k8s.io --ignore-not-found

# 验证清理结果
echo "验证清理结果..."
k8s kubectl get all -n $NAMESPACE
k8s kubectl get configmap -n $NAMESPACE
k8s kubectl get secret -n $NAMESPACE
k8s kubectl get crd prowjobs.prow.k8s.io --ignore-not-found

# 安装 Prow CRD
echo "应用本地 Prow CRD..."
CRD_FILE="./prowjob_crd.yaml"

if [ ! -f "$CRD_FILE" ]; then
    echo "错误：$CRD_FILE 文件不存在，请确保已创建该文件。"
    exit 1
fi

if [ ! -s "$CRD_FILE" ]; then
    echo "错误：$CRD_FILE 文件为空，请检查文件内容。"
    exit 1
fi

if ! grep -q "apiVersion: apiextensions.k8s.io/v1" "$CRD_FILE" || ! grep -q "kind: CustomResourceDefinition" "$CRD_FILE"; then
    echo "错误：$CRD_FILE 文件内容无效，缺少 apiVersion 或 kind。"
    exit 1
fi

k8s kubectl apply -f "$CRD_FILE"

# 验证 CRD 安装
echo "验证 Prow CRD 是否安装..."
k8s kubectl get crd prowjobs.prow.k8s.io

# 重新创建必要的 Secret 和 ConfigMap
echo "重新创建必要的 Secret 和 ConfigMap..."

k8s kubectl create secret -n $NAMESPACE generic hmac-token --from-file=hmac=./secret
k8s kubectl create secret -n $NAMESPACE generic github-token --from-file=github-token=./alchemy-prow-bot.2025-05-11.private-key.pem
k8s kubectl create configmap -n $NAMESPACE config --from-file=config.yaml=./config.yaml
k8s kubectl create configmap -n $NAMESPACE plugins --from-file=plugins.yaml=./plugins.yaml
k8s kubectl create configmap -n $NAMESPACE job-config --from-file=prow-jobs.yaml=./prow-jobs.yaml

# 验证 ConfigMap 是否创建成功
echo "验证 ConfigMap 是否创建..."
for CONFIGMAP in config plugins job-config; do
    if ! k8s kubectl get configmap -n $NAMESPACE $CONFIGMAP --no-headers >/dev/null 2>&1; then
        echo "错误：ConfigMap $CONFIGMAP 未创建，请检查文件是否存在或集群状态。"
        k8s kubectl describe configmap -n $NAMESPACE $CONFIGMAP || echo "ConfigMap 不存在。"
        exit 1
    fi
done

# 导入镜像到 k8s.io 命名空间
echo "导入镜像到 k8s.io 命名空间..."
export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY

# 拉取镜像
echo "拉取 Hook 镜像 gcr.io/k8s-prow/hook:ko-v20240805-37a08f946..."
if ! ctr image pull gcr.io/k8s-prow/hook:ko-v20240805-37a08f946; then
    echo "错误：无法拉取 Hook 镜像 gcr.io/k8s-prow/hook:ko-v20240805-37a08f946，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

echo "拉取 Deck 镜像 gcr.io/k8s-prow/deck:ko-v20240805-37a08f946..."
if ! ctr image pull gcr.io/k8s-prow/deck:ko-v20240805-37a08f946; then
    echo "错误：无法拉取 Deck 镜像 gcr.io/k8s-prow/deck:ko-v20240805-37a08f946，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

# 导出镜像
ctr image export hook.tar gcr.io/k8s-prow/hook:ko-v20240805-37a08f946
ctr image export deck.tar gcr.io/k8s-prow/deck:ko-v20240805-37a08f946
ctr -n k8s.io image import hook.tar
ctr -n k8s.io image import deck.tar
rm hook.tar deck.tar

echo "验证镜像是否导入到 k8s.io 命名空间..."
ctr -n k8s.io image ls | grep gcr.io/k8s-prow || echo "镜像未找到，请检查 ctr 命令是否成功执行"

# 重新应用 prow-setup.yaml
echo "重新应用 prow-setup.yaml..."
k8s kubectl apply -f $PROW_SETUP_FILE

# 验证 Hook 和 Deck Deployment 是否创建成功
echo "验证 Hook Deployment 是否创建..."
if ! k8s kubectl get deployment -n $NAMESPACE hook --no-headers >/dev/null 2>&1; then
    echo "错误：Hook Deployment 未创建，请检查 prow-setup.yaml 或集群状态。"
    k8s kubectl describe deployment -n $NAMESPACE hook || echo "Deployment 不存在。"
    exit 1
fi

echo "验证 Deck Deployment 是否创建..."
if ! k8s kubectl get deployment -n $NAMESPACE deck --no-headers >/dev/null 2>&1; then
    echo "错误：Deck Deployment 未创建，请检查 prow-setup.yaml 或集群状态。"
    k8s kubectl describe deployment -n $NAMESPACE deck || echo "Deployment 不存在。"
    exit 1
fi

# 等待 Pod 进入 Running 状态
echo "等待 Hook 和 Deck Pod 进入 Running 状态..."

# 等待 Hook Pod
echo "等待 Hook Pod..."
HOOK_TIMEOUT_COUNT=0
while true; do
    HOOK_POD=$(k8s kubectl get pods -n $NAMESPACE -l app=hook --no-headers -o custom-columns=":metadata.name" | head -n 1)
    if [ -n "$HOOK_POD" ]; then
        HOOK_STATUS=$(k8s kubectl get pod -n $NAMESPACE $HOOK_POD --no-headers -o custom-columns=":status.phase")
        HOOK_READY=$(k8s kubectl get pod -n $NAMESPACE $HOOK_POD --no-headers -o custom-columns=":status.containerStatuses[0].ready" | grep "true" || true)
        HOOK_CONDITION=$(k8s kubectl get pod -n $NAMESPACE $HOOK_POD --no-headers -o custom-columns=":status.conditions[?(@.type=='Ready')].status" | grep "False" || true)
        if [ "$HOOK_STATUS" = "Running" ] && [ -n "$HOOK_READY" ] && [ -z "$HOOK_CONDITION" ]; then
            echo "Hook Pod ($HOOK_POD) 已进入 Running 状态且 Ready"
            break
        else
            HOOK_CONTAINER_STATUS=$(k8s kubectl get pod -n $NAMESPACE $HOOK_POD --no-headers -o custom-columns=":status.containerStatuses[0].state" | grep "CrashLoopBackOff" || true)
            if [ -n "$HOOK_CONTAINER_STATUS" ]; then
                echo "错误：Hook Pod ($HOOK_POD) 处于 CrashLoopBackOff 状态，输出日志："
                k8s kubectl logs -n $NAMESPACE $HOOK_POD --tail=50
                k8s kubectl describe pod -n $NAMESPACE $HOOK_POD
                exit 1
            fi
            echo "Hook Pod ($HOOK_POD) 状态: $HOOK_STATUS, Ready: $HOOK_READY，等待中..."
        fi
    else
        echo "未找到 Hook Pod，等待中..."
        k8s kubectl get pods -n $NAMESPACE -l app=hook
    fi
    sleep 5
    HOOK_TIMEOUT_COUNT=$((HOOK_TIMEOUT_COUNT + 5))
    if [ $HOOK_TIMEOUT_COUNT -ge $TIMEOUT ]; then
        echo "错误：等待 Hook Pod 超时（${TIMEOUT}秒），请检查部署状态："
        k8s kubectl get pods -n $NAMESPACE
        k8s kubectl describe deployment -n $NAMESPACE hook
        exit 1
    fi
done

# 等待 Deck Pod
echo "等待 Deck Pod..."
DECK_TIMEOUT_COUNT=0
while true; do
    DECK_POD=$(k8s kubectl get pods -n $NAMESPACE -l app=deck --no-headers -o custom-columns=":metadata.name" | head -n 1)
    if [ -n "$DECK_POD" ]; then
        DECK_STATUS=$(k8s kubectl get pod -n $NAMESPACE $DECK_POD --no-headers -o custom-columns=":status.phase")
        DECK_READY=$(k8s kubectl get pod -n $NAMESPACE $DECK_POD --no-headers -o custom-columns=":status.containerStatuses[0].ready" | grep "true" || true)
        DECK_CONDITION=$(k8s kubectl get pod -n $NAMESPACE $DECK_POD --no-headers -o custom-columns=":status.conditions[?(@.type=='Ready')].status" | grep "False" || true)
        if [ "$DECK_STATUS" = "Running" ] && [ -n "$DECK_READY" ] && [ -z "$DECK_CONDITION" ]; then
            echo "Deck Pod ($DECK_POD) 已进入 Running 状态且 Ready"
            break
        else
            DECK_CONTAINER_STATUS=$(k8s kubectl get pod -n $NAMESPACE $DECK_POD --no-headers -o custom-columns=":status.containerStatuses[0].state" | grep "CrashLoopBackOff" || true)
            if [ -n "$DECK_CONTAINER_STATUS" ]; then
                echo "错误：Deck Pod ($DECK_POD) 处于 CrashLoopBackOff 状态，输出日志："
                k8s kubectl logs -n $NAMESPACE $DECK_POD --tail=50
                k8s kubectl describe pod -n $NAMESPACE $DECK_POD
                exit 1
            fi
            echo "Deck Pod ($DECK_POD) 状态: $DECK_STATUS, Ready: $DECK_READY，等待中..."
        fi
    else
        echo "未找到 Deck Pod，等待中..."
        k8s kubectl get pods -n $NAMESPACE -l app=deck
        # Describe the ReplicaSet to get more details
        REPLICASET=$(k8s kubectl get replicaset -n $NAMESPACE -l app=deck --no-headers -o custom-columns=":metadata.name" | head -n 1)
        if [ -n "$REPLICASET" ]; then
            echo "Deck ReplicaSet 状态："
            k8s kubectl describe replicaset -n $NAMESPACE $REPLICASET
        fi
    fi
    sleep 5
    DECK_TIMEOUT_COUNT=$((DECK_TIMEOUT_COUNT + 5))
    if [ $DECK_TIMEOUT_COUNT -ge $TIMEOUT ]; then
        echo "错误：等待 Deck Pod 超时（${TIMEOUT}秒），请检查部署状态："
        k8s kubectl get pods -n $NAMESPACE
        k8s kubectl describe deployment -n $NAMESPACE deck
        REPLICASET=$(k8s kubectl get replicaset -n $NAMESPACE -l app=deck --no-headers -o custom-columns=":metadata.name" | head -n 1)
        if [ -n "$REPLICASET" ]; then
            k8s kubectl describe replicaset -n $NAMESPACE $REPLICASET
        fi
        exit 1
    fi
done

# 启动 Hook 容器内的命令并检查端口
echo "启动 Hook 容器内的命令..."
k8s kubectl exec -n $NAMESPACE $HOOK_POD -- /bin/sh -c "(export HTTP_PROXY=$PROXY && export HTTPS_PROXY=$PROXY && export NO_PROXY=$NO_PROXY && export LOGRUS_LEVEL=debug && /ko-app/hook --config-path=/etc/config/config.yaml --hmac-secret-file=/etc/hmac/hmac --github-app-id=1263514 --github-app-private-key-path=/etc/github/github-token --plugin-config=/etc/plugins/plugins.yaml --job-config-path=/etc/job-config/prow-jobs.yaml --dry-run=false > /tmp/hook.log 2>&1 &)"

# 等待 Hook 端口 8888 可用
echo "等待 Hook 端口 8888 可用..."
HOOK_PORT_TIMEOUT=0
while true; do
    HOOK_PORT_CHECK=$(k8s kubectl exec -n $NAMESPACE $HOOK_POD -- /bin/sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:8888/hook" || echo "未监听")
    if [ "$HOOK_PORT_CHECK" != "未监听" ] && [ "$HOOK_PORT_CHECK" != "000" ]; then
        echo "Hook 容器已监听 8888 端口，HTTP 返回码: $HOOK_PORT_CHECK"
        break
    else
        echo "Hook 端口 8888 未监听，等待中..."
        sleep 5
        HOOK_PORT_TIMEOUT=$((HOOK_PORT_TIMEOUT + 5))
        if [ $HOOK_PORT_TIMEOUT -ge $TIMEOUT ]; then
            echo "错误：等待 Hook 端口 8888 超时（${TIMEOUT}秒），输出日志："
            k8s kubectl exec -n $NAMESPACE $HOOK_POD -- /bin/sh -c "cat /tmp/hook.log | tail -50"
            exit 1
        fi
    fi
done

# 启动 Deck 容器内的命令并检查端口
echo "启动 Deck 容器内的命令..."
k8s kubectl exec -n $NAMESPACE $DECK_POD -- /bin/sh -c "(export HTTP_PROXY=$PROXY && export HTTPS_PROXY=$PROXY && export NO_PROXY=$NO_PROXY && export LOGRUS_LEVEL=debug && /ko-app/deck --config-path=/etc/config/config.yaml > /tmp/deck.log 2>&1 &)"

# 等待 Deck 端口 8080 可用
echo "等待 Deck 端口 8080 可用..."
DECK_PORT_TIMEOUT=0
while true; do
    DECK_PORT_CHECK=$(k8s kubectl exec -n $NAMESPACE $DECK_POD -- /bin/sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080" || echo "未监听")
    if [ "$DECK_PORT_CHECK" != "未监听" ] && [ "$DECK_PORT_CHECK" != "000" ]; then
        echo "Deck 容器已监听 8080 端口，HTTP 返回码: $DECK_PORT_CHECK"
        break
    else
        echo "Deck 端口 8080 未监听，等待中..."
        sleep 5
        DECK_PORT_TIMEOUT=$((DECK_PORT_TIMEOUT + 5))
        if [ $DECK_PORT_TIMEOUT -ge $TIMEOUT ]; then
            echo "错误：等待 Deck 端口 8080 超时（${TIMEOUT}秒），输出日志："
            k8s kubectl exec -n $NAMESPACE $DECK_POD -- /bin/sh -c "cat /tmp/deck.log | tail -50"
            exit 1
        fi
    fi
done

# 验证部署结果
echo "验证部署结果..."
k8s kubectl get all -n $NAMESPACE

echo "清理和重新部署完成！"
