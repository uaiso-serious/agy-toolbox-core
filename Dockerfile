FROM ghcr.io/uaiso-serious/agy-runtime:latest

USER root
ARG DOCKER_VERSION=29.9.1
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash bash-completion gnupg \
      bsdextrautils dos2unix findutils grep sed gawk diffutils patch file less tree \
      tar gzip bzip2 xz-utils zstd zip unzip \
      procps bc gettext-base \
      locales tzdata tini \
      xxd nano vim \
      iproute2 uidmap iptables fuse-overlayfs slirp4netns \
 && (update-alternatives --set iptables /usr/sbin/iptables-legacy || true) \
 && (update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true) \
 && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=1 \
          docker/dockerd docker/containerd docker/containerd-shim-runc-v2 docker/runc docker/ctr \
 && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-rootless-extras-${DOCKER_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=1 \
 && mkdir -p /home/agent/.local/share/docker \
 && chown -R agent:agent /home/agent/.local/share/docker \
 && rm -rf /var/lib/apt/lists/*

COPY rootfs/usr/ /usr/
RUN chmod +x /usr/local/bin/*.sh

VOLUME /home/agent/.local/share/docker
USER agent

COPY --chown=agent:agent rootfs/home/agent/ /home/agent/

ENV MISE_YES=1 \
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=node,python
RUN mise install && mise reshim

