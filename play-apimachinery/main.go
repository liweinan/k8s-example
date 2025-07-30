package main

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/util/yaml"
)

func main() {
	fmt.Println("=== Apimachinery Minimal Example ===\n")

	// Example 1: Create a simple Pod using unstructured.Unstructured
	fmt.Println("1. Creating a Pod using unstructured.Unstructured:")
	createPodExample()

	fmt.Println("\n" + strings.Repeat("=", 50) + "\n")

	// Example 2: Parse YAML to unstructured object
	fmt.Println("2. Parsing YAML to unstructured object:")
	parseYAMLExample()

	fmt.Println("\n" + strings.Repeat("=", 50) + "\n")

	// Example 3: Working with ObjectMeta
	fmt.Println("3. Working with ObjectMeta:")
	objectMetaExample()

	fmt.Println("\n" + strings.Repeat("=", 50) + "\n")

	// Example 4: Type conversion example
	fmt.Println("4. Type conversion example:")
	typeConversionExample()
}

func createPodExample() {
	// Create a Pod using unstructured.Unstructured
	pod := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "v1",
			"kind":       "Pod",
			"metadata": map[string]interface{}{
				"name":      "example-pod",
				"namespace": "default",
				"labels": map[string]interface{}{
					"app": "example",
				},
			},
			"spec": map[string]interface{}{
				"containers": []interface{}{
					map[string]interface{}{
						"name":  "nginx",
						"image": "nginx:latest",
						"ports": []interface{}{
							map[string]interface{}{
								"containerPort": 80,
							},
						},
					},
				},
			},
		},
	}

	// Convert to JSON and print
	podJSON, err := json.MarshalIndent(pod.Object, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Pod JSON:\n%s\n", string(podJSON))
}

func parseYAMLExample() {
	yamlData := `
apiVersion: v1
kind: Service
metadata:
  name: example-service
  namespace: default
spec:
  selector:
    app: example
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
`

	// Parse YAML to unstructured object
	obj, err := yaml.ToUnstructured([]byte(yamlData))
	if err != nil {
		log.Fatal(err)
	}

	// Convert to JSON and print
	objJSON, err := json.MarshalIndent(obj, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Parsed Service JSON:\n%s\n", string(objJSON))
}

func objectMetaExample() {
	// Create ObjectMeta
	objectMeta := metav1.ObjectMeta{
		Name:      "example-deployment",
		Namespace: "default",
		Labels: map[string]string{
			"app":     "example",
			"version": "v1",
		},
		Annotations: map[string]string{
			"description": "Example deployment created with apimachinery",
		},
	}

	// Create a Deployment with the ObjectMeta
	deployment := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "apps/v1",
			"kind":       "Deployment",
			"metadata":   objectMeta,
			"spec": map[string]interface{}{
				"replicas": 3,
				"selector": map[string]interface{}{
					"matchLabels": map[string]interface{}{
						"app": "example",
					},
				},
				"template": map[string]interface{}{
					"metadata": map[string]interface{}{
						"labels": map[string]interface{}{
							"app": "example",
						},
					},
					"spec": map[string]interface{}{
						"containers": []interface{}{
							map[string]interface{}{
								"name":  "app",
								"image": "nginx:latest",
							},
						},
					},
				},
			},
		},
	}

	// Convert to JSON and print
	deploymentJSON, err := json.MarshalIndent(deployment.Object, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Deployment JSON:\n%s\n", string(deploymentJSON))
}

func typeConversionExample() {
	// Create a ConfigMap using unstructured
	configMap := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "v1",
			"kind":       "ConfigMap",
			"metadata": map[string]interface{}{
				"name":      "example-config",
				"namespace": "default",
			},
			"data": map[string]interface{}{
				"config.json": `{"key": "value"}`,
				"app.conf":    "debug=true",
			},
		},
	}

	// Get the GVK (Group Version Kind)
	gvk := configMap.GetObjectKind().GroupVersionKind()
	fmt.Printf("GVK: %s\n", gvk)

	// Get the name and namespace
	name := configMap.GetName()
	namespace := configMap.GetNamespace()
	fmt.Printf("Name: %s, Namespace: %s\n", name, namespace)

	// Access nested fields
	data, found, err := unstructured.NestedMap(configMap.Object, "data")
	if err != nil {
		log.Fatal(err)
	}
	if found {
		fmt.Printf("ConfigMap data: %+v\n", data)
	}

	// Convert to JSON and print
	configMapJSON, err := json.MarshalIndent(configMap.Object, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("ConfigMap JSON:\n%s\n", string(configMapJSON))
}
