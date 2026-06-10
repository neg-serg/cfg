FROM docker.io/library/ubuntu:24.04

RUN apt-get update && apt-get install -y curl xz-utils ca-certificates nss-plugin-pem

# Download Guix install script separately
RUN curl -sL -o /tmp/guix-install.sh https://guix.gnu.org/install.sh
RUN chmod +x /tmp/guix-install.sh
RUN /tmp/guix-install.sh --no-daemon

ENV GUIX_PROFILE=/root/.guix-profile
ENV PATH=/root/.guix-profile/bin:$PATH

RUN groupadd --system guixbuild && \
    for i in $(seq 1 10); do \
      useradd -g guixbuild -d /var/empty -s "$(command -v nologin)" -c "Build user $i" --system "guixbuilder$i"; \
    done

CMD ["/root/.guix-profile/bin/guix-daemon", "--build-users-group=guixbuild", "--disable-chroot"]
