SYSTEM_NS = tracing-system
APP_NS ?= traced-apps

.PHONY: otelcol-remote
otelcol-remote: namespace
	oc create configmap -n tracing-system remote-ca --from-file=otlp-cert.crt 2>&1 | grep -v "already exists" || true
	oc apply -f otelcol-remote.yaml
	# sleep 5
	# oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: otelcol-local-reencrypt
otelcol-local-reencrypt: jaeger otlp-htpasswd-secret
	oc apply -f otelcol-local-reencrypt.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: otelcol-local-passthrough
otelcol-local-passthrough: jaeger otlp-htpasswd-secret otlp-cert-secret
	oc apply -f otelcol-local-passthrough.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: otlp-htpasswd-secret
otlp-htpasswd-secret:
	# Use kubernetes.io/basic-auth type?
	oc create secret generic -n tracing-system otlp-htpasswd --from-file=otlp-htpasswd 2>&1 | grep -v "already exists" || true

.PHONY: otlp-cert-secret
otlp-cert-secret:
	oc create secret tls -n tracing-system otlp-cert --cert=otlp-cert.crt --key=otlp-cert.key 2>&1 | grep -v "already exists" || true

.PHONY: otlp-route-reencrypt
otlp-route-reencrypt: otelcol-local-reencrypt
	oc delete route -n $(SYSTEM_NS) --ignore-not-found=true otelcol-collector-headless
	oc create route reencrypt -n $(SYSTEM_NS) --service=otelcol-collector-headless --port=otlp-auth-grpc --cert=otlp-cert.crt --key=otlp-cert.key --ca-cert=otlp-cert.crt --hostname=otlp.apps.observability-d.p3ao.p1.openshiftapps.com

.PHONY: otlp-route-passthrough
otlp-route-passthrough: otelcol-local-passthrough
	oc delete route -n $(SYSTEM_NS) --ignore-not-found=true otelcol-collector-headless
	oc create route passthrough -n $(SYSTEM_NS) --service=otelcol-collector-headless --port=otlp-auth-grpc --hostname=otlp.apps.observability-d.p3ao.p1.openshiftapps.com
	oc annotate -n $(SYSTEM_NS) --overwrite=true  routes/otelcol-collector-headless haproxy.router.openshift.io/balance=random
	oc annotate -n $(SYSTEM_NS) --overwrite=true  routes/otelcol-collector-headless haproxy.router.openshift.io/disable_cookies=true

.PHONY: jaeger
jaeger: namespace
	oc apply -f jaeger.yaml

.PHONY: namespace
namespace:
	oc new-project $(SYSTEM_NS) 2>&1 | grep -v "already exists" || true

.PHONY: start-vertx-create-span
start-vertx-create-span: app-namespace
	oc apply -n $(APP_NS) -f vertx-create-span.yaml

.PHONY: stop-vertx-create-span
stop-vertx-create-span:
	oc delete -n $(APP_NS) -f vertx-create-span.yaml

.PHONY: app-namespace
app-namespace:
	oc new-project $(APP_NS) 2>&1 | grep -v "already exists" || true
	oc apply -n $(APP_NS) -f otelcol-sidecar.yaml

.PHONY: otlp-cert
otlp-cert:
	openssl req -newkey rsa:4096 -nodes -keyout otlp-cert.key -x509 -days 365 -out otlp-cert.crt -subj "/C=US/CN=otlp" -addext "subjectAltName = DNS:otlp.apps.observability-d.p3ao.p1.openshiftapps.com"

.PHONY: clean
clean:
	oc delete project --ignore-not-found=true $(SYSTEM_NS) 2>&1 | grep -v "forbidden" || true
	oc delete project --ignore-not-found=true $(APP_NS) 2>&1 | grep -v "forbidden" || true
