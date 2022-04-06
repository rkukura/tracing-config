SYSTEM_NS = tracing-system
APP_NS ?= traced-apps

.PHONY: otelcol-remote
otelcol-remote: namespace
	oc create configmap -n tracing-system remote-ca --from-file=otlp-cert.crt 2>&1 | grep -v "already exists" || true
	oc apply -f otelcol-remote.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: otelcol-local
otelcol-local: jaeger
	oc create secret generic -n tracing-system otlp-htpasswd --from-file=otlp-htpasswd
	oc apply -f otelcol-local.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: otlp-route
otlp-route: otelcol-local
	oc create route reencrypt -n tracing-system --service=otelcol-collector-headless --port=otlp-auth-grpc --cert=otlp-cert.crt --key=otlp-cert.key --ca-cert=otlp-cert.crt --hostname=otlp.apps.observability-d.p3ao.p1.openshiftapps.com

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
	oc delete project $(SYSTEM_NS)
	oc delete project $(APP_NS)
