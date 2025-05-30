/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ApplicationSpec defines the desired state of Application
type ApplicationSpec struct {
	// Image is the container image to run
	// +kubebuilder:validation:Required
	Image string `json:"image"`

	// Replicas is the number of desired pods
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=1
	Replicas int32 `json:"replicas,omitempty"`

	// Port is the port that the application listens on
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=80
	Port int32 `json:"port,omitempty"`

	// Resources defines the compute resources required
	Resources ResourceRequirements `json:"resources,omitempty"`

	// Env is a list of environment variables to set in the container
	Env []EnvVar `json:"env,omitempty"`
}

// ResourceRequirements describes the compute resource requirements
type ResourceRequirements struct {
	// CPU request in cores (e.g. 100m, 0.1, 1)
	// +kubebuilder:default="100m"
	CPURequest string `json:"cpuRequest,omitempty"`

	// Memory request (e.g. 64Mi, 1Gi)
	// +kubebuilder:default="128Mi"
	MemoryRequest string `json:"memoryRequest,omitempty"`

	// CPU limit in cores (e.g. 100m, 0.1, 1)
	// +kubebuilder:default="200m"
	CPULimit string `json:"cpuLimit,omitempty"`

	// Memory limit (e.g. 64Mi, 1Gi)
	// +kubebuilder:default="256Mi"
	MemoryLimit string `json:"memoryLimit,omitempty"`
}

// EnvVar represents an environment variable
type EnvVar struct {
	// Name of the environment variable
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Value of the environment variable
	Value string `json:"value,omitempty"`
}

// ApplicationStatus defines the observed state of Application
type ApplicationStatus struct {
	// AvailableReplicas is the number of available replicas
	AvailableReplicas int32 `json:"availableReplicas,omitempty"`

	// Conditions represent the latest available observations of the application's current state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// LastUpdateTime is the last time the status was updated
	LastUpdateTime metav1.Time `json:"lastUpdateTime,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Image",type="string",JSONPath=".spec.image"
//+kubebuilder:printcolumn:name="Replicas",type="integer",JSONPath=".spec.replicas"
//+kubebuilder:printcolumn:name="Available",type="integer",JSONPath=".status.availableReplicas"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// Application is the Schema for the applications API
type Application struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ApplicationSpec   `json:"spec,omitempty"`
	Status ApplicationStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ApplicationList contains a list of Application
type ApplicationList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Application `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Application{}, &ApplicationList{})
}
