# Kubernetes Apimachinery Minimal Example

This directory contains a minimal example demonstrating the usage of Kubernetes `apimachinery` package. The example shows how to create and manipulate Kubernetes API objects programmatically using Go.

## Overview

The `apimachinery` package provides the core types and utilities for working with Kubernetes API objects. This example demonstrates four key concepts:

1. **Creating unstructured objects** - Building Kubernetes resources using `unstructured.Unstructured`
2. **YAML parsing** - Converting YAML to unstructured objects
3. **Working with ObjectMeta** - Using typed metadata structures
4. **Type conversion and field access** - Accessing object properties and nested fields

## Project Structure

```
play-apimachinery/
├── main.go          # Main example code
├── go.mod           # Go module definition
└── README.md        # This file
```

## Dependencies

- `k8s.io/apimachinery v0.28.4` - Core Kubernetes API machinery
- Various indirect dependencies for JSON/YAML processing, logging, etc.

## Code Analysis

### Main Function

The main function orchestrates four different examples, each demonstrating a specific aspect of apimachinery:

```go
func main() {
    // Example 1: Creating Pod using unstructured.Unstructured
    // Example 2: Parsing YAML to unstructured object  
    // Example 3: Working with ObjectMeta
    // Example 4: Type conversion example
}
```

### Example 1: Creating Pod with Unstructured

**Function**: `createPodExample()`

This example shows how to create a Kubernetes Pod using the `unstructured.Unstructured` type:

```go
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
```

**Key Points**:
- Uses `map[string]interface{}` for flexible object construction
- Demonstrates nested structure creation
- Shows how to convert to JSON for output

### Example 2: YAML to Unstructured Parsing

**Function**: `parseYAMLExample()`

This example demonstrates parsing YAML data into unstructured objects:

```go
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

obj, err := yaml.ToUnstructured([]byte(yamlData))
```

**Key Points**:
- Uses `yaml.ToUnstructured()` to parse YAML
- Shows how to work with Service resources
- Demonstrates YAML to JSON conversion

### Example 3: Working with ObjectMeta

**Function**: `objectMetaExample()`

This example shows how to use typed `metav1.ObjectMeta` structures:

```go
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
```

**Key Points**:
- Uses strongly-typed `metav1.ObjectMeta`
- Demonstrates label and annotation management
- Shows integration with unstructured objects

### Example 4: Type Conversion and Field Access

**Function**: `typeConversionExample()`

This example demonstrates advanced object manipulation:

```go
// Get GVK (Group Version Kind)
gvk := configMap.GetObjectKind().GroupVersionKind()

// Get name and namespace
name := configMap.GetName()
namespace := configMap.GetNamespace()

// Access nested fields
data, found, err := unstructured.NestedMap(configMap.Object, "data")
```

**Key Points**:
- Shows how to access object metadata
- Demonstrates nested field access using `unstructured.NestedMap()`
- Illustrates GVK (Group Version Kind) retrieval

## Key Apimachinery Concepts Demonstrated

### 1. Unstructured Objects

The `unstructured.Unstructured` type allows you to work with Kubernetes objects without having strongly-typed structs for every resource type. This is useful for:
- Generic object manipulation
- Working with Custom Resource Definitions (CRDs)
- Dynamic object creation

### 2. YAML Processing

The `yaml` package provides utilities for:
- Converting YAML to unstructured objects
- Parsing Kubernetes manifests
- Working with multi-document YAML files

### 3. Object Metadata

The `metav1` package provides typed structures for:
- `ObjectMeta` - Standard Kubernetes object metadata
- `TypeMeta` - API version and kind information
- Various utility functions for metadata manipulation

### 4. Field Access

The `unstructured` package provides helper functions for:
- `NestedMap()` - Access nested map fields
- `NestedSlice()` - Access nested slice fields
- `NestedString()` - Access nested string fields
- `SetNestedField()` - Set nested fields

## Usage

To run this example:

```bash
cd play-apimachinery
go mod tidy
go run main.go
```

## Expected Output

The program will output four sections, each showing:
1. A Pod JSON representation
2. A Service JSON representation (parsed from YAML)
3. A Deployment JSON representation (using ObjectMeta)
4. A ConfigMap JSON representation with field access examples

## Learning Objectives

After studying this example, you should understand:

1. **How to create Kubernetes objects programmatically**
2. **How to parse YAML manifests into Go objects**
3. **How to work with object metadata**
4. **How to access and manipulate nested object fields**
5. **The difference between structured and unstructured approaches**

## Common Use Cases

This apimachinery knowledge is useful for:
- Building Kubernetes operators
- Creating custom controllers
- Writing admission webhooks
- Developing CLI tools for Kubernetes
- Processing Kubernetes manifests programmatically

## Related Resources

- [Kubernetes Apimachinery Documentation](https://pkg.go.dev/k8s.io/apimachinery)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) 