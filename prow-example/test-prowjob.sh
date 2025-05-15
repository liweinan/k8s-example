#!/bin/bash

# Generate a unique name for the ProwJob
JOB_NAME="test-job-$(date +%s)"

# Create the ProwJob
echo "Creating ProwJob $JOB_NAME..."
cat test-prowjob.yaml | sed "s/test-job-\$(date +%s)/$JOB_NAME/" | kubectl apply -f -

# Wait for the ProwJob to be created
echo "Waiting for ProwJob to be created..."
kubectl wait --for=condition=created prowjob/$JOB_NAME --timeout=30s

# Get the ProwJob status
echo "ProwJob status:"
kubectl get prowjob $JOB_NAME -o yaml

# Watch the pod creation
echo "Watching pod creation..."
kubectl get pods -w | grep $JOB_NAME