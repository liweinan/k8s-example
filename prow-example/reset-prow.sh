#!/bin/bash

# 设置脚本为出错时退出
set -e

# 定义 default 命名空间
NAMESPACE="default"

# 定义 prow-setup.yaml 文件路径
PROW_SETUP_FILE="./prow-setup.yaml"

# 定义 RBAC 文件路径
RBAC_FILE="./prow-rbac.yaml"

# 定义代理地址（默认值）
PROXY_IP=${1:-192.168.0.119}
PROXY_PORT=1080
PROXY="http://${PROXY_IP}:${PROXY_PORT}"

# 定义 NO_PROXY 设置，排除 Kubernetes API 服务器和服务 CIDR
NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.152.183.1"

# 定义等待超时时间（秒）
TIMEOUT=600  # 10 minutes to give Deck more time to start

# 清理 pod-test.tar 和 golang:1.21 镜像
echo "清理 pod-test.tar 和 golang:1.21 镜像..."
rm pod-test.tar 2>/dev/null || true
sudo ctr image rm docker.io/library/golang:1.21 2>/dev/null || true

# 打印开始信息
echo "开始清理 Prow 服务..."

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

# 验证 hook ServiceAccount
echo "验证 hook ServiceAccount 是否创建..."
if ! k8s kubectl get serviceaccount -n $NAMESPACE hook --no-headers >/dev/null 2>&1; then
    echo "错误：hook ServiceAccount 未创建，请检查 prow-rbac.yaml 或集群状态。"
    k8s kubectl describe serviceaccount -n $NAMESPACE hook || echo "ServiceAccount 不存在。"
    exit 1
fi

# 验证 plank ServiceAccount 和 token Secret (used by prow-controller-manager)
echo "验证 plank ServiceAccount 是否创建..."
if ! k8s kubectl get serviceaccount -n $NAMESPACE plank --no-headers >/dev/null 2>&1; then
    echo "错误：plank ServiceAccount 未创建，请检查 prow-rbac.yaml 或集群状态。"
    k8s kubectl describe serviceaccount -n $NAMESPACE plank || echo "ServiceAccount 不存在。"
    exit 1
fi

echo "验证 plank-token Secret 是否创建..."
if ! k8s kubectl get secret -n $NAMESPACE plank-token --no-headers >/dev/null 2>&1; then
    echo "错误：plank-token Secret 未创建，请检查 prow-rbac.yaml 或集群状态。"
    k8s kubectl describe secret -n $NAMESPACE plank-token || echo "Secret 不存在。"
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

# 创建 kubeconfig Secret
echo "创建 kubeconfig Secret..."
cat <<EOF > /tmp/kubeconfig.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    server: https://10.152.183.1:443
  name: default
contexts:
- context:
    cluster: default
    namespace: default
    user: plank
  name: default-context
current-context: default-context
users:
- name: plank
  user:
    tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF

k8s kubectl create secret generic kubeconfig -n $NAMESPACE --from-file=config=/tmp/kubeconfig.yaml
rm /tmp/kubeconfig.yaml

# 创建 test-project ConfigMap
echo "创建 test-project ConfigMap..."
k8s kubectl create configmap test-project -n $NAMESPACE \
  --from-file=go.mod=./test-project/go.mod \
  --from-file=math.go=./test-project/math.go \
  --from-file=math_test.go=./test-project/math_test.go

k8s kubectl create secret -n $NAMESPACE generic hmac-token --from-file=hmac=./secret
k8s kubectl create secret -n $NAMESPACE generic github-token --from-file=github-token=./alchemy-prow-bot.2025-05-11.private-key.pem
k8s kubectl create configmap -n $NAMESPACE config --from-file=config.yaml=./config.yaml
k8s kubectl create configmap -n $NAMESPACE plugins --from-file=plugins.yaml=./plugins.yaml
k8s kubectl create configmap -n $NAMESPACE job-config --from-file=prow-jobs.yaml=./prow-jobs.yaml

# 验证 ConfigMap 是否创建成功
echo "验证 ConfigMap 是否创建..."
for CONFIGMAP in config plugins job-config test-project; do
    if ! k8s kubectl get configmap -n $NAMESPACE $CONFIGMAP --no-headers >/dev/null 2>&1; then
        echo "错误：ConfigMap $CONFIGMAP 未创建，请检查文件是否存在或集群状态。"
        k8s kubectl describe configmap -n $NAMESPACE $CONFIGMAP || echo "ConfigMap 不存在。"
        exit 1
    fi
done

# 构建 pod-test 二进制文件
echo "构建 pod-test 二进制文件..."
# 创建临时目录并复制 pod-test 文件
mkdir -p /tmp/pod-test
cat <<EOF > /tmp/pod-test/go.mod
module pod-test

go 1.21

require (
	k8s.io/api v0.29.2
	k8s.io/apimachinery v0.29.2
	k8s.io/client-go v0.29.2
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/emicklei/go-restful/v3 v3.11.0 // indirect
	github.com/go-logr/logr v1.3.0 // indirect
	github.com/go-openapi/jsonpointer v0.19.6 // indirect
	github.com/go-openapi/jsonreference v0.20.2 // indirect
	github.com/go-openapi/swag v0.22.3 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/protobuf v1.5.3 // indirect
	github.com/google/gnostic-models v0.6.8 // indirect
	github.com/google/gofuzz v1.2.0 // indirect
	github.com/google/uuid v1.3.0 // indirect
	github.com/imdario/mergo v0.3.6 // indirect
	github.com/josharian/intern v1.0.0 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/mailru/easyjson v0.7.7 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	golang.org/x/net v0.19.0 // indirect
	golang.org/x/oauth2 v0.10.0 // indirect
	golang.org/x/sys v0.15.0 // indirect
	golang.org/x/term v0.15.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	golang.org/x/time v0.3.0 // indirect
	google.golang.org/appengine v1.6.7 // indirect
	google.golang.org/protobuf v1.31.0 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	k8s.io/klog/v2 v2.110.1 // indirect
	k8s.io/kube-openapi v0.0.0-20231010175941-2dd684a91f00 // indirect
	k8s.io/utils v0.0.0-20230726121419-3b25d923346b // indirect
	sigs.k8s.io/json v0.0.0-20221116044647-bc3834ca7abd // indirect
	sigs.k8s.io/structured-merge-diff/v4 v4.4.1 // indirect
	sigs.k8s.io/yaml v1.3.0 // indirect
)
EOF
cat <<EOF > /tmp/pod-test/pod-test.go
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
)

func main() {
	// Create a kubeconfig similar to Plank's
	kubeconfig := api.Config{
		Clusters: map[string]*api.Cluster{
			"default": {
				Server:               "https://10.152.183.1:443",
				CertificateAuthority: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
			},
		},
		Contexts: map[string]*api.Context{
			"default-context": {
				Cluster:   "default",
				AuthInfo:  "plank",
				Namespace: "default",
			},
		},
		CurrentContext: "default-context",
		AuthInfos: map[string]*api.AuthInfo{
			"plank": {
				TokenFile: "/var/run/secrets/kubernetes.io/serviceaccount/token",
			},
		},
	}

	// Convert to clientcmd.Config
	clientConfig := clientcmd.NewDefaultClientConfig(kubeconfig, &clientcmd.ConfigOverrides{})

	// Create the clientset
	config, err := clientConfig.ClientConfig()
	if err != nil {
		log.Fatalf("Error creating client config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Error creating clientset: %v", err)
	}

	// Create a test pod
	testPod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-pod-" + time.Now().Format("20060102150405"),
			Namespace: "default",
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "test",
					Image: "busybox",
					Command: []string{
						"sleep",
						"3600",
					},
				},
			},
		},
	}

	// Create a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create the pod
	fmt.Printf("Creating pod %s...\n", testPod.Name)
	createdPod, err := clientset.CoreV1().Pods("default").Create(ctx, testPod, metav1.CreateOptions{})
	if err != nil {
		log.Fatalf("Error creating pod: %v", err)
	}
	fmt.Printf("Pod created: %s\n", createdPod.Name)

	// Set up a watch for the pod
	watch, err := clientset.CoreV1().Pods("default").Watch(ctx, metav1.SingleObject(metav1.ObjectMeta{
		Name:      createdPod.Name,
		Namespace: "default",
	}))
	if err != nil {
		log.Fatalf("Error setting up watch: %v", err)
	}
	defer watch.Stop()

	// Wait for the pod to appear in the cache
	fmt.Println("Waiting for pod to appear in cache...")
	startTime := time.Now()
	for {
		select {
		case event, ok := <-watch.ResultChan():
			if !ok {
				log.Fatalf("Watch channel closed")
			}
			if event.Type == "ADDED" || event.Type == "MODIFIED" {
				pod := event.Object.(*corev1.Pod)
				fmt.Printf("Pod %s appeared in cache after %v\n", pod.Name, time.Since(startTime))
				return
			}
		case <-ctx.Done():
			log.Fatalf("Timeout waiting for pod to appear in cache after %v", time.Since(startTime))
		}
	}
}
EOF
export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY

cd /tmp/pod-test
go mod tidy
go build -o pod-test pod-test.go
cd -
if [ ! -f "/tmp/pod-test/pod-test" ]; then
    echo "错误：无法构建 pod-test 二进制文件，请检查 Go 环境和 pod-test.go 文件。"
    exit 1
fi

# 导入镜像到 k8s.io 命名空间
echo "导入镜像到 k8s.io 命名空间..."

# 拉取镜像
echo "拉取 Hook 镜像 gcr.io/k8s-prow/hook:latest..."
if ! ctr image pull gcr.io/k8s-prow/hook:latest; then
    echo "错误：无法拉取 Hook 镜像 gcr.io/k8s-prow/hook:latest，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

echo "拉取 Deck 镜像 gcr.io/k8s-prow/deck:latest..."
if ! ctr image pull gcr.io/k8s-prow/deck:latest; then
    echo "错误：无法拉取 Deck 镜像 gcr.io/k8s-prow/deck:latest，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

echo "拉取 Prow Controller Manager 镜像 gcr.io/k8s-prow/prow-controller-manager:latest..."
if ! ctr image pull gcr.io/k8s-prow/prow-controller-manager:latest; then
    echo "错误：无法拉取 Prow Controller Manager 镜像 gcr.io/k8s-prow/prow-controller-manager:latest，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

# 拉取 golang:1.21 镜像（用于 pod-test container）
echo "拉取 golang:1.21 镜像..."
if ! ctr image pull --platform linux/amd64 docker.io/library/golang:1.21; then
    echo "错误：无法拉取 golang:1.21 镜像，请检查网络、代理设置或镜像是否存在。"
    exit 1
fi

# 验证镜像是否成功拉取
echo "验证 golang:1.21 镜像是否成功拉取..."
if ! ctr image ls | grep -q docker.io/library/golang:1.21; then
    echo "错误：golang:1.21 镜像未找到，尝试重新拉取..."
    ctr image rm docker.io/library/golang:1.21 2>/dev/null || true
    if ! ctr image pull --platform linux/amd64 docker.io/library/golang:1.21; then
        echo "错误：重新拉取 golang:1.21 镜像失败，请检查网络、代理设置或镜像是否存在。"
        exit 1
    fi
    if ! ctr image ls | grep -q docker.io/library/golang:1.21; then
        echo "错误：golang:1.21 镜像仍未找到，请检查 containerd 状态。"
        exit 1
    fi
fi

# 导出镜像
ctr image export hook.tar gcr.io/k8s-prow/hook:latest
ctr image export deck.tar gcr.io/k8s-prow/deck:latest
ctr image export controller.tar gcr.io/k8s-prow/prow-controller-manager:latest
ctr image export pod-test.tar docker.io/library/golang:1.21
ctr -n k8s.io image import hook.tar
ctr -n k8s.io image import deck.tar
ctr -n k8s.io image import controller.tar
ctr -n k8s.io image import pod-test.tar
rm hook.tar deck.tar controller.tar pod-test.tar

echo "验证镜像是否导入到 k8s.io 命名空间..."
ctr -n k8s.io image ls | grep -E 'gcr.io/k8s-prow|docker.io/library/golang' || echo "镜像未找到，请检查 ctr 命令是否成功执行"

# 重新应用 prow-setup.yaml
echo "重新应用 prow-setup.yaml..."
k8s kubectl apply -f $PROW_SETUP_FILE

# 验证 Hook, Deck, Prow Controller Manager, 和 Pod Test Deployment 是否创建成功
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

echo "验证 Prow Controller Manager Deployment 是否创建..."
if ! k8s kubectl get deployment -n $NAMESPACE prow-controller-manager --no-headers >/dev/null 2>&1; then
    echo "错误：Prow Controller Manager Deployment 未创建，请检查 prow-setup.yaml 或集群状态。"
    k8s kubectl describe deployment -n $NAMESPACE prow-controller-manager || echo "Deployment 不存在。"
    exit 1
fi

echo "验证 Pod Test Deployment 是否创建..."
if ! k8s kubectl get deployment -n $NAMESPACE pod-test --no-headers >/dev/null 2>&1; then
    echo "错误：Pod Test Deployment 未创建，请检查 prow-setup.yaml 或集群状态。"
    k8s kubectl describe deployment -n $NAMESPACE pod-test || echo "Deployment 不存在。"
    exit 1
fi

# 等待 Pod 进入 Running 状态
echo "等待 Hook、Deck、Prow Controller Manager 和 Pod Test Pod 进入 Running 状态..."

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
    fi
    sleep 5
    DECK_TIMEOUT_COUNT=$((DECK_TIMEOUT_COUNT + 5))
    if [ $DECK_TIMEOUT_COUNT -ge $TIMEOUT ]; then
        echo "错误：等待 Deck Pod 超时（${TIMEOUT}秒），请检查部署状态："
        k8s kubectl get pods -n $NAMESPACE
        k8s kubectl describe deployment -n $NAMESPACE deck
        exit 1
    fi
done

# 等待 Prow Controller Manager Pod
echo "等待 Prow Controller Manager Pod..."
CONTROLLER_TIMEOUT_COUNT=0
while true; do
    CONTROLLER_POD=$(k8s kubectl get pods -n $NAMESPACE -l app=prow-controller-manager --no-headers -o custom-columns=":metadata.name" | head -n 1)
    if [ -n "$CONTROLLER_POD" ]; then
        CONTROLLER_STATUS=$(k8s kubectl get pod -n $NAMESPACE $CONTROLLER_POD --no-headers -o custom-columns=":status.phase")
        CONTROLLER_READY=$(k8s kubectl get pod -n $NAMESPACE $CONTROLLER_POD --no-headers -o custom-columns=":status.containerStatuses[0].ready" | grep "true" || true)
        CONTROLLER_CONDITION=$(k8s kubectl get pod -n $NAMESPACE $CONTROLLER_POD --no-headers -o custom-columns=":status.conditions[?(@.type=='Ready')].status" | grep "False" || true)
        if [ "$CONTROLLER_STATUS" = "Running" ] && [ -n "$CONTROLLER_READY" ] && [ -z "$CONTROLLER_CONDITION" ]; then
            echo "Prow Controller Manager Pod ($CONTROLLER_POD) 已进入 Running 状态且 Ready"
            break
        else
            CONTROLLER_CONTAINER_STATUS=$(k8s kubectl get pod -n $NAMESPACE $CONTROLLER_POD --no-headers -o custom-columns=":status.containerStatuses[0].state" | grep "CrashLoopBackOff" || true)
            if [ -n "$CONTROLLER_CONTAINER_STATUS" ]; then
                echo "错误：Prow Controller Manager Pod ($CONTROLLER_POD) 处于 CrashLoopBackOff 状态，输出日志："
                k8s kubectl logs -n $NAMESPACE $CONTROLLER_POD --tail=50
                k8s kubectl describe pod -n $NAMESPACE $CONTROLLER_POD
                exit 1
            fi
            echo "Prow Controller Manager Pod ($CONTROLLER_POD) 状态: $CONTROLLER_STATUS, Ready: $CONTROLLER_READY，等待中..."
        fi
    else
        echo "未找到 Prow Controller Manager Pod，等待中..."
        k8s kubectl get pods -n $NAMESPACE -l app=prow-controller-manager
    fi
    sleep 5
    CONTROLLER_TIMEOUT_COUNT=$((CONTROLLER_TIMEOUT_COUNT + 5))
    if [ $CONTROLLER_TIMEOUT_COUNT -ge $TIMEOUT ]; then
        echo "错误：等待 Prow Controller Manager Pod 超时（${TIMEOUT}秒），请检查部署状态："
        k8s kubectl get pods -n $NAMESPACE
        k8s kubectl describe deployment -n $NAMESPACE prow-controller-manager
        exit 1
    fi
done

# 等待 Pod Test Pod
echo "等待 Pod Test Pod..."
POD_TEST_TIMEOUT_COUNT=0
while true; do
    POD_TEST_POD=$(k8s kubectl get pods -n $NAMESPACE -l app=pod-test --no-headers -o custom-columns=":metadata.name" | head -n 1)
    if [ -n "$POD_TEST_POD" ]; then
        POD_TEST_STATUS=$(k8s kubectl get pod -n $NAMESPACE $POD_TEST_POD --no-headers -o custom-columns=":status.phase")
        POD_TEST_READY=$(k8s kubectl get pod -n $NAMESPACE $POD_TEST_POD --no-headers -o custom-columns=":status.containerStatuses[0].ready" | grep "true" || true)
        POD_TEST_CONDITION=$(k8s kubectl get pod -n $NAMESPACE $POD_TEST_POD --no-headers -o custom-columns=":status.conditions[?(@.type=='Ready')].status" | grep "False" || true)
        if [ "$POD_TEST_STATUS" = "Running" ] && [ -n "$POD_TEST_READY" ] && [ -z "$POD_TEST_CONDITION" ]; then
            echo "Pod Test Pod ($POD_TEST_POD) 已进入 Running 状态且 Ready"
            break
        else
            POD_TEST_CONTAINER_STATUS=$(k8s kubectl get pod -n $NAMESPACE $POD_TEST_POD --no-headers -o custom-columns=":status.containerStatuses[0].state" | grep "CrashLoopBackOff" || true)
            if [ -n "$POD_TEST_CONTAINER_STATUS" ]; then
                echo "错误：Pod Test Pod ($POD_TEST_POD) 处于 CrashLoopBackOff 状态，输出日志："
                k8s kubectl logs -n $NAMESPACE $POD_TEST_POD --tail=50
                k8s kubectl describe pod -n $NAMESPACE $POD_TEST_POD
                exit 1
            fi
            echo "Pod Test Pod ($POD_TEST_POD) 状态: $POD_TEST_STATUS, Ready: $POD_TEST_READY，等待中..."
        fi
    else
        echo "未找到 Pod Test Pod，等待中..."
        k8s kubectl get pods -n $NAMESPACE -l app=pod-test
    fi
    sleep 5
    POD_TEST_TIMEOUT_COUNT=$((POD_TEST_TIMEOUT_COUNT + 5))
    if [ $POD_TEST_TIMEOUT_COUNT -ge $TIMEOUT ]; then
        echo "错误：等待 Pod Test Pod 超时（${TIMEOUT}秒），请检查部署状态："
        k8s kubectl get pods -n $NAMESPACE
        k8s kubectl describe deployment -n $NAMESPACE pod-test
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

# 启动 Prow Controller Manager 容器内的命令
echo "启动 Prow Controller Manager 容器内的命令..."
k8s kubectl exec -n $NAMESPACE $CONTROLLER_POD -- /bin/sh -c "(export HTTP_PROXY=$PROXY && export HTTPS_PROXY=$PROXY && export NO_PROXY=$NO_PROXY && export LOGRUS_LEVEL=debug && /ko-app/prow-controller-manager --enable-controller=plank --config-path=/etc/config/config.yaml --kubeconfig=/etc/kubeconfig/config > /tmp/controller.log 2>&1 &)"

# 复制 pod-test 二进制文件到 Pod Test 容器并执行
echo "复制 pod-test 二进制文件到 Pod Test 容器..."
k8s kubectl cp /tmp/pod-test/pod-test $NAMESPACE/$POD_TEST_POD:/tmp/pod-test

# 验证 Pod Test 的测试结果
echo "验证 Pod Test 的测试结果..."
POD_TEST_LOG_TIMEOUT=0
while true; do
    POD_TEST_LOG_CHECK=$(k8s kubectl exec -n $NAMESPACE $POD_TEST_POD -- /bin/sh -c "[ -f /tmp/pod-test.log ] && echo 'exists'" || echo "not_exists")
    if [ "$POD_TEST_LOG_CHECK" = "exists" ]; then
        echo "Pod Test 已生成测试日志，输出测试结果："
        k8s kubectl exec -n $NAMESPACE $POD_TEST_POD -- /bin/sh -c "cat /tmp/pod-test.log"
        break
    else
        echo "Pod Test 尚未生成测试日志，等待中..."
        sleep 5
        POD_TEST_LOG_TIMEOUT=$((POD_TEST_LOG_TIMEOUT + 5))
        if [ $POD_TEST_LOG_TIMEOUT -ge $TIMEOUT ]; then
            echo "错误：等待 Pod Test 日志超时（${TIMEOUT}秒），请检查容器状态："
            k8s kubectl logs -n $NAMESPACE $POD_TEST_POD --tail=50
            k8s kubectl describe pod -n $NAMESPACE $POD_TEST_POD
            exit 1
        fi
    fi
done

# 验证部署结果
echo "验证部署结果..."
k8s kubectl get all -n $NAMESPACE

echo "清理和重新部署完成！"