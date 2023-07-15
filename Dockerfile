FROM rust:alpine AS gst-builder
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

# Print Info about current build Target
RUN printf "I'm building for TARGETPLATFORM=${TARGETPLATFORM}" \
    && printf ", TARGETARCH=${TARGETARCH}" \
    && printf ", TARGETVARIANT=${TARGETVARIANT} \n" \
    && printf "With uname -s : " && uname -s \
    && printf "and  uname -m : " && uname -m

# Switch to the root user while we do our changes
USER root

# Install all libraries and needs
RUN apk add --no-cache \
    alsa-lib-dev \
    bison \
    build-base \
    cairo-dev \
    cmake \
    fftw-dev \
    flex \
    git \
    gobject-introspection-dev \
    gst-plugins-base-dev \
    gstreamer-dev \
    liblo-dev \
    libsamplerate-dev \
    libsndfile-dev \
    pkgconfig \
    portaudio-dev

# Build and install CSound
RUN git clone --depth 1 https://github.com/csound/csound.git \
    && cd csound \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && cd ../.. \
    && rm -rf csound

WORKDIR /usr/src/gst-plugins-rs

# Clone source of gst-plugins-rs to workdir
ARG GST_PLUGINS_RS_TAG=gstreamer-1.22.4
RUN git clone -c advice.detachedHead=false \
    --single-branch --depth 1 \
    --branch ${GST_PLUGINS_RS_TAG} \
    https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs.git ./
# EXPERIMENTAL: For gstreamer-spotify set upgraded version number of dependency librespot to 0.4.2
RUN sed -i 's/librespot = { version = "0.4", default-features = false }/librespot = { version = "0.4.2", default-features = false }/g' audio/spotify/Cargo.toml

# Build GStreamer plugins written in Rust (optional with --no-default-features)
ENV DEST_DIR /target/gst-plugins-rs
ENV CARGO_PROFILE_RELEASE_DEBUG false
# try adding the RUSTFLAGS environment variable before the cargo build command to force the generation of dynamic librarie
ENV RUSTFLAGS "-C target-feature=-crt-static"
RUN export CSOUND_LIB_DIR="/usr/lib" \
    && export PLUGINS_DIR=$(pkg-config --variable=pluginsdir gstreamer-1.0) \
    && export SO_SUFFIX=so \
    && cargo build --release --no-default-features \
    --jobs $(nproc) \
    --package gst-plugin-spotify \
    && install -v -d ${DEST_DIR}/${PLUGINS_DIR} \
    && install -v -m 755 target/release/*.${SO_SUFFIX} ${DEST_DIR}/${PLUGINS_DIR}

RUN echo "build complete"

FROM alpine AS final

RUN echo "handling final layer and copying over the files we need"
COPY --from=gst-builder /target/gst-plugins-rs/usr/lib/gstreamer-1.0/libgstspotify.so /usr/lib/gstreamer-1.0/libgstspotify.so

RUN apk add --no-cache dumb-init

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "-c", "while true; do sleep 3600; done"]



