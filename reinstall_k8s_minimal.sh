#!/bin/bash
# Minimal script to reinstall k8s snap and bootstrap cluster
# No manual IP binding, no CNI deployment (uses default Cilium), waits for all pods Running and Ready
# Usage: sudo bash reinstall_k8s_minimal.sh

# Exit on any error
set -e

# Define variables
K8S_DIR="/var/snap/k8s"
CONTAINERD_DIR="/var/snap/k8s/common/run/containerd"

# Log function for output
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

# Step 1: Stop and remove k8s snap
log "Stopping k8s services..."
sudo snap stop k8s || true
log "Removing k8s snap and cleaning residual data..."
sudo snap remove k8s --purge || true
sudo rm -rf "$K8S_DIR"

# Step 2: Stop and disable system containerd
log "Stopping and disabling system containerd..."
sudo systemctl stop containerd || true
sudo systemctl disable containerd || true
sudo rm -rf /run/containerd

# Step 3: Check for port conflicts
log "Checking for port conflicts on 6400, 9000, 6443..."
if sudo netstat -tulnp | grep -E ':6400|:9000|:6443'; then
    log "ERROR: Ports 6400, 9000, or 6443 are in use. Please free these ports."
    exit 1
else
    log "No port conflicts found."
fi

# Step 4: Verify /run/containerd is clear
log "Verifying /run/containerd is clear..."
if [ -e /run/containerd ]; then
    log "ERROR: /run/containerd exists. Cleaning up..."
    sudo rm -rf /run/containerd
fi
if [ -e /run/containerd ]; then
    log "ERROR: Failed to clean /run/containerd. Another service may be using it."
    sudo ps aux | grep containerd
    exit 1
fi
log "/run/containerd is clear."

# Step 5: Install k8s snap
log "Installing k8s snap (latest --classic version)..."
sudo snap install k8s --classic

# Step 6: Configure containerd path
log "Configuring containerd base directory..."
sudo snap set k8s containerd-base-dir="$CONTAINERD_DIR" || log "WARNING: snap set containerd-base-dir failed, continuing..."
sudo mkdir -p "$CONTAINERD_DIR"
sudo chmod 755 "$CONTAINERD_DIR"

# Step 7: Run bootstrap
log "Running k8s bootstrap..."
sudo k8s bootstrap

# Step 8: Wait for all system pods to be Running and Ready (up to 5 minutes)
log "Waiting for all system pods to be Running and Ready (up to 5 minutes)..."
TIMEOUT=300
INTERVAL=10
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    # Get pod status, check if all are Running and Ready
    PODS=$(sudo k8s kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[*].ready}{"\t"}{.status.initContainerStatuses[*].ready}{"\n"}{end}' 2>/dev/null || true)
    NOT_READY=$(echo "$PODS" | grep -v "Running.*true" || true)
    if [ -z "$NOT_READY" ] && [ -n "$PODS" ]; then
        log "All system pods are Running and Ready."
        break
    fi
    log "Some system pods not Running or Ready yet, waiting $INTERVAL seconds..."
    echo "$NOT_READY" | while read -r pod phase ready init_ready; do
        log "Pod $pod: Phase=$phase, Ready=$ready, InitReady=$init_ready"
    done
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done
if [ $ELAPSED -ge $TIMEOUT ]; then
    log "ERROR: Not all system pods became Running and Ready within $TIMEOUT seconds."
    sudo k8s kubectl get pods -n kube-system
    NOT_READY_POD=$(sudo k8s kubectl get pods -n kube-system | grep -v "Running.*[0-9]/[0-9]" | awk '{print $1}' | head -n 1)
    if [ -n "$NOT_READY_POD" ]; then
        sudo k8s kubectl describe pod -n kube-system "$NOT_READY_POD"
    fi
    exit 1
fi

# Step 9: Wait for node to be Ready (up to 1 minute)
log "Waiting for node to be Ready (up to 1 minute)..."
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if sudo k8s kubectl get nodes | grep -q Ready; then
        log "Node is Ready."
        break
    fi
    log "Node not Ready yet, waiting $INTERVAL seconds..."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done
if [ $ELAPSED -ge $TIMEOUT ]; then
    log "ERROR: Node did not become Ready within $TIMEOUT seconds."
    sudo k8s kubectl get nodes
    sudo journalctl -u snap.k8s.kubelet --since "10 minutes ago"
    exit 1
fi

# Step 10: Check cluster status
log "Checking cluster status..."
sudo k8s status

# Step 11: Check service status
log "Checking k8s service status..."
sudo snap services k8s

# Step 12: Check node status
log "Checking node status..."
sudo k8s kubectl get nodes

# Step 13: Check system pods
log "Checking system pod status..."
sudo k8s kubectl get pods -n kube-system

# Step 14: Verify control socket
log "Checking control socket..."
ls -l /var/snap/k8s/common/var/lib/k8sd/state/control.socket || log "WARNING: Control socket not found"

# Step 15: Verify admin.conf
log "Verifying admin.conf..."
ls -l /etc/kubernetes/admin.conf || log "WARNING: admin.conf not found"

log "Script completed. If bootstrap fails, check logs with 'sudo snap logs k8s' and 'sudo journalctl -u snap.k8s*'"
