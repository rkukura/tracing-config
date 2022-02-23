
.PHONY: otelcol-local
otelcol-local: jaeger
	oc apply -f otelcol-local.yaml
	sleep 5
	oc annotate -n tracing-system --overwrite=true service/otelcol-collector-headless service.beta.openshift.io/serving-cert-secret-name=otelcol-collector-headless-tls

.PHONY: jaeger
jaeger: namespace
	oc apply -f jaeger.yaml

.PHONY: namespace
namespace:
	oc new-project tracing-system 2>&1 | grep -v "already exists" || true

.PHONY: clean
clean:
	oc delete project tracing-system
