# Makefile
.PHONY: help generate-config test build deploy-test deploy-dev deploy-stage deploy-prod clean

# Variables
VARIABLES_FILE := config/variables.yaml
KUBE_CONTEXT := $(shell kubectl config current-context)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-tools: ## Check required tools
	@command -v yq >/dev/null 2>&1 || { echo "yq is required but not installed. Install: brew install yq"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
	@command -v kustomize >/dev/null 2>&1 || { echo "kustomize is required but not installed."; exit 1; }
	@echo "✓ All required tools are installed"

generate-config: check-tools ## Generate ConfigMaps from variables
	@echo "Generating ConfigMaps..."
	@bash scripts/generate-configmaps.sh
	@echo "✓ ConfigMaps generated"

test: check-tools ## Run all tests
	@echo "Running tests..."
	@bash scripts/test-deployment.sh

validate: generate-config ## Validate Kubernetes manifests
	@echo "Validating manifests..."
	@for env in test dev stage prod; do \
		echo "Validating $$env..."; \
		kubectl --dry-run=client -f kubernetes/generated/configmap-$$env.yaml apply; \
	done
	@echo "✓ All manifests valid"

build: ## Build Docker image locally
	@export IMAGE_TAG=$$(git rev-parse --short HEAD); \
	export REGISTRY=$$(yq eval '.registry.url' $(VARIABLES_FILE)); \
	export PROJECT=$$(yq eval '.project.name' $(VARIABLES_FILE)); \
	docker build -t $$REGISTRY/$$PROJECT:$$IMAGE_TAG -f docker/Dockerfile .

init-namespaces: check-tools ## Initialize all Kubernetes namespaces
	@for env in test dev stage prod; do \
		NS=$$(yq eval ".namespaces.$$env" $(VARIABLES_FILE)); \
		echo "Creating namespace: $$NS"; \
		kubectl create namespace $$NS --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl label namespace $$NS environment=$$env managed-by=makefile --overwrite; \
	done
	@echo "✓ All namespaces initialized"

deploy-test: generate-config ## Deploy to test environment
	@echo "Deploying to test..."
	@NS=$$(yq eval '.namespaces.test' $(VARIABLES_FILE)); \
	kubectl apply -f kubernetes/generated/configmap-test.yaml -n $$NS; \
	cd kubernetes/overlays/test && kustomize build . | kubectl apply -n $$NS -f -

deploy-dev: generate-config ## Deploy to dev environment
	@echo "Deploying to dev..."
	@NS=$$(yq eval '.namespaces.dev' $(VARIABLES_FILE)); \
	kubectl apply -f kubernetes/generated/configmap-dev.yaml -n $$NS; \
	cd kubernetes/overlays/dev && kustomize build . | kubectl apply -n $$NS -f -

deploy-stage: generate-config ## Deploy to stage environment
	@echo "Deploying to stage..."
	@NS=$$(yq eval '.namespaces.stage' $(VARIABLES_FILE)); \
	kubectl apply -f kubernetes/generated/configmap-stage.yaml -n $$NS; \
	cd kubernetes/overlays/stage && kustomize build . | kubectl apply -n $$NS -f -

deploy-prod: generate-config ## Deploy to production environment
	@echo "⚠️  Deploying to PRODUCTION..."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		NS=$$(yq eval '.namespaces.prod' $(VARIABLES_FILE)); \
		kubectl apply -f kubernetes/generated/configmap-prod.yaml -n $$NS; \
		cd kubernetes/overlays/prod && kustomize build . | kubectl apply -n $$NS -f -; \
	fi

status: ## Show deployment status for all environments
	@for env in test dev stage prod; do \
		NS=$$(yq eval ".namespaces.$$env" $(VARIABLES_FILE)); \
		echo "=== $$env ($$NS) ==="; \
		kubectl get pods -n $$NS 2>/dev/null || echo "Namespace not found"; \
		echo ""; \
	done

logs: ## Tail logs from production
	@NS=$$(yq eval '.namespaces.prod' $(VARIABLES_FILE)); \
	kubectl logs -f -n $$NS -l app=odoo --tail=100

clean: ## Clean generated files
	@echo "Cleaning generated files..."
	@rm -rf kubernetes/generated/
	@echo "✓ Cleaned"

backup-db: ## Backup production database
	@NS=$$(yq eval '.namespaces.prod' $(VARIABLES_FILE)); \
	DB=$$(yq eval '.database.names.prod' $(VARIABLES_FILE)); \
	TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	POD=$$(kubectl get pods -n $$NS -l app=postgres-patroni,role=master -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -n $$NS $$POD -- pg_dump -U postgres $$DB | gzip > backup-$$TIMESTAMP.sql.gz; \
	echo "✓ Backup created: backup-$$TIMESTAMP.sql.gz"

generate-ingress: check-tools ## Generate Ingress manifests
	@echo "Generating Ingress manifests..."
	@bash scripts/generate-ingress.sh
	@echo "✓ Ingress manifests generated"

test-ingress: check-tools ## Test Ingress configuration
	@bash scripts/test-ingress.sh

check-dns: ## Check DNS for all domains
	@for env in test dev stage prod; do \
		DOMAIN=$$(yq eval ".domains.$$env" $(VARIABLES_FILE)); \
		echo "Checking DNS for $$DOMAIN ($$env)..."; \
		dig +short $$DOMAIN || echo "⚠ DNS not resolved"; \
	done

check-ssl: ## Check SSL certificates for all domains
	@for env in test dev stage prod; do \
		DOMAIN=$$(yq eval ".domains.$$env" $(VARIABLES_FILE)); \
		echo "Checking SSL for $$DOMAIN ($$env)..."; \
		echo | timeout 5 openssl s_client -connect $$DOMAIN:443 -servername $$DOMAIN 2>/dev/null | \
		openssl x509 -noout -dates 2>/dev/null || echo "⚠ SSL not available"; \
	done

setup-basic-auth: ## Setup basic auth for stage environment
	@echo "Setting up basic auth for stage..."
	@read -p "Username: " USERNAME; \
	read -sp "Password: " PASSWORD; \
	echo ""; \
	htpasswd -c -b /tmp/auth $$USERNAME $$PASSWORD; \
	NS=$$(yq eval '.namespaces.stage' $(VARIABLES_FILE)); \
	kubectl create secret generic basic-auth --from-file=/tmp/auth -n $$NS --dry-run=client -o yaml | kubectl apply -f -; \
	rm /tmp/auth; \
	echo "✓ Basic auth configured for stage"