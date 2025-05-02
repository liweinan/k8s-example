// Package main contains the entry point for the SimpleApp controller.
// This controller watches for SimpleApp custom resources and manages their lifecycle.
package main

import (
	"flag"
	"os"

	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	_ "k8s.io/client-go/plugin/pkg/client/auth" // Import for authentication providers
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	examplecomv1 "simpleapp-controller/api/v1"
	"simpleapp-controller/controllers"
)

// Global scheme for runtime objects
var (
	scheme = runtime.NewScheme()
)

// init registers the Kubernetes API schemes with our runtime scheme
func init() {
	// Add standard Kubernetes types to the scheme
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))
	// Add our custom SimpleApp types to the scheme
	utilruntime.Must(examplecomv1.AddToScheme(scheme))
}

// main is the entry point for the controller
func main() {
	// Command line flags for controller configuration
	var metricsAddr string
	var enableLeaderElection bool
	var probeAddr string
	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false, "Enable leader election for controller manager.")
	flag.Parse()

	// Set up structured logging using zap
	ctrl.SetLogger(zap.New(zap.UseDevMode(true)))

	// Create a new controller manager with the specified options
	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                        scheme,
		HealthProbeBindAddress:        probeAddr,
		LeaderElection:               enableLeaderElection,
		LeaderElectionID:             "simpleapp-controller.example.com",
	})
	if err != nil {
		ctrl.Log.Error(err, "unable to start manager")
		os.Exit(1)
	}

	// Set up the SimpleApp reconciler with the manager
	if err = (&controllers.SimpleAppReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
	}).SetupWithManager(mgr); err != nil {
		ctrl.Log.Error(err, "unable to create controller", "controller", "SimpleApp")
		os.Exit(1)
	}

	// Add health and readiness probes
	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		ctrl.Log.Error(err, "unable to set up health check")
		os.Exit(1)
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		ctrl.Log.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	// Start the controller manager
	ctrl.Log.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		ctrl.Log.Error(err, "problem running manager")
		os.Exit(1)
	}
} 