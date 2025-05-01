package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// SimpleAppSpec defines the desired state of SimpleApp
type SimpleAppSpec struct {
	AppName  string `json:"appName"`
	Replicas int32  `json:"replicas"`
}

// SimpleAppStatus defines the observed state of SimpleApp
type SimpleAppStatus struct {
	// Add status fields if needed
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// SimpleApp is the Schema for the simpleapps API
type SimpleApp struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   SimpleAppSpec   `json:"spec,omitempty"`
	Status SimpleAppStatus `json:"status,omitempty"`
}

// DeepCopyInto copies all properties of this object into another object of the same type
func (in *SimpleApp) DeepCopyInto(out *SimpleApp) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	out.Spec = in.Spec
	out.Status = in.Status
}

// DeepCopy creates a deep copy of SimpleApp
func (in *SimpleApp) DeepCopy() *SimpleApp {
	if in == nil {
		return nil
	}
	out := new(SimpleApp)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject creates a deep copy of an object
func (in *SimpleApp) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// +kubebuilder:object:root=true

// SimpleAppList contains a list of SimpleApp
type SimpleAppList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []SimpleApp `json:"items"`
}

// DeepCopyInto copies all properties of this object into another object of the same type
func (in *SimpleAppList) DeepCopyInto(out *SimpleAppList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		in, out := &in.Items, &out.Items
		*out = make([]SimpleApp, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

// DeepCopy creates a deep copy of SimpleAppList
func (in *SimpleAppList) DeepCopy() *SimpleAppList {
	if in == nil {
		return nil
	}
	out := new(SimpleAppList)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject creates a deep copy of an object
func (in *SimpleAppList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

func init() {
	SchemeBuilder.Register(&SimpleApp{}, &SimpleAppList{})
} 