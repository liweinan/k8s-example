package main

import (
	"context"
	"fmt"
	"log"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/clientcmd/api"
	"k8s.io/utils/pointer"
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
	config, err := clientConfig.ClientConfig()
	if err != nil {
		log.Fatalf("Error creating client config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Error creating clientset: %v", err)
	}

	// Create a test pod
	testPod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-pod-" + time.Now().Format("20060102150405"),
			Namespace: "default",
		},
		Spec: corev1.PodSpec{
			ServiceAccountName: "plank",
			AutomountServiceAccountToken: pointer.Bool(true),
			Containers: []corev1.Container{
				{
					Name:  "test",
					Image: "busybox",
					Command: []string{
						"sleep",
						"3600",
					},
					Env: []corev1.EnvVar{
						{
							Name:  "HTTP_PROXY",
							Value: "http://192.168.0.123:1080",
						},
						{
							Name:  "HTTPS_PROXY",
							Value: "http://192.168.0.123:1080",
						},
						{
							Name:  "NO_PROXY",
							Value: "localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.152.183.1",
						},
						{
							Name:  "KUBECONFIG",
							Value: "/etc/kubeconfig/config",
						},
					},
					VolumeMounts: []corev1.VolumeMount{
						{
							Name:      "kubeconfig",
							MountPath: "/etc/kubeconfig",
							ReadOnly:  true,
						},
					},
				},
			},
			Volumes: []corev1.Volume{
				{
					Name: "kubeconfig",
					VolumeSource: corev1.VolumeSource{
						Secret: &corev1.SecretVolumeSource{
							SecretName: "kubeconfig",
							DefaultMode: pointer.Int32(420),
						},
					},
				},
			},
		},
	}

	// Create a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create the pod
	fmt.Printf("Creating pod %s...\n", testPod.Name)
	createdPod, err := clientset.CoreV1().Pods("default").Create(ctx, testPod, metav1.CreateOptions{})
	if err != nil {
		log.Fatalf("Error creating pod: %v", err)
	}
	fmt.Printf("Pod created: %s\n", createdPod.Name)

	// Set up a watch for the pod
	watch, err := clientset.CoreV1().Pods("default").Watch(ctx, metav1.SingleObject(metav1.ObjectMeta{
		Name:      createdPod.Name,
		Namespace: "default",
	}))
	if err != nil {
		log.Fatalf("Error setting up watch: %v", err)
	}
	defer watch.Stop()

	// Wait for the pod to appear in the cache
	fmt.Println("Waiting for pod to appear in cache...")
	startTime := time.Now()
	for {
		select {
		case event, ok := <-watch.ResultChan():
			if !ok {
				log.Fatalf("Watch channel closed")
			}
			if event.Type == "ADDED" || event.Type == "MODIFIED" {
				pod := event.Object.(*corev1.Pod)
				fmt.Printf("Pod %s appeared in cache after %v\n", pod.Name, time.Since(startTime))
				return
			}
		case <-ctx.Done():
			log.Fatalf("Timeout waiting for pod to appear in cache after %v", time.Since(startTime))
		}
	}
}
