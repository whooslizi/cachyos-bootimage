FROM scratch AS ctx

FROM docker.io/cachyos/cachyos-v3:latest AS base

FROM base AS builder

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        git \
        make \
        rust \
        go-md2man \
        ostree \
        glibc \
        pkgconf

WORKDIR /src

RUN git clone https://github.com/bootc-dev/bootc.git .

RUN make bin install-all DESTDIR=/output

FROM base

COPY --from=builder /output /

LABEL containers.bootc=1
LABEL org.opencontainers.image.title="cachyos-bootimage"
LABEL org.opencontainers.image.description="Immutable CachyOS bootc image"
LABEL org.opencontainers.image.source="https://github.com/whooslizi/cachyos-bootimage"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base \
        bootc \
        linux-cachyos \
        linux-cachyos-headers \
        linux-firmware \
        dracut \
        ostree \
        docker \
        docker-compose-plugin \
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
        jq \
        rsync \
        htop \
        btop \
        smartmontools \
        btrfs-progs \
        e2fsprogs \
        xfsprogs \
        dosfstools \
        skopeo \
        ca-certificates && \
    pacman -Scc --noconfirm

RUN systemctl enable \
    docker.service \
    sshd.service \
    NetworkManager.service

RUN mkdir -p /usr/lib/dracut/dracut.conf.d

RUN printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc "\n' \
    > /usr/lib/dracut/dracut.conf.d/bootc.conf

RUN depmod -a $(basename $(ls -d /usr/lib/modules/* | tail -1))

RUN dracut --force \
    /usr/lib/modules/$(basename $(ls -d /usr/lib/modules/* | tail -1))/initramfs.img

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
