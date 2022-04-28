SYSTEM_NS = tracing-system
APP_NS ?= traced-apps

.PHONY: client-gateway
client-gateway: namespace
	oc create configmap -n tracing-system remote-ca --from-file=otlp-cert.crt 2>&1 | grep -v "already exists" || true
	oc apply -f client-gateway.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/gateway-collector-headless service.beta.openshift.io/serving-cert-secret-name=gateway-collector-headless-tls

.PHONY: server-gateway
server-gateway: jaeger htpasswd-secret otlp-cert-secret
	oc apply -f server-gateway.yaml
	sleep 5
	oc annotate -n $(SYSTEM_NS) --overwrite=true service/gateway-collector-headless service.beta.openshift.io/serving-cert-secret-name=gateway-collector-headless-tls
	oc delete route -n $(SYSTEM_NS) --ignore-not-found=true gateway-collector-headless
	oc create route passthrough -n $(SYSTEM_NS) --service=gateway-collector-headless --port=otlp-auth-grpc --hostname=otlp.apps.observability-d.p3ao.p1.openshiftapps.com
	oc annotate -n $(SYSTEM_NS) --overwrite=true  routes/gateway-collector-headless haproxy.router.openshift.io/balance=random
	oc annotate -n $(SYSTEM_NS) --overwrite=true  routes/gateway-collector-headless haproxy.router.openshift.io/disable_cookies=true

.PHONY: htpasswd-secret
htpasswd-secret:
	# Use kubernetes.io/basic-auth type?
	oc create secret generic -n tracing-system gateway-collector-basicauth --from-file=htpasswd 2>&1 | grep -v "already exists" || true

.PHONY: otlp-cert-secret
otlp-cert-secret:
	oc create secret tls -n tracing-system otlp-cert --cert=otlp-cert.crt --key=otlp-cert.key 2>&1 | grep -v "already exists" || true

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
	oc apply -n $(APP_NS) -f sidecar-agent.yaml

.PHONY: otlp-cert
otlp-cert:
	openssl req -newkey rsa:4096 -nodes -keyout otlp-cert.key -x509 -days 365 -out otlp-cert.crt -subj "/C=US/CN=otlp" -addext "subjectAltName = DNS:otlp.apps.observability-d.p3ao.p1.openshiftapps.com"

.PHONY: clean
clean:
	oc delete project --ignore-not-found=true $(SYSTEM_NS) 2>&1 | grep -v "forbidden" || true
	oc delete project --ignore-not-found=true $(APP_NS) 2>&1 | grep -v "forbidden" || true
