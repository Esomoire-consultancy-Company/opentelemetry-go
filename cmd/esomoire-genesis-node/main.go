package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"
)

const defaultManifestURL = "https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml"

var requiredEnv = []string{
	"DATABASE_URL",
	"OBJECT_STORE_BUCKET",
	"OBJECT_STORE_ENDPOINT",
	"OBJECT_STORE_ACCESS_KEY_ID",
	"OBJECT_STORE_SECRET_ACCESS_KEY",
	"JWT_ISSUER",
	"JWT_AUDIENCE",
	"JWT_JWKS_URL",
	"OTEL_EXPORTER_OTLP_ENDPOINT",
	"OTEL_EXPORTER_OTLP_HEADERS",
}

type server struct {
	startedAt   time.Time
	manifestURL string
	httpClient  *http.Client
}

type statusResponse struct {
	Service        string            `json:"service"`
	Status         string            `json:"status"`
	NodeName       string            `json:"node_name,omitempty"`
	NodeID         string            `json:"node_id,omitempty"`
	SiteID         string            `json:"site_id,omitempty"`
	ManifestURL    string            `json:"manifest_url"`
	UptimeSeconds  int64             `json:"uptime_seconds"`
	Checks         map[string]string `json:"checks,omitempty"`
	MissingEnv     []string          `json:"missing_env,omitempty"`
	CheckedAt      string            `json:"checked_at"`
	DeploymentMode string            `json:"deployment_mode"`
}

func main() {
	port := envOrDefault("GENESIS_REGISTRY_PORT", "8081")
	manifestURL := envOrDefault("GENESIS_MANIFEST_URL", defaultManifestURL)

	srv := &server{
		startedAt:   time.Now().UTC(),
		manifestURL: manifestURL,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", srv.root)
	mux.HandleFunc("/healthz", srv.health)
	mux.HandleFunc("/readyz", srv.ready)
	mux.HandleFunc("/manifestz", srv.manifest)

	addr := ":" + port
	log.Printf("starting esomoire genesis node on %s", addr)
	log.Printf("manifest url: %s", manifestURL)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func (s *server) root(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service":      "esomoire-genesis-node",
		"status":       "running",
		"health_path":  "/healthz",
		"ready_path":   "/readyz",
		"manifest_path": "/manifestz",
	})
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.baseResponse("healthy"))
}

func (s *server) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()

	checks := map[string]string{}
	missing := missingRequiredEnv(requiredEnv)
	if len(missing) == 0 {
		checks["environment"] = "ok"
	} else {
		checks["environment"] = "missing_required_values"
	}

	if err := s.checkManifest(ctx); err != nil {
		checks["manifest"] = "unreachable: " + err.Error()
	} else {
		checks["manifest"] = "ok"
	}

	status := "ready"
	code := http.StatusOK
	if len(missing) > 0 || !strings.HasPrefix(checks["manifest"], "ok") {
		status = "not_ready"
		code = http.StatusServiceUnavailable
	}

	resp := s.baseResponse(status)
	resp.Checks = checks
	resp.MissingEnv = missing
	writeJSON(w, code, resp)
}

func (s *server) manifest(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.manifestURL, nil)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	res, err := s.httpClient.Do(req)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
		return
	}
	defer res.Body.Close()

	writeJSON(w, http.StatusOK, map[string]any{
		"manifest_url": s.manifestURL,
		"http_status":  res.StatusCode,
		"reachable":    res.StatusCode >= 200 && res.StatusCode < 300,
		"checked_at":   time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *server) baseResponse(status string) statusResponse {
	return statusResponse{
		Service:        "esomoire-genesis-node",
		Status:         status,
		NodeName:       os.Getenv("GENESIS_NODE_NAME"),
		NodeID:         os.Getenv("GENESIS_NODE_ID"),
		SiteID:         os.Getenv("GENESIS_SITE_ID"),
		ManifestURL:    s.manifestURL,
		UptimeSeconds:  int64(time.Since(s.startedAt).Seconds()),
		CheckedAt:      time.Now().UTC().Format(time.RFC3339),
		DeploymentMode: envOrDefault("DEPLOYMENT_ENVIRONMENT", "bootstrap"),
	}
}

func (s *server) checkManifest(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, s.manifestURL, nil)
	if err != nil {
		return err
	}

	res, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	if res.StatusCode >= 200 && res.StatusCode < 300 {
		return nil
	}

	if res.StatusCode == http.StatusMethodNotAllowed || res.StatusCode == http.StatusForbidden {
		return s.checkManifestWithGet(ctx)
	}

	return fmt.Errorf("unexpected status %d", res.StatusCode)
}

func (s *server) checkManifestWithGet(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.manifestURL, nil)
	if err != nil {
		return err
	}

	res, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("unexpected status %d", res.StatusCode)
	}

	return nil
}

func missingRequiredEnv(keys []string) []string {
	missing := make([]string, 0)
	for _, key := range keys {
		if strings.TrimSpace(os.Getenv(key)) == "" {
			missing = append(missing, key)
		}
	}
	sort.Strings(missing)
	return missing
}

func envOrDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func writeJSON(w http.ResponseWriter, code int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		if !errors.Is(err, http.ErrHandlerTimeout) {
			log.Printf("write json: %v", err)
		}
	}
}
