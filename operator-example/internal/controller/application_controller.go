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

package controller

import (
	"context"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	appsv1alpha1 "github.com/liweinan/k8s-example/operator-example/api/v1alpha1"
)

// ApplicationReconciler reconciles a Application object
type ApplicationReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=apps.example.com,resources=applications,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps.example.com,resources=applications/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps.example.com,resources=applications/finalizers,verbs=update
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Application object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.17.0/pkg/reconcile
func (r *ApplicationReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	// Fetch the Application instance
	application := &appsv1alpha1.Application{}
	err := r.Get(ctx, req.NamespacedName, application)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			log.Info("Application resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the request.
		log.Error(err, "Failed to get Application")
		return ctrl.Result{}, err
	}

	// Check if the deployment already exists, if not create a new one
	foundDeployment := &appsv1.Deployment{}
	err = r.Get(ctx, types.NamespacedName{Name: application.Name, Namespace: application.Namespace}, foundDeployment)
	if err != nil && errors.IsNotFound(err) {
		// Define a new deployment
		dep := r.deploymentForApplication(application)
		log.Info("Creating a new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
		err = r.Create(ctx, dep)
		if err != nil {
			log.Error(err, "Failed to create new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
			return ctrl.Result{}, err
		}
		// Deployment created successfully - return and requeue
		return ctrl.Result{Requeue: true}, nil
	} else if err != nil {
		log.Error(err, "Failed to get Deployment")
		return ctrl.Result{}, err
	}

	// Check if the service already exists, if not create a new one
	foundService := &corev1.Service{}
	err = r.Get(ctx, types.NamespacedName{Name: application.Name, Namespace: application.Namespace}, foundService)
	if err != nil && errors.IsNotFound(err) {
		// Define a new service
		svc := r.serviceForApplication(application)
		log.Info("Creating a new Service", "Service.Namespace", svc.Namespace, "Service.Name", svc.Name)
		err = r.Create(ctx, svc)
		if err != nil {
			log.Error(err, "Failed to create new Service", "Service.Namespace", svc.Namespace, "Service.Name", svc.Name)
			return ctrl.Result{}, err
		}
		// Service created successfully - return and requeue
		return ctrl.Result{Requeue: true}, nil
	} else if err != nil {
		log.Error(err, "Failed to get Service")
		return ctrl.Result{}, err
	}

	// Update the Application status with the deployment status
	if err := r.updateApplicationStatus(ctx, application, foundDeployment); err != nil {
		log.Error(err, "Failed to update Application status")
		return ctrl.Result{Requeue: true}, nil
	}

	return ctrl.Result{RequeueAfter: time.Minute}, nil
}

// deploymentForApplication returns a application Deployment object
func (r *ApplicationReconciler) deploymentForApplication(app *appsv1alpha1.Application) *appsv1.Deployment {
	labels := map[string]string{
		"app": app.Name,
	}

	// Create resource requirements
	resources := corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse(app.Spec.Resources.CPURequest),
			corev1.ResourceMemory: resource.MustParse(app.Spec.Resources.MemoryRequest),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse(app.Spec.Resources.CPULimit),
			corev1.ResourceMemory: resource.MustParse(app.Spec.Resources.MemoryLimit),
		},
	}

	// Create environment variables
	var envVars []corev1.EnvVar
	for _, env := range app.Spec.Env {
		envVars = append(envVars, corev1.EnvVar{
			Name:  env.Name,
			Value: env.Value,
		})
	}

	dep := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      app.Name,
			Namespace: app.Namespace,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &app.Spec.Replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{{
						Image: app.Spec.Image,
						Name:  app.Name,
						Ports: []corev1.ContainerPort{{
							ContainerPort: app.Spec.Port,
							Name:          "http",
						}},
						Resources: resources,
						Env:       envVars,
					}},
				},
			},
		},
	}

	// Set Application instance as the owner and controller
	ctrl.SetControllerReference(app, dep, r.Scheme)
	return dep
}

// serviceForApplication returns a application Service object
func (r *ApplicationReconciler) serviceForApplication(app *appsv1alpha1.Application) *corev1.Service {
	labels := map[string]string{
		"app": app.Name,
	}

	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      app.Name,
			Namespace: app.Namespace,
		},
		Spec: corev1.ServiceSpec{
			Selector: labels,
			Ports: []corev1.ServicePort{{
				Port:       app.Spec.Port,
				TargetPort: intstr.FromInt(int(app.Spec.Port)),
				Protocol:   corev1.ProtocolTCP,
				Name:       "http",
			}},
			Type: corev1.ServiceTypeClusterIP,
		},
	}

	// Set Application instance as the owner and controller
	ctrl.SetControllerReference(app, svc, r.Scheme)
	return svc
}

// updateApplicationStatus updates the status of the Application resource
func (r *ApplicationReconciler) updateApplicationStatus(ctx context.Context, app *appsv1alpha1.Application, deployment *appsv1.Deployment) error {
	// Create a copy of the application to modify
	appCopy := app.DeepCopy()

	// Update the status
	appCopy.Status.AvailableReplicas = deployment.Status.AvailableReplicas
	appCopy.Status.ReadyReplicas = deployment.Status.ReadyReplicas
	appCopy.Status.UpdatedReplicas = deployment.Status.UpdatedReplicas

	// Use Patch instead of Update to avoid conflicts
	return r.Status().Patch(ctx, appCopy, client.MergeFrom(app))
}

// SetupWithManager sets up the controller with the Manager.
func (r *ApplicationReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&appsv1alpha1.Application{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Complete(r)
}
