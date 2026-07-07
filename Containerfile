FROM scratch AS ctx

ARG BASE_IMAGE=docker.io/cachyos/cachyos-v3:latest
FROM ${BASE_IMAGE} AS base

FROM base AS builder

RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm \
        git \
        make \
        rust \
        go-md2man \
        ostree \
        glibc \
        pkgconf

WORKDIR /src

ARG BOOTC_VERSION=v1.16.3

RUN git clone \
    --depth=1 \
    --branch ${BOOTC_VERSION} \
    https://github.com/bootc-dev/bootc.git .

RUN make bin install-all DESTDIR=/output

FROM base

COPY --from=builder /output /

LABEL containers.bootc=1
LABEL org.opencontainers.image.title="cachyos-bootimage"
LABEL org.opencontainers.image.description="Immutable CachyOS bootc image"
LABEL org.opencontainers.image.source="https://github.com/whooslizi/cachyos-bootimage"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="whooslizi"
LABEL org.opencontainers.image.documentation="https://github.com/whooslizi/cachyos-bootimage"

RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm \
        base \
        linux-cachyos \
        linux-firmware \
        dracut \
        ostree \
        docker \
        docker-compose \
        openssh \
        networkmanager \
        tailscale \
        fastfetch \
        sudo \
        git \
        curl \
        wget \
        nano \
        vim \
        btrfs-progs \
        e2fsprogs \
        xfsprogs \
        dosfstools \
        ca-certificates && \
    pacman -Scc --noconfirm

RUN mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /usr/lib/systemd/system/docker.service \
      /etc/systemd/system/multi-user.target.wants/docker.service && \
    ln -sf /usr/lib/systemd/system/sshd.service \
      /etc/systemd/system/multi-user.target.wants/sshd.service && \
    ln -sf /usr/lib/systemd/system/NetworkManager.service \
      /etc/systemd/system/multi-user.target.wants/NetworkManager.service

RUN mkdir -p /usr/lib/dracut/dracut.conf.d && \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" \
      > /usr/lib/dracut/dracut.conf.d/30-systemd.conf && \
    printf "reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=\" bootc \"\n" \
      > /usr/lib/dracut/dracut.conf.d/30-bootc.conf

RUN KVER=$(ls -1 /usr/lib/modules | head -n1) && \
    depmod -a "${KVER}" && \
    dracut --force /usr/lib/modules/"${KVER}"/initramfs.img --kver "${KVER}"

RUN rm -rf \
    /boot \
    /root \
    /home \
    /srv \
    /mnt \
    /opt

RUN mkdir -p \
    /boot \
    /sysroot \
    /usr/lib/ostree \
    /var

RUN ln -sT sysroot/ostree /ostree && \
    ln -sT var/home /home && \
    ln -sT var/srv /srv && \
    ln -sT var/opt /opt && \
    ln -sT var/mnt /mnt && \
    ln -sT var/roothome /root

RUN printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' \
    > /usr/lib/ostree/prepare-root.conf

RUN bootc container lint
