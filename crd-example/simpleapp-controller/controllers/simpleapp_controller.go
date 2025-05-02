// Package controllers contains the implementation of the SimpleApp controller.
// This controller watches for changes to SimpleApp resources and performs reconciliation.
package controllers

import (
	"context"
	"fmt"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	examplecomv1 "simpleapp-controller/api/v1"
)

// SimpleAppReconciler is the main controller type that implements the reconciliation logic
// for SimpleApp custom resources.
type SimpleAppReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// RBAC permissions required by the controller
// These annotations are used by kubebuilder to generate the RBAC manifests
//+kubebuilder:rbac:groups=example.com,resources=simpleapps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=example.com,resources=simpleapps/status,verbs=get;update;patch

// Reconcile is the main reconciliation loop for SimpleApp resources.
// It is called whenever a SimpleApp is created, updated, or deleted.
func (r *SimpleAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	// Get a logger with context for structured logging
	logger := log.FromContext(ctx)

	// Fetch the SimpleApp instance from the Kubernetes API
	simpleApp := &examplecomv1.SimpleApp{}
	err := r.Get(ctx, req.NamespacedName, simpleApp)
	if err != nil {
		// If the resource is not found, return without error
		// This handles the case where the resource was deleted
		logger.Error(err, "unable to fetch SimpleApp")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Log the SimpleApp details using both structured logging and fmt.Printf
	// This demonstrates two different logging approaches
	logger.Info("Hello, World!", "AppName", simpleApp.Spec.AppName, "Replicas", simpleApp.Spec.Replicas)
	fmt.Printf("Hello, World! AppName: %s, Replicas: %d\n", simpleApp.Spec.AppName, simpleApp.Spec.Replicas)

	// Return no error and no requeue, indicating successful reconciliation
	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
// This method is called by the main function to register the controller
// with the controller-runtime manager.
func (r *SimpleAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		// Watch for changes to SimpleApp resources
		For(&examplecomv1.SimpleApp{}).
		// Complete the controller setup
		Complete(r)
}
