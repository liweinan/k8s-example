package main

import (
	"context"
	"fmt"
	"log"
	"time"

	corev1 "k8s.io/api/core/v1"
	kerrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/rest"
)

func startPod(ctx context.Context, mgr manager.Manager, jobName string) (string, string, error) {
	log.Printf("Starting pod creation for job %s", jobName)

	// Generate build ID
	buildID := fmt.Sprintf("build-%d", time.Now().Unix())
	log.Printf("Generated build ID: %s", buildID)

	// Create pod spec
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-%s", jobName, buildID),
			Namespace: "default",
			Labels: map[string]string{
				"created-by-prow": "true",
				"build-id":        buildID,
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
				},
			},
		},
	}

	podName := types.NamespacedName{Namespace: pod.Namespace, Name: pod.Name}
	log.Printf("Pod will be created with name: %s in namespace: %s", pod.Name, pod.Namespace)
	log.Printf("Pod spec: %+v", pod)

	// Create the pod using the manager's client
	log.Printf("Attempting to create pod...")
	err := mgr.GetClient().Create(ctx, pod)
	if err != nil {
		log.Printf("Error creating pod: %v", err)
		return "", "", fmt.Errorf("create pod %s: %w", podName.String(), err)
	}
	log.Printf("Pod creation request sent successfully")

	// Wait for pod to appear in cache
	log.Printf("Waiting for pod to appear in cache...")
	startTime := time.Now()
	if err := wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 10*time.Second, true, func(ctx context.Context) (bool, error) {
		var pod corev1.Pod
		if err := mgr.GetClient().Get(ctx, podName, &pod); err != nil {
			if kerrors.IsNotFound(err) {
				log.Printf("Pod not found in cache yet, retrying...")
				return false, nil
			}
			log.Printf("Error getting pod from cache: %v", err)
			return false, fmt.Errorf("failed to get pod %s: %w", podName.String(), err)
		}
		log.Printf("Pod found in cache after %v", time.Since(startTime))
		return true, nil
	}); err != nil {
		log.Printf("Timeout waiting for pod to appear in cache after %v: %v", time.Since(startTime), err)
		return "", "", fmt.Errorf("failed waiting for new pod %s to appear in cache: %w", podName.String(), err)
	}

	log.Printf("Pod creation completed successfully")
	return buildID, pod.Name, nil
}

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
		// Match plank's cache settings
		SyncPeriod: 10 * time.Second,
		NewCache: func(config *rest.Config, opts cache.Options) (cache.Cache, error) {
			opts.SyncPeriod = 10 * time.Second
			return cache.New(config, opts)
		},
	})
	if err != nil {
		log.Fatalf("Error creating manager: %v", err)
	}

	// Start the manager
	go func() {
		if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
			log.Fatalf("Error starting manager: %v", err)
		}
	}()

	// Wait for cache to sync
	log.Printf("Waiting for cache to sync...")
	if !mgr.GetCache().WaitForCacheSync(signals.SetupSignalHandler()) {
		log.Fatalf("Failed to sync cache")
	}
	log.Printf("Cache synced successfully")

	// Create a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Start the pod
	buildID, podName, err := startPod(ctx, mgr, "test-job")
	if err != nil {
		log.Fatalf("Error starting pod: %v", err)
	}

	log.Printf("Successfully created pod %s with build ID %s", podName, buildID)
}
