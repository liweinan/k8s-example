package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"k8s.io/api/admission/v1beta1"
	admissionregistrationv1beta1 "k8s.io/api/admissionregistration/v1beta1"
	networkingv1 "k8s.io/api/networking/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/klog"
)

var (
	runtimeScheme = runtime.NewScheme()
	codecs        = serializer.NewCodecFactory(runtimeScheme)
	deserializer  = codecs.UniversalDeserializer()
)

var (
	ignoredNamespaces = []string{
		metav1.NamespaceSystem,
		metav1.NamespacePublic,
	}
	requiredAnnotations = []string{
		"nginx.ingress.kubernetes.io/rewrite-target",
	}
)

type WebhookServer struct {
	server *http.Server
}

// Webhook Server parameters
type WhSvrParameters struct {
	port     int    // webhook server port
	certFile string // path to the x509 certificate for https
	keyFile  string // path to the x509 private key matching `CertFile`
}

func (whsvr *WebhookServer) serve(w http.ResponseWriter, r *http.Request) {
	var body []byte
	if r.Body != nil {
		if data, err := ioutil.ReadAll(r.Body); err == nil {
			body = data
		}
	}
	if len(body) == 0 {
		klog.Error("empty body")
		http.Error(w, "empty body", http.StatusBadRequest)
		return
	}

	// verify the content type is accurate
	contentType := r.Header.Get("Content-Type")
	if contentType != "application/json" {
		klog.Errorf("Content-Type=%s, expect application/json", contentType)
		http.Error(w, "invalid Content-Type, expect `application/json`", http.StatusUnsupportedMediaType)
		return
	}

	var admissionResponse *v1beta1.AdmissionResponse
	ar := v1beta1.AdmissionReview{}
	if _, _, err := deserializer.Decode(body, nil, &ar); err != nil {
		klog.Errorf("Can't decode body: %v", err)
		admissionResponse = &v1beta1.AdmissionResponse{
			Result: &metav1.Status{
				Message: err.Error(),
			},
		}
	} else {
		admissionResponse = whsvr.validate(&ar)
	}

	admissionReview := v1beta1.AdmissionReview{
		Response: admissionResponse,
	}
	if admissionResponse != nil {
		admissionReview.Response.UID = ar.Request.UID
	}

	resp, err := json.Marshal(admissionReview)
	if err != nil {
		klog.Errorf("Can't encode response: %v", err)
		http.Error(w, fmt.Sprintf("could not encode response: %v", err), http.StatusInternalServerError)
	}
	klog.Infof("Ready to write reponse ...")
	if _, err := w.Write(resp); err != nil {
		klog.Errorf("Can't write response: %v", err)
		http.Error(w, fmt.Sprintf("could not write response: %v", err), http.StatusInternalServerError)
	}
}

func (whsvr *WebhookServer) validate(ar *v1beta1.AdmissionReview) *v1beta1.AdmissionResponse {
	req := ar.Request
	var ingress networkingv1.Ingress
	if err := json.Unmarshal(req.Object.Raw, &ingress); err != nil {
		klog.Errorf("Could not unmarshal raw object: %v", err)
		return &v1beta1.AdmissionResponse{
			Result: &metav1.Status{
				Message: err.Error(),
			},
		}
	}

	klog.Infof("AdmissionReview for Kind=%v, Namespace=%v Name=%v (%v) UID=%v patchOperation=%v UserInfo=%v",
		req.Kind, req.Namespace, req.Name, ingress.Name, req.UID, req.Operation, req.UserInfo)

	// determine whether to perform validation
	if !validationRequired(ignoredNamespaces, &ingress.ObjectMeta) {
		klog.Infof("Skipping validation for %s/%s due to policy check", ingress.Namespace, ingress.Name)
		return &v1beta1.AdmissionResponse{
			Allowed: true,
		}
	}

	for _, annotation := range requiredAnnotations {
		if _, ok := ingress.Annotations[annotation]; !ok {
			return &v1beta1.AdmissionResponse{
				Result: &metav1.Status{
					Message: fmt.Sprintf("Required annotation '%s' is missing", annotation),
				},
			}
		}
	}

	return &v1beta1.AdmissionResponse{
		Allowed: true,
	}
}

func validationRequired(ignoredList []string, metadata *metav1.ObjectMeta) bool {
	for _, namespace := range ignoredList {
		if metadata.Namespace == namespace {
			klog.Infof("Skip validation for %v for it's in special namespace:%v", metadata.Name, metadata.Namespace)
			return false
		}
	}
	return true
}

func main() {
	// Add to scheme
	addToScheme(admissionregistrationv1beta1.AddToScheme)
	addToScheme(networkingv1.AddToScheme)

	params := WhSvrParameters{
		port:     8443,
		certFile: "/etc/webhook/certs/cert.pem",
		keyFile:  "/etc/webhook/certs/key.pem",
	}

	whsvr := &WebhookServer{
		server: &http.Server{
			Addr: fmt.Sprintf(":%d", params.port),
		},
	}

	http.HandleFunc("/validate", whsvr.serve)
	klog.Fatal(whsvr.server.ListenAndServeTLS(params.certFile, params.keyFile))
}

func addToScheme(addToSchemeFunc func(*runtime.Scheme) error) {
	if err := addToSchemeFunc(runtimeScheme); err != nil {
		klog.Fatalf("failed to add to scheme: %v", err)
	}
}
