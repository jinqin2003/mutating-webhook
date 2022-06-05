package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/jinqin2003/mutating-webhook/pkg/admission"
	"github.com/sirupsen/logrus"
	admissionv1 "k8s.io/api/admission/v1"
)

var (
	validationRequests = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_validation_requests_total",
			Help: "harbor proxy webhook validation HTTP Requests",
		})

	validationnRequestErrors = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_validation_request_errors_total",
			Help: "harbor proxy webhook validation HTTP request errors",
		})

	validationnResponseStatus = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_validation_response_status",
			Help: "harbor proxy webhook validation HTTP response status",
		}, []string{"status"})

	validationnHTTPRequestDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name: "harbor_proxy_webhook_validationn_http_request_duration_seconds",
			Help: "harbor proxy webhook validationn HTTP request duration seconds",
		})

	mutationRequests = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_mutation_requests_total",
			Help: "harbor proxy webhook mutation HTTP requests",
		})

	mutationRequestErrors = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_mutation_request_errors_total",
			Help: "harbor proxy webhook mutation HTTP request errors",
		})

	mutationResponseStatus = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "harbor_proxy_webhook_mutation_response_status",
			Help: "harbor proxy webhook mutation HTTP response status",
		}, []string{"status"})

	mutationHTTPRequestDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name: "harbor_proxy_webhook_mutation_http_request_duration_seconds",
			Help: "harbor proxy webhook mutation HTTP request duration seconds",
		})
)

func main() {
	setLogger()

	// handle our core application
	http.HandleFunc("/validate-pods", ServeValidatePods)
	http.HandleFunc("/mutate-pods", ServeMutatePods)
	http.HandleFunc("/health", ServeHealth)

	// create new multiplexer for Prometheus
	promMux := http.NewServeMux()
	promMux.Handle("/metrics", promhttp.Handler())

	// Prometheus metrics need to be served off a separate port so we can disable mTLS
	go func() {
		http.ListenAndServe(":7777", promMux)
		logrus.Print("Listening on port 7777 for prometheus metrics...")
	}()

	// start the server
	// listens to clear text http on port 8080 unless TLS env var is set to "true"
	if os.Getenv("TLS") == "true" {
		cert := "/etc/admission-webhook/tls/tls.crt"
		key := "/etc/admission-webhook/tls/tls.key"
		logrus.Print("Listening on port 443...")
		logrus.Fatal(http.ListenAndServeTLS(":443", cert, key, nil))
	} else {
		logrus.Print("Listening on port 8080...")
		logrus.Fatal(http.ListenAndServe(":8080", nil))
	}
}

// ServeHealth returns 200 when things are good
func ServeHealth(w http.ResponseWriter, r *http.Request) {
	logrus.WithField("uri", r.RequestURI).Debug("healthy")
	fmt.Fprint(w, "OK")
}

// ServeValidatePods validates an admission request and then writes an admission
// review to `w`
func ServeValidatePods(w http.ResponseWriter, r *http.Request) {
	logger := logrus.WithField("uri", r.RequestURI)
	logger.Debug("received validation request")

	timer := prometheus.NewTimer(validationnHTTPRequestDuration)
	validationRequests.Inc()

	in, err := parseRequest(*r)
	if err != nil {
		logger.Error(err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		validationnRequestErrors.Inc()
		validationnResponseStatus.WithLabelValues(strconv.Itoa(http.StatusBadRequest)).Inc()
		return
	}

	adm := admission.Admitter{
		Logger:  logger,
		Request: in.Request,
	}

	out, err := adm.ValidatePodReview()
	if err != nil {
		e := fmt.Sprintf("could not generate admission response: %v", err)
		logger.Error(e)
		http.Error(w, e, http.StatusInternalServerError)
		validationnRequestErrors.Inc()
		validationnResponseStatus.WithLabelValues(strconv.Itoa(http.StatusInternalServerError)).Inc()
		return
	}

	w.Header().Set("Content-Type", "application/json")
	jout, err := json.Marshal(out)
	if err != nil {
		e := fmt.Sprintf("could not parse admission response: %v", err)
		logger.Error(e)
		http.Error(w, e, http.StatusInternalServerError)
		validationnRequestErrors.Inc()
		validationnResponseStatus.WithLabelValues(strconv.Itoa(http.StatusInternalServerError)).Inc()
		return
	}

	validationnResponseStatus.WithLabelValues(strconv.Itoa(http.StatusOK)).Inc()
	timer.ObserveDuration()
	logger.Debug("sending response")
	logger.Debugf("%s", jout)
	fmt.Fprintf(w, "%s", jout)
}

// ServeMutatePods returns an admission review with pod mutations as a json patch
// in the review response
func ServeMutatePods(w http.ResponseWriter, r *http.Request) {
	logger := logrus.WithField("uri", r.RequestURI)
	logger.Debug("received mutation request")

	timer := prometheus.NewTimer(mutationHTTPRequestDuration)
	mutationRequests.Inc()

	in, err := parseRequest(*r)
	if err != nil {
		logger.Error(err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		mutationRequestErrors.Inc()
		mutationResponseStatus.WithLabelValues(strconv.Itoa(http.StatusBadRequest)).Inc()
		return
	}

	adm := admission.Admitter{
		Logger:  logger,
		Request: in.Request,
	}

	out, err := adm.MutatePodReview()
	if err != nil {
		e := fmt.Sprintf("could not generate admission response: %v", err)
		logger.Error(e)
		http.Error(w, e, http.StatusInternalServerError)
		mutationRequestErrors.Inc()
		mutationResponseStatus.WithLabelValues(strconv.Itoa(http.StatusInternalServerError)).Inc()
		return
	}

	w.Header().Set("Content-Type", "application/json")
	jout, err := json.Marshal(out)
	if err != nil {
		e := fmt.Sprintf("could not parse admission response: %v", err)
		logger.Error(e)
		http.Error(w, e, http.StatusInternalServerError)
		mutationRequestErrors.Inc()
		mutationResponseStatus.WithLabelValues(strconv.Itoa(http.StatusInternalServerError)).Inc()
		return
	}

	mutationResponseStatus.WithLabelValues(strconv.Itoa(http.StatusOK)).Inc()
	timer.ObserveDuration()
	logger.Debug("sending response")
	logger.Debugf("%s", jout)
	fmt.Fprintf(w, "%s", jout)
}

// setLogger sets the logger using env vars, it defaults to text logs on
// debug level unless otherwise specified
func setLogger() {
	logrus.SetLevel(logrus.DebugLevel)

	lev := os.Getenv("LOG_LEVEL")
	if lev != "" {
		llev, err := logrus.ParseLevel(lev)
		if err != nil {
			logrus.Fatalf("cannot set LOG_LEVEL to %q", lev)
		}
		logrus.SetLevel(llev)
	}

	if os.Getenv("LOG_JSON") == "true" {
		logrus.SetFormatter(&logrus.JSONFormatter{})
	}
}

// parseRequest extracts an AdmissionReview from an http.Request if possible
func parseRequest(r http.Request) (*admissionv1.AdmissionReview, error) {
	if r.Header.Get("Content-Type") != "application/json" {
		return nil, fmt.Errorf("Content-Type: %q should be %q",
			r.Header.Get("Content-Type"), "application/json")
	}

	bodybuf := new(bytes.Buffer)
	bodybuf.ReadFrom(r.Body)
	body := bodybuf.Bytes()

	if len(body) == 0 {
		return nil, fmt.Errorf("admission request body is empty")
	}

	var a admissionv1.AdmissionReview

	if err := json.Unmarshal(body, &a); err != nil {
		mutationRequestErrors.Inc()
		return nil, fmt.Errorf("could not parse admission review request: %v", err)
	}

	if a.Request == nil {
		mutationRequestErrors.Inc()
		return nil, fmt.Errorf("admission review can't be used: Request field is nil")
	}

	return &a, nil
}
