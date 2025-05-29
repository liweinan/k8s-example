package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	// Parse command line flags
	kubeconfig := flag.String("kubeconfig", filepath.Join(os.Getenv("HOME"), ".kube", "config"), "Path to kubeconfig file")
	namespace := flag.String("namespace", "default", "Namespace to create the pod in")
	flag.Parse()

	// Try to get in-cluster config first
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Printf("Not running in cluster, trying to use kubeconfig: %v", err)
		// If not in cluster, use kubeconfig
		config, err = clientcmd.BuildConfigFromFlags("", *kubeconfig)
		if err != nil {
			log.Fatalf("Error creating client config: %v", err)
		}
	}

	// Create the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Error creating clientset: %v", err)
	}

	// Create a minimal pod
	podName := fmt.Sprintf("test-pod-%d", time.Now().Unix())
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podName,
			Namespace: *namespace,
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "nginx",
					Image: "nginx:latest",
					Ports: []corev1.ContainerPort{
						{
							ContainerPort: 80,
						},
					},
				},
			},
		},
	}

	// Create the pod
	fmt.Printf("Creating pod %s in namespace %s...\n", podName, *namespace)
	createdPod, err := clientset.CoreV1().Pods(*namespace).Create(context.TODO(), pod, metav1.CreateOptions{})
	if err != nil {
		log.Fatalf("Error creating pod: %v", err)
	}
	fmt.Printf("Pod created successfully: %s\n", createdPod.Name)

	// Wait for pod to be ready
	fmt.Println("Waiting for pod to be ready...")
	for {
		pod, err := clientset.CoreV1().Pods(*namespace).Get(context.TODO(), podName, metav1.GetOptions{})
		if err != nil {
			log.Fatalf("Error getting pod status: %v", err)
		}

		if pod.Status.Phase == corev1.PodRunning {
			fmt.Println("Pod is now running!")
			break
		}

		fmt.Printf("Pod status: %s\n", pod.Status.Phase)
		time.Sleep(2 * time.Second)
	}
}
