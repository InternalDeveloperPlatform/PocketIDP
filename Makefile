IMG_TAG ?= latest
IMG ?= ghcr.io/humanitec-tutorials/5min-idp:$(IMG_TAG)
PLATFORM ?= linux/amd64,linux/arm64

# Build the 5min-idp image
build:
	docker buildx build --platform $(PLATFORM) -t $(IMG) .
	# Ideally we could remove the next step, but docker on GHA doesn't support
	# loading multi-platform builds yet
	docker buildx build -t $(IMG) --load .

# Check the 5min-idp image
check-image:
	docker run --rm -v $(PWD):/app $(IMG) ./image/check.sh

# Push the 5min-idp image
push:
	docker buildx build --platform $(PLATFORM) -t $(IMG) --push .

# Initialize tflint
lint-init:
	tflint --init

# Lint terraform directory
lint: lint-init
	tflint --config ../.tflint.hcl --chdir=./setup/terraform

# Test the 5min-idp
test: build check-image
	docker run --rm -i -h 5min-idp --name 5min-idp \
	-e HUMANITEC_ORG \
	-v hum-5min-idp:/state \
	-v $(HOME)/.humctl:/root/.humctl \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network bridge \
	$(IMG) ./image/test.sh

# Run the locally built image
run-local: build
	docker run --rm -it -h 5min-idp --name 5min-idp \
	-e HUMANITEC_ORG \
	-e HUMANITEC_SERVICE_USER \
	-e TLS_CA_CERT \
	-e TLS_CERT_STRING \
	-e TLS_KEY_STRING \
	-v hum-5min-idp:/state \
	-v $(HOME)/.humctl:/root/.humctl \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network bridge \
	$(IMG)
# Run the locally built image and don't delete the state
run-local-persistent: build
	docker run -it -h 5min-idp --name 5min-idp \
	-e HUMANITEC_ORG \
	-e HUMANITEC_SERVICE_USER \
	-e TLS_CA_CERT \
	-e TLS_CERT_STRING \
	-e TLS_KEY_STRING \
	-v hum-5min-idp:/state \
	-v $(HOME)/.humctl:/root/.humctl \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network bridge \
	$(IMG)

# Re-do the Humanitec token in a running 5min-IDP
.PHONY: renew-token
renew-token:
	humctl login -v9
	docker cp ~/.humctl 5min-idp:/root/.humctl
