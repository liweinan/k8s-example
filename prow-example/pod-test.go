package main

import (
	"context"
	"fmt"
	"log"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
	ctrlruntimeclient "sigs.k8s.io/controller-runtime/pkg/client"
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
	cfg, err := clientConfig.ClientConfig()
	if err != nil {
		log.Fatalf("Error creating client config: %v", err)
	}

	// Create controller-runtime client
	scheme := runtime.NewScheme()
	if err := corev1.AddToScheme(scheme); err != nil {
		log.Fatalf("Error adding scheme: %v", err)
	}

	ctrlClient, err := ctrlruntimeclient.New(cfg, ctrlruntimeclient.Options{Scheme: scheme})
	if err != nil {
		log.Fatalf("Error creating controller-runtime client: %v", err)
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

	// Create the pod using controller-runtime client
	fmt.Printf("Creating pod %s...\n", testPod.Name)
	if err := ctrlClient.Create(ctx, testPod); err != nil {
		log.Fatalf("Error creating pod: %v", err)
	}
	fmt.Printf("Pod created: %s\n", testPod.Name)

	// Wait for the pod to appear in the cache
	fmt.Println("Waiting for pod to appear in cache...")
	startTime := time.Now()
	for {
		select {
		case <-ctx.Done():
			log.Fatalf("Timeout waiting for pod to appear in cache after %v", time.Since(startTime))
		default:
			var pod corev1.Pod
			if err := ctrlClient.Get(ctx, types.NamespacedName{Name: testPod.Name, Namespace: "default"}, &pod); err == nil {
				fmt.Printf("Pod %s appeared in cache after %v\n", pod.Name, time.Since(startTime))
				return
			}
			time.Sleep(100 * time.Millisecond)
		}
	}
}
