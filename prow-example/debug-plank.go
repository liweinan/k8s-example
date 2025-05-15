package main

import (
	"context"
	"fmt"
	"log"
	"time"

	corev1 "k8s.io/api/core/v1"
	kerrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
	"k8s.io/utils/ptr"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
)

// logWithTime adds a timestamp to log messages
func logWithTime(format string, args ...interface{}) {
	log.Printf(format, args...)
}

// logTiming logs the time taken for an operation
func logTiming(operation string, start time.Time) {
	logWithTime("%s took %v", operation, time.Since(start))
}

func startPod(ctx context.Context, mgr manager.Manager, jobName string) (string, string, error) {
	startTime := time.Now()
	logWithTime("Starting pod creation for job %s", jobName)

	// Generate build ID
	buildID := fmt.Sprintf("build-%d", time.Now().Unix())
	logWithTime("Generated build ID: %s", buildID)

	// Create pod spec with Plank-like configuration
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-%s", jobName, buildID),
			Namespace: "default",
			Labels: map[string]string{
				"created-by-prow":  "true",
				"build-id":         buildID,
				"prow.k8s.io/job":  jobName,
				"prow.k8s.io/type": "periodic",
			},
			Annotations: map[string]string{
				"prow.k8s.io/job":  jobName,
				"prow.k8s.io/type": "periodic",
			},
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
					Resources: corev1.ResourceRequirements{
						Requests: corev1.ResourceList{
							corev1.ResourceCPU:    resource.MustParse("100m"),
							corev1.ResourceMemory: resource.MustParse("100Mi"),
						},
						Limits: corev1.ResourceList{
							corev1.ResourceCPU:    resource.MustParse("200m"),
							corev1.ResourceMemory: resource.MustParse("200Mi"),
						},
					},
					ImagePullPolicy: corev1.PullIfNotPresent,
					SecurityContext: &corev1.SecurityContext{
						RunAsNonRoot: ptr.To(true),
						RunAsUser:    ptr.To(int64(1000)),
					},
				},
			},
			RestartPolicy: corev1.RestartPolicyNever,
			DNSPolicy:     corev1.DNSClusterFirst,
			NodeSelector: map[string]string{
				"kubernetes.io/os": "linux",
			},
			SecurityContext: &corev1.PodSecurityContext{
				RunAsNonRoot: ptr.To(true),
				RunAsUser:    ptr.To(int64(1000)),
			},
		},
	}

	podName := types.NamespacedName{Namespace: pod.Namespace, Name: pod.Name}
	logWithTime("Pod will be created with name: %s in namespace: %s", pod.Name, pod.Namespace)
	logWithTime("Pod spec: %+v", pod)

	// Create the pod using the manager's client
	logWithTime("Attempting to create pod...")
	createStart := time.Now()
	err := mgr.GetClient().Create(ctx, pod)
	if err != nil {
		logWithTime("Error creating pod: %v", err)
		return "", "", fmt.Errorf("create pod %s: %w", podName.String(), err)
	}
	logTiming("Pod creation request", createStart)
	logWithTime("Pod creation request sent successfully")

	// Wait for pod to appear in cache (mimicking Plank's behavior)
	logWithTime("Waiting for pod to appear in cache...")
	cacheStart := time.Now()
	if err := wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 10*time.Second, true, func(ctx context.Context) (bool, error) {
		var pod corev1.Pod
		if err := mgr.GetClient().Get(ctx, podName, &pod); err != nil {
			if kerrors.IsNotFound(err) {
				logWithTime("Pod not found in cache yet, retrying...")
				return false, nil
			}
			logWithTime("Error getting pod from cache: %v", err)
			return false, fmt.Errorf("failed to get pod %s: %w", podName.String(), err)
		}

		// Log pod status and conditions
		logWithTime("Pod status: Phase=%s, Message=%s, Reason=%s", pod.Status.Phase, pod.Status.Message, pod.Status.Reason)
		for _, condition := range pod.Status.Conditions {
			logWithTime("Pod condition: Type=%s, Status=%s, Reason=%s, Message=%s",
				condition.Type, condition.Status, condition.Reason, condition.Message)
		}

		// Log container statuses
		for _, containerStatus := range pod.Status.ContainerStatuses {
			logWithTime("Container status: Name=%s, State=%+v, Ready=%v",
				containerStatus.Name, containerStatus.State, containerStatus.Ready)
		}

		logTiming("Pod found in cache", cacheStart)
		return true, nil
	}); err != nil {
		logWithTime("Timeout waiting for pod to appear in cache after %v: %v", time.Since(cacheStart), err)
		return "", "", fmt.Errorf("failed waiting for new pod %s to appear in cache: %w", podName.String(), err)
	}

	// Wait for pod to be ready with Plank-like timeouts
	logWithTime("Waiting for pod to be ready...")
	readyStart := time.Now()
	if err := wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 30*time.Second, true, func(ctx context.Context) (bool, error) {
		var pod corev1.Pod
		if err := mgr.GetClient().Get(ctx, podName, &pod); err != nil {
			return false, fmt.Errorf("failed to get pod %s: %w", podName.String(), err)
		}

		// Log pod status while waiting
		logWithTime("Pod status: Phase=%s, Message=%s, Reason=%s", pod.Status.Phase, pod.Status.Message, pod.Status.Reason)

		// Check pod conditions
		for _, condition := range pod.Status.Conditions {
			logWithTime("Pod condition: Type=%s, Status=%s, Reason=%s, Message=%s",
				condition.Type, condition.Status, condition.Reason, condition.Message)

			// Check for specific failure conditions
			if condition.Type == corev1.PodScheduled && condition.Status == corev1.ConditionFalse {
				logWithTime("Pod scheduling failed: %s", condition.Message)
				return false, fmt.Errorf("pod scheduling failed: %s", condition.Message)
			}
		}

		// Check container statuses
		for _, containerStatus := range pod.Status.ContainerStatuses {
			logWithTime("Container status: Name=%s, State=%+v, Ready=%v",
				containerStatus.Name, containerStatus.State, containerStatus.Ready)

			// Check for container failures
			if containerStatus.State.Waiting != nil {
				logWithTime("Container waiting: Reason=%s, Message=%s",
					containerStatus.State.Waiting.Reason, containerStatus.State.Waiting.Message)
			}
			if containerStatus.State.Terminated != nil {
				logWithTime("Container terminated: Reason=%s, Message=%s, ExitCode=%d",
					containerStatus.State.Terminated.Reason, containerStatus.State.Terminated.Message, containerStatus.State.Terminated.ExitCode)
			}
		}

		// Check if pod is ready
		if pod.Status.Phase == corev1.PodRunning {
			for _, condition := range pod.Status.Conditions {
				if condition.Type == corev1.PodReady && condition.Status == corev1.ConditionTrue {
					logTiming("Pod ready", readyStart)
					return true, nil
				}
			}
		}

		return false, nil
	}); err != nil {
		logWithTime("Timeout waiting for pod to be ready after %v: %v", time.Since(readyStart), err)
		return "", "", fmt.Errorf("failed waiting for pod %s to be ready: %w", podName.String(), err)
	}

	logTiming("Total pod creation process", startTime)
	logWithTime("Pod creation completed successfully")
	return buildID, pod.Name, nil
}

func main() {
	// Create a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

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
	cfg, err := clientConfig.ClientConfig()
	if err != nil {
		log.Fatalf("Error creating client config: %v", err)
	}

	// Create controller-runtime manager
	scheme := runtime.NewScheme()
	if err := corev1.AddToScheme(scheme); err != nil {
		log.Fatalf("Error adding scheme: %v", err)
	}

	mgr, err := manager.New(cfg, manager.Options{
		Scheme: scheme,
		Cache: cache.Options{
			DefaultNamespaces: map[string]cache.Config{
				"default": {},
			},
			SyncPeriod: ptr.To(10 * time.Second),
		},
		Metrics: metricsserver.Options{
			BindAddress: "0",
		},
	})
	if err != nil {
		log.Fatalf("Error creating manager: %v", err)
	}

	// Start the manager in a goroutine
	go func() {
		if err := mgr.Start(ctx); err != nil {
			log.Fatalf("Error starting manager: %v", err)
		}
	}()

	// Wait for cache to sync
	logWithTime("Waiting for cache to sync...")
	syncStart := time.Now()
	if !mgr.GetCache().WaitForCacheSync(ctx) {
		log.Fatalf("Failed to sync cache")
	}
	logTiming("Cache sync", syncStart)
	logWithTime("Cache synced successfully")

	// Start the pod
	buildID, podName, err := startPod(ctx, mgr, "test-job")
	if err != nil {
		log.Fatalf("Error starting pod: %v", err)
	}

	logWithTime("Successfully created pod %s with build ID %s", podName, buildID)
}
