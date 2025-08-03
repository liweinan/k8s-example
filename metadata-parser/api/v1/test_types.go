package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Cluster
// +kubebuilder:printcolumn:name=Age,type=date,JSONPath=.metadata.creationTimestamp
// +kubebuilder:printcolumn:name=Status,type=string,JSONPath=.status.phase
// TestResource is a test resource for validation
type TestResource struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// spec defines the desired state of TestResource
	// +required
	// +kubebuilder:validation:Required
	Spec TestResourceSpec `json:"spec"`

	// status defines the observed state of TestResource
	// +optional
	// +kubebuilder:validation:Optional
	Status TestResourceStatus `json:"status,omitempty,omitzero"`
}

// TestResourceSpec defines the desired state of TestResource
type TestResourceSpec struct {
	// Name of the resource
	// +required
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	Name string `json:"name"`

	// Description of the resource
	// +optional
	// +kubebuilder:validation:Optional
	// +kubebuilder:default="Default description"
	Description string `json:"description,omitempty"`

	// Count of replicas
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	// +kubebuilder:default=1
	Replicas int32 `json:"replicas,omitempty"`

	// Tags for the resource
	// +optional
	// +listType=set
	Tags []string `json:"tags,omitempty"`
}

// TestResourceStatus defines the observed state of TestResource
type TestResourceStatus struct {
	// Phase of the resource
	// +optional
	// +kubebuilder:validation:Enum=Pending;Running;Succeeded;Failed
	Phase string `json:"phase,omitempty"`

	// Conditions represent the latest available observations of an object's state
	// +optional
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}
