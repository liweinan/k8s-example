package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func verifyEnvironment() {
	// Print current user and environment
	fmt.Println("=== Environment Information ===")
	fmt.Printf("Current user: %s\n", os.Getenv("USER"))
	fmt.Printf("HOME directory: %s\n", os.Getenv("HOME"))
	fmt.Printf("KUBECONFIG: %s\n", os.Getenv("KUBECONFIG"))

	// Check k8s kubectl
	if _, err := exec.LookPath("k8s"); err == nil {
		cmd := exec.Command("k8s", "kubectl", "config", "view")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("Error running k8s kubectl config view: %v\n", err)
		} else {
			fmt.Println("=== K8s Kubectl Configuration ===")
			fmt.Println(string(output))
		}
	} else {
		fmt.Println("k8s command not found in PATH")
	}

	// Check common kubeconfig locations
	paths := []string{
		filepath.Join(os.Getenv("HOME"), ".kube", "config"),
		"/root/.kube/config",
		"/etc/kubernetes/admin.conf",
		"/etc/kubernetes/kubeconfig",
		"/var/snap/k8s/current/kubeconfig",
	}

	fmt.Println("\n=== Checking kubeconfig locations ===")
	for _, path := range paths {
		if _, err := os.Stat(path); err == nil {
			fmt.Printf("Found kubeconfig at: %s\n", path)
		} else {
			fmt.Printf("No kubeconfig at: %s\n", path)
		}
	}
	fmt.Println("===================================")
}

func getKubeconfigPath() string {
	// First try KUBECONFIG environment variable
	if kubeconfig := os.Getenv("KUBECONFIG"); kubeconfig != "" {
		return kubeconfig
	}

	// Try to get config from k8s kubectl
	cmd := exec.Command("k8s", "kubectl", "config", "view", "--raw")
	output, err := cmd.CombinedOutput()
	if err == nil {
		// Create a temporary file with the config
		tmpFile := filepath.Join(os.TempDir(), "kubeconfig")
		if err := os.WriteFile(tmpFile, output, 0600); err == nil {
			return tmpFile
		}
	}

	// If all else fails, return the default path
	return filepath.Join(os.Getenv("HOME"), ".kube", "config")
}

func main() {
	// Parse command line flags
	kubeconfig := flag.String("kubeconfig", getKubeconfigPath(), "Path to kubeconfig file")
	namespace := flag.String("namespace", "default", "Namespace to create the pod in")
	debug := flag.Bool("debug", false, "Enable debug mode to show environment information")
	flag.Parse()

	if *debug {
		verifyEnvironment()
	}

	// Try to get in-cluster config first
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Printf("Not running in cluster, trying to use kubeconfig: %v", err)
		// If not in cluster, use kubeconfig
		config, err = clientcmd.BuildConfigFromFlags("", *kubeconfig)
		if err != nil {
			log.Fatalf("Error creating client config: %v\nPlease ensure you have a valid kubeconfig file at %s", err, *kubeconfig)
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
