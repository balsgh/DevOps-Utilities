FROM alpine:3.20

# Define versions of tools to install
# YQ            - https://github.com/mikefarah/yq/releases/latest
# HELM          - https://github.com/helm/helm/releases/latest
# KUBECTL       - https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/ / https://cdn.dl.k8s.io/release/stable.txt
# KUBECTX       - https://github.com/ahmetb/kubectx/releases/latest
# Skupper CLI   - https://skupper.io/docs/latest/install/ / https://github.com/skupperproject/skupper/releases/latest
ENV \
    YQ_VERSION=v4.50.1 \
    HELM_VERSION=v4.1.0 \
    KUBECTL_VERSION=v1.35.0 \
    KUBECTX_VERSION=v0.9.5 \
    SKUPPER_CLI_VERSION=2.1.3 \
    # Set environment variable for PATH globally
    PATH=$HOME/.local/bin:$PATH

ARG IMAGE_VERSION=1.1.0 \
    USER_ID=1001 \
    USER_GROUP_ID=1001 \
    ARCH=linux_x86_64

LABEL maintainer="https://github.com/balsgh" \
      org.opencontainers.image.title="scp-iac-tools-container" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.description="Alpine image with yq, helm, kubectl, and more."

WORKDIR /opt

RUN \
        ### Install container dependencies ###
        apk add --no-cache \
            bash \
            coreutils \
            curl \
            jq \
            sed \
            util-linux \
    && \
        ### Install image build dependencies ###
        apk add --no-cache --virtual .build-deps \
            ca-certificates \
            git \
            gnupg \
            openssh \
            tar \
            wget \
    && \
        ### yq ###
        curl --fail --silent --show-error --location \
            https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 --output /usr/bin/yq && \
        curl --fail --silent --show-error --location \
            https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums-bsd --output /tmp/checksums-bsd && \
        echo "$(grep 'SHA256 (yq_linux_amd64)' /tmp/checksums-bsd | cut -d '=' -f2 | xargs)  /usr/bin/yq" | sha256sum -c - && \
        chmod -v +x /usr/bin/yq && \
        rm -fv /tmp/checksums-bsd && \
        yq --version \
    && \
        ### helm ###
        curl --fail --silent --show-error --location --remote-name \
            https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
        curl --fail --silent --show-error --location --remote-name \
            https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum && \
        sha256sum -c helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum && \
        tar -xzvf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
        mv -v linux-amd64/helm /usr/local/bin/helm && \
        chmod -v +x /usr/local/bin/helm && \
        rm -frv linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz* helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum && \
        helm version \
    && \
        ### kubectl ###
        curl --fail --silent --show-error --location --remote-name \
            https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
        curl --fail --silent --show-error --location --remote-name \
            https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256 && \
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - && \
        chmod -v +x kubectl && \
        mv -v kubectl /usr/local/bin/ && \
        rm -fv kubectl.sha256 && \
        kubectl version --client \
    && \
        ### kubectx & kubens ###
        if [[ "$(uname -m)" = "x86_64" ]]; then \
            export ARCH=linux_x86_64; \
        elif [[ "$(uname -m)" = "aarch64" ]]; then \
            export ARCH=linux_arm64; \
        else \
            export ARCH=linux_x86_64; \
        fi && \
        echo "ARCH=[${ARCH}]" && \
        curl --fail --silent --show-error --location --remote-name \
            https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/checksums.txt && \
        \
        curl --fail --silent --show-error --location --remote-name \
            https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_${ARCH}.tar.gz && \
        grep "kubectx_${KUBECTX_VERSION}_${ARCH}.tar.gz" checksums.txt | sha256sum -c - && \
        tar -xzf kubectx_${KUBECTX_VERSION}_${ARCH}.tar.gz -C /usr/local/bin && \
        chmod -v +x /usr/local/bin/kubectx && \
        \
        curl --fail --silent --show-error --location --remote-name \
            https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_${ARCH}.tar.gz && \
        grep "kubens_${KUBECTX_VERSION}_${ARCH}.tar.gz" checksums.txt | sha256sum -c - && \
        tar -xzf kubens_${KUBECTX_VERSION}_${ARCH}.tar.gz -C /usr/local/bin && \
        chmod -v +x /usr/local/bin/kubens && \
        \
        rm -fv \
            kubectx_${KUBECTX_VERSION}_${ARCH}.tar.gz \
            kubens_${KUBECTX_VERSION}_${ARCH}.tar.gz \
            checksums.txt && \
        kubectx --version && kubens --version \
    && \
        ### 1Password CLI ###
        echo https://downloads.1password.com/linux/alpinelinux/stable/ >> /etc/apk/repositories && \
        wget https://downloads.1password.com/linux/keys/alpinelinux/support@1password.com-61ddfc31.rsa.pub -P /etc/apk/keys && \
        apk add --no-cache 1password-cli && \
        op --version \
    && \
        ### Skupper CLI ###
        curl --fail --silent --show-error --location https://skupper.io/v2/install.sh | VERSION=${SKUPPER_CLI_VERSION} sh && \
        rm -rf /var/lib/apt/lists/* && \
        skupper version
    && \
        ### Cleanup ###
        apk del .build-deps \
        && \
        rm -fr /tmp/* /var/cache/apk/*

# Set up non-root user and workspace
RUN addgroup \
        -S usergroup \
        --gid ${USER_GROUP_ID} \
    && \
    adduser \
        -S user \
        -G usergroup \
        --uid ${USER_ID} \
        --home /home/user \
    && \
    mkdir -pv /opt/workspace \
    && \
    mkdir -pv /home/user/.config/op \
    && \
    chown -v -R user:usergroup /opt /home/user \
    && \
    chmod -v -R 755 /opt/ /home/user \
    && \
    chmod -v -R 700 /opt/ /home/user/.config/op

# Switch to non-root user
USER user

# Set environment variables for non-root user
ENV \
    HOME="/home/user" \
    TMPDIR="/tmp" \
    PATH="/usr/local/bin:${PATH}"

WORKDIR /opt/workspace

# Set default command
CMD ["bash"]
