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
	fmt.Println("\n=== Environment Information ===")
	fmt.Printf("Current user: %s\n", os.Getenv("USER"))
	fmt.Printf("HOME directory: %s\n", os.Getenv("HOME"))
	fmt.Printf("KUBECONFIG: %s\n", os.Getenv("KUBECONFIG"))
	fmt.Printf("Current working directory: %s\n", getCurrentDir())

	// Check k8s kubectl
	if _, err := exec.LookPath("k8s"); err == nil {
		cmd := exec.Command("k8s", "kubectl", "config", "view")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("Error running k8s kubectl config view: %v\n", err)
		} else {
			fmt.Println("\n=== K8s Kubectl Configuration ===")
			fmt.Println(string(output))
		}

		// Get cluster info
		cmd = exec.Command("k8s", "kubectl", "cluster-info")
		output, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("Error getting cluster info: %v\n", err)
		} else {
			fmt.Println("\n=== Cluster Information ===")
			fmt.Println(string(output))
		}

		// Get node info
		cmd = exec.Command("k8s", "kubectl", "get", "nodes", "-o", "wide")
		output, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("Error getting node info: %v\n", err)
		} else {
			fmt.Println("\n=== Node Information ===")
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
			// Check file permissions
			if info, err := os.Stat(path); err == nil {
				fmt.Printf("  Permissions: %v\n", info.Mode())
				fmt.Printf("  Size: %d bytes\n", info.Size())
				fmt.Printf("  Last modified: %v\n", info.ModTime())
			}
		} else {
			fmt.Printf("No kubeconfig at: %s\n", path)
		}
	}
	fmt.Println("===================================")
}

func getCurrentDir() string {
	dir, err := os.Getwd()
	if err != nil {
		return fmt.Sprintf("Error getting current directory: %v", err)
	}
	return dir
}

func getKubeconfigPath() string {
	fmt.Println("\n=== Kubeconfig Path Resolution ===")

	// First try KUBECONFIG environment variable
	if kubeconfig := os.Getenv("KUBECONFIG"); kubeconfig != "" {
		fmt.Printf("Using KUBECONFIG from environment: %s\n", kubeconfig)
		return kubeconfig
	}
	fmt.Println("No KUBECONFIG environment variable set")

	// Try to get config from k8s kubectl
	fmt.Println("\nTrying to get config from k8s kubectl...")
	cmd := exec.Command("k8s", "kubectl", "config", "view", "--raw")
	output, err := cmd.CombinedOutput()
	if err == nil {
		// Create a temporary file with the config
		tmpFile := filepath.Join(os.TempDir(), "kubeconfig")
		fmt.Printf("Creating temporary kubeconfig at: %s\n", tmpFile)
		if err := os.WriteFile(tmpFile, output, 0600); err == nil {
			fmt.Printf("Successfully created temporary kubeconfig\n")
			return tmpFile
		} else {
			fmt.Printf("Failed to create temporary kubeconfig: %v\n", err)
		}
	} else {
		fmt.Printf("Failed to get config from k8s kubectl: %v\n", err)
	}

	// If all else fails, return the default path
	defaultPath := filepath.Join(os.Getenv("HOME"), ".kube", "config")
	fmt.Printf("\nFalling back to default path: %s\n", defaultPath)
	fmt.Println("===================================")
	return defaultPath
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
	fmt.Printf("\n=== Creating Pod ===\n")
	fmt.Printf("Name: %s\n", podName)
	fmt.Printf("Namespace: %s\n", *namespace)
	fmt.Printf("Image: nginx:latest\n")
	fmt.Printf("Port: 80\n")

	createdPod, err := clientset.CoreV1().Pods(*namespace).Create(context.TODO(), pod, metav1.CreateOptions{})
	if err != nil {
		log.Fatalf("Error creating pod: %v", err)
	}
	fmt.Printf("Pod created successfully: %s\n", createdPod.Name)

	// Wait for pod to be ready
	fmt.Println("\n=== Waiting for Pod to be Ready ===")
	startTime := time.Now()
	for {
		pod, err := clientset.CoreV1().Pods(*namespace).Get(context.TODO(), podName, metav1.GetOptions{})
		if err != nil {
			log.Fatalf("Error getting pod status: %v", err)
		}

		// Print detailed status
		fmt.Printf("\nPod Status at %v:\n", time.Now().Format("15:04:05"))
		fmt.Printf("Phase: %s\n", pod.Status.Phase)
		fmt.Printf("IP: %s\n", pod.Status.PodIP)
		fmt.Printf("Node: %s\n", pod.Spec.NodeName)

		if len(pod.Status.ContainerStatuses) > 0 {
			containerStatus := pod.Status.ContainerStatuses[0]
			fmt.Printf("Container Status:\n")
			fmt.Printf("  Ready: %v\n", containerStatus.Ready)
			fmt.Printf("  State: %v\n", containerStatus.State)
			if containerStatus.State.Running != nil {
				fmt.Printf("  Started: %v\n", containerStatus.State.Running.StartedAt)
			}
		}

		if pod.Status.Phase == corev1.PodRunning {
			fmt.Printf("\nPod is now running! (took %v)\n", time.Since(startTime))
			break
		}

		time.Sleep(2 * time.Second)
	}

	// Print final pod information
	fmt.Println("\n=== Final Pod Information ===")
	pod, err = clientset.CoreV1().Pods(*namespace).Get(context.TODO(), podName, metav1.GetOptions{})
	if err != nil {
		log.Printf("Error getting final pod status: %v", err)
	} else {
		fmt.Printf("Name: %s\n", pod.Name)
		fmt.Printf("Namespace: %s\n", pod.Namespace)
		fmt.Printf("IP: %s\n", pod.Status.PodIP)
		fmt.Printf("Node: %s\n", pod.Spec.NodeName)
		fmt.Printf("Creation Time: %v\n", pod.CreationTimestamp)
		fmt.Printf("Phase: %s\n", pod.Status.Phase)
	}
}
