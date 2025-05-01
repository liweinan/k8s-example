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

// SimpleAppReconciler reconciles a SimpleApp object
type SimpleAppReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=example.com,resources=simpleapps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=example.com,resources=simpleapps/status,verbs=get;update;patch

func (r *SimpleAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the SimpleApp instance
	simpleApp := &examplecomv1.SimpleApp{}
	err := r.Get(ctx, req.NamespacedName, simpleApp)
	if err != nil {
		logger.Error(err, "unable to fetch SimpleApp")
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Print "Hello, World!" and SimpleApp details
	logger.Info("Hello, World!", "AppName", simpleApp.Spec.AppName, "Replicas", simpleApp.Spec.Replicas)
	fmt.Printf("Hello, World! AppName: %s, Replicas: %d\n", simpleApp.Spec.AppName, simpleApp.Spec.Replicas)

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager
func (r *SimpleAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&examplecomv1.SimpleApp{}).
		Complete(r)
} 