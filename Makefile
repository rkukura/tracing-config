SYSTEM_NS = tracing-system
APP_NS ?= traced-apps

.PHONY: otelcol-local
otelcol-local: jaeger
	oc apply -f otelcol-local.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

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
	oc apply -f otelcol-sidecar.yaml

.PHONY: clean
clean:
	oc delete project $(SYSTEM_NS)
	oc delete project $(APP_NS)
