
.PHONY: jaeger
jaeger: namespace
	oc apply -f jaeger.yaml

.PHONY: namespace
namespace:
	oc new-project tracing-system 2>&1 | grep -v "already exists" || true

.PHONY: clean
clean:
	oc delete project tracing-system
