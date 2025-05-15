#!/bin/bash

# Generate a unique name for the ProwJob
JOB_NAME="test-job-$(date +%s)"

# Create the ProwJob
echo "Creating ProwJob $JOB_NAME..."
sed "s/test-job-\$(date +%s)/$JOB_NAME/" test-prowjob.yaml | k8s kubectl apply -f -

# Wait for the ProwJob to be created
echo "Waiting for ProwJob to be created..."
k8s kubectl wait --for=condition=created prowjob/$JOB_NAME --timeout=30s

# Get the ProwJob status
echo "ProwJob status:"
k8s kubectl get prowjob $JOB_NAME -o yaml

# Watch the pod creation
echo "Watching pod creation..."
k8s kubectl get pods -w | grep $JOB_NAME