ARG flux_sched_version=jammy
FROM fluxrm/flux-sched:${flux_sched_version} AS builder
ARG replicas=3
ENV workers=${replicas}
USER root

RUN apt-get update
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install \
    autotools-dev \
    autoconf \
    automake \
    cmake \
    gcc-12 \
    g++-12 \
    git \
    python3 \
    python3-pip \
    openssh-server \
    openssh-client \
    libdb-dev \
    apt-utils \
    dnsutils \
    iputils-ping \
    software-properties-common

# Import the local Flux forks supplied through the named build contexts in
# docker-compose.yml. Docker copies the source trees into the image; it does
# not modify the repositories on the host.
COPY --from=custom_flux_core / /src/flux-core/

# Install the custom Flux Core over the base image's installation. Using the
# same /usr prefix avoids mixing an original /usr installation with a custom
# /usr/local installation.
RUN cd /src/flux-core && \
    ./autogen.sh && \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig

COPY --from=custom_flux_sched / /src/flux-sched/

# Build Fluxion only after the custom Core is installed, ensuring that the
# custom scheduler is compiled against the custom Core in this image.
RUN cmake \
        -S /src/flux-sched \
        -B /tmp/flux-sched-build \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DFLUX_SCHED_VER=0.55.0 \
        -DCMAKE_C_COMPILER=/usr/bin/gcc-12 \
        -DCMAKE_CXX_COMPILER=/usr/bin/g++-12 && \
    cmake --build /tmp/flux-sched-build --parallel && \
    cmake --install /tmp/flux-sched-build && \
    ldconfig

# These are the STATE_DIR, system, and resources directories
ENV STATE_DIR=/var/lib/flux
RUN mkdir -p ${STATE_DIR} /etc/flux/system /etc/flux/system/cron.d /etc/flux/config /etc/flux/imp/conf.d /run/flux && \
    mkdir -p /mnt/curve && \
    flux keygen /mnt/curve/curve.cert && \
    chown -R fluxuser:fluxuser /run/flux ${STATE_DIR} /mnt/curve/curve.cert /etc/flux ${workdir}

COPY ./flux/imp.toml /etc/flux/imp/conf.d/imp.toml

WORKDIR /home/fluxuser
RUN pip3 install --upgrade pip && \
    pip3 install pika --upgrade && \
    chown -R fluxuser:fluxuser /home/fluxuser && \
    chown -R fluxuser:fluxuser /run/flux

USER fluxuser
WORKDIR /home/fluxuser/
COPY ./scripts/entrypoint.sh ./scripts/job.py ./
COPY --chown=fluxuser:fluxuser \
    ./cosched_config/config.toml \
    ./cosched_config/simple-socket.jgf \
    ./
ENTRYPOINT /bin/bash /home/fluxuser/entrypoint.sh
