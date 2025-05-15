#!/bin/bash

# Set error handling
set -e

# Generate a unique name for the ProwJob
JOB_NAME="test-job-$(date +%s)"

echo "=== Starting ProwJob Test ==="
echo "Job Name: $JOB_NAME"

# Create the ProwJob
echo -e "\n=== Creating ProwJob ==="
sed "s/test-job-\$(date +%s)/$JOB_NAME/" test-prowjob.yaml | k8s kubectl apply -f -

# Wait for the ProwJob to be created
echo -e "\n=== Waiting for ProwJob to be created ==="
k8s kubectl wait --for=condition=created prowjob/$JOB_NAME --timeout=30s

# Get the ProwJob status
echo -e "\n=== ProwJob Status ==="
k8s kubectl get prowjob $JOB_NAME -o yaml | grep -A 5 "status:"

# Get the pod name
echo -e "\n=== Getting Pod Name ==="
POD_NAME=$(k8s kubectl get pods | grep $JOB_NAME | awk '{print $1}')
echo "Pod Name: $POD_NAME"

# Watch the pod logs
echo -e "\n=== Watching Pod Logs ==="
k8s kubectl logs -f $POD_NAME

# Wait for pod completion
echo -e "\n=== Waiting for Pod Completion ==="
k8s kubectl wait --for=condition=Ready pod/$POD_NAME --timeout=300s

# Get final pod status
echo -e "\n=== Final Pod Status ==="
k8s kubectl get pod $POD_NAME

echo -e "\n=== Test Complete ==="