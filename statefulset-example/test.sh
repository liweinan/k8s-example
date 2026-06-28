#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

KUBECTL="${KUBECTL:-kubectl}"
NS="${NS:-default}"
DNS_SUFFIX="${DNS_SUFFIX:-${NS}.svc.cluster.local}"
POD_NAME="web-0"
DNS_NAME="${POD_NAME}.web-headless.${DNS_SUFFIX}"

echo "=== StatefulSet 稳定 DNS 演示 ==="
echo "kubectl: $KUBECTL"
echo "namespace: $NS"
echo

echo "1. 部署 Headless Service 和 StatefulSet..."
$KUBECTL apply -f headless-service.yaml
$KUBECTL apply -f statefulset.yaml

echo
echo "2. 等待 3 个 Pod 就绪（StatefulSet 按序启动）..."
$KUBECTL wait --for=jsonpath='{.status.readyReplicas}'=3 statefulset/web --timeout=180s
$KUBECTL get pods -l app=web -o wide

pod_ip() {
  $KUBECTL get pod "$1" -o jsonpath='{.status.podIP}'
}

OLD_IP=$(pod_ip "$POD_NAME")
echo
echo "3. 当前 ${POD_NAME} 的 Pod IP: ${OLD_IP}"
echo "   稳定 DNS 名称: ${DNS_NAME}"

echo
echo "4. 删除 ${POD_NAME}，模拟 Pod 故障..."
$KUBECTL delete pod "$POD_NAME" --wait=true
$KUBECTL wait --for=condition=Ready "pod/${POD_NAME}" --timeout=120s
sleep 2

NEW_IP=$(pod_ip "$POD_NAME")
echo
echo "5. 重启后 ${POD_NAME} 的新 Pod IP: ${NEW_IP}"
echo "   Pod 名仍是: ${POD_NAME}（StatefulSet 保证同名重建）"

if [[ -n "$OLD_IP" && -n "$NEW_IP" && "$OLD_IP" != "$NEW_IP" ]]; then
  echo "   IP 已变化: ${OLD_IP} -> ${NEW_IP}"
else
  echo "   IP 可能相同（Calico 偶发复用），重点看 DNS 是否仍指向当前 Pod"
fi
echo "   DNS 名称仍是: ${DNS_NAME}"

resolve_dns() {
  $KUBECTL run "dns-test-$RANDOM" --rm -i --restart=Never --image=busybox:1.36 \
    --command -- nslookup "$DNS_NAME" 2>/dev/null \
    | awk '/^Address: / { print $2; exit }' \
    | head -1 \
    | tr -d '[:space:]'
}

echo
echo "6. 从集群内解析 DNS，确认域名指向当前 Pod IP..."
RESOLVED_IP=""
for attempt in 1 2 3 4 5; do
  RESOLVED_IP=$(resolve_dns || true)
  if [[ "$RESOLVED_IP" == "$NEW_IP" ]]; then
    echo "   第 ${attempt} 次解析成功: ${RESOLVED_IP}"
    break
  fi
  echo "   第 ${attempt} 次解析: ${RESOLVED_IP:-<empty>}，等待 CoreDNS 更新..."
  sleep 3
done
echo "   DNS 解析结果: ${RESOLVED_IP}"
echo "   当前 Pod IP:  ${NEW_IP}"

if [[ "$RESOLVED_IP" == "$NEW_IP" ]]; then
  echo "   ✓ DNS 名不变，且始终指向当前 Pod IP"
else
  echo "   ! DNS 与 Pod IP 不一致，请稍等后重试 nslookup"
fi

set +o pipefail
$KUBECTL run "dns-test-http-$RANDOM" --rm -i --restart=Never --image=busybox:1.36 \
  --command -- wget -qO- "http://${DNS_NAME}/" | head -3 || true
set -o pipefail

echo
echo "=== 演示完成 ==="
echo "清理: kubectl delete -f statefulset.yaml -f headless-service.yaml"
