FROM --platform=linux/amd64 alpine:3.21 AS builder

ARG VERSION_OPENCORE="1.0.3"
ARG REPO_OPENCORE="https://github.com/acidanthera/OpenCorePkg"
ADD OpenCore-1.0.3-RELEASE.zip /tmp/opencore.zip

RUN apk --update --no-cache add unzip && \
    unzip /tmp/opencore.zip -d /tmp/oc && \
    cp /tmp/oc/Utilities/macserial/macserial.linux /macserial && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

FROM scratch AS runner
COPY --from=qemux/qemu:6.21 / /

ARG VERSION_ARG="0.0"
ARG VERSION_KVM_OPENCORE="v21"
ARG VERSION_OSX_KVM="326053dd61f49375d5dfb28ee715d38b04b5cd8e"
ARG REPO_OSX_KVM="https://raw.githubusercontent.com/kholia/OSX-KVM"
ARG REPO_KVM_OPENCORE="https://github.com/thenickdude/KVM-Opencore"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN rm -f /etc/apt/sources.list.d/* && \
    echo "deb http://mirrors.aliyun.com/debian/ trixie main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian/ trixie-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/debian-security trixie-security main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian/ trixie-backports main contrib non-free" >> /etc/apt/sources.list


RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
    xxd \
    fdisk \
    mtools \
    curl \
    python3 \
    git &&\
    apt-get clean && \
    echo "$VERSION_ARG" > /run/version && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --chmod=755 ./src /run/
COPY --chmod=755 ./assets /assets/
COPY --chmod=755 --from=builder /macserial /usr/local/bin/

ADD --chmod=644 \
    OVMF_CODE.fd \
    OVMF_VARS.fd \
    OVMF_VARS-1024x768.fd \
    OVMF_VARS-1920x1080.fd /usr/share/OVMF/

ADD OpenCore-v21.iso.gz /opencore.iso.gz

VOLUME /storage
EXPOSE 8006 5900

ENV VERSION="13"
ENV RAM_SIZE="4G"
ENV CPU_CORES="2"
ENV DISK_SIZE="64G"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
