FROM alpine:3.19

LABEL org.opencontainers.image.source https://github.com/humanitec-tutorials/5min-idp

RUN apk add --no-cache \
  bash curl git jq bash-completion docker-cli && \
  mkdir -p /etc/bash_completion.d

# inject the target architecture (https://docs.docker.com/reference/dockerfile/#automatic-platform-args-in-the-global-scope)
ARG TARGETARCH

# install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$TARGETARCH/kubectl" > /tmp/kubectl && \
  install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl && \
  kubectl completion bash > /etc/bash_completion.d/kubectl && \
  rm /tmp/kubectl

# install helm (https://github.com/helm/helm/releases)
RUN mkdir /tmp/helm && \
  curl -fsSL https://get.helm.sh/helm-v3.14.4-linux-${TARGETARCH}.tar.gz > /tmp/helm/helm.tar.gz && \
  tar -zxvf /tmp/helm/helm.tar.gz -C /tmp/helm && \
  install -o root -g root -m 0755 /tmp/helm/linux-${TARGETARCH}/helm /usr/local/bin/helm && \
  helm completion bash > /etc/bash_completion.d/helm && \
  rm -rf /tmp/helm

# install kind https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
RUN curl -fsSL https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-${TARGETARCH} > /tmp/kind && \
  install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind && \
  rm /tmp/kind

# install terraform (https://github.com/hashicorp/terraform/releases)
RUN mkdir /tmp/terraform && \
  curl -fsSL https://releases.hashicorp.com/terraform/1.8.1/terraform_1.8.1_linux_${TARGETARCH}.zip > /tmp/terraform/terraform.zip && \
  unzip /tmp/terraform/terraform.zip -d /tmp/terraform && \
  install -o root -g root -m 0755 /tmp/terraform/terraform /usr/local/bin/terraform && \
  rm -rf /tmp/terraform

# install yq
RUN  curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH} > /tmp/yq && \
  install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq && \
  yq shell-completion bash > /etc/bash_completion.d/yq && \
  rm /tmp/yq

# install humctl (https://github.com/humanitec/cli/releases)
RUN mkdir /tmp/humctl && \
  curl -fsSL https://github.com/humanitec/cli/releases/download/v0.23.0/cli_0.23.0_linux_${TARGETARCH}.tar.gz > /tmp/humctl/humctl.tar.gz && \
  tar -zxvf /tmp/humctl/humctl.tar.gz -C /tmp/humctl && \
  install -o root -g root -m 0755 /tmp/humctl/humctl /usr/local/bin/humctl && \
  humctl completion bash > /etc/bash_completion.d/humctl && \
  rm -rf /tmp/humctl

ENV KUBECONFIG="/state/kube/config-internal.yaml"

COPY . /app

WORKDIR /app

ENTRYPOINT ["/bin/bash"]
