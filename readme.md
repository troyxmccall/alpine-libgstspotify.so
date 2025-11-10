# Alpine Linux libgstspotify.so

This repository provides a GitHub Actions workflow to build and export `libgstspotify.so` as a GStreamer plugin for Spotify for Alpine Linux. The workflow is configured to build for both amd64 and arm64 architectures using Docker Buildx and QEMU. Upon a successful build, the artifacts are bundled and uploaded as a release.

# Download Release:

You can grab a pre-built .so for your Alpine system here:

https://github.com/troyxmccall/alpine-libgstspotify.so/releases

# Usage in your build

for a Alpine-based mopidy image 

```dockerfile
# Stage 1: download pre-build libgstspotify
FROM alpine:3.20 AS libgstspotify-downloader
ARG TARGETPLATFORM
RUN apk add --no-cache curl tar && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            curl -L -o libgstspotify-amd64.tar.gz https://github.com/troyxmccall/alpine-libgstspotify.so/releases/download/v1.22.12/libgstspotify-amd64.tar.gz && \
            tar -xzf libgstspotify-amd64.tar.gz \
            ;; \
        "linux/arm64") \
            curl -L -o libgstspotify-arm64.tar.gz https://github.com/troyxmccall/alpine-libgstspotify.so/releases/download/v1.22.12/libgstspotify-arm64.tar.gz && \
            tar -xzf libgstspotify-arm64.tar.gz \
            ;; \
        *) \
            echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 \
            ;; \
    esac



##############

# Stage 2: Build
FROM alpine:3.18 AS builder
# Set environment variables
ENV PYTHON_VERSION=3.12
ENV VIRTUAL_ENV=/opt/venv

# Install necessary packages
RUN apk add --no-cache \
        build-base \
        cairo-dev \
        curl \
        git \
        gobject-introspection-dev \
        gst-plugins-bad \
        gst-plugins-base \
        gst-plugins-good \
        gstreamer \
        pulseaudio \
        py3-cffi \
        py3-gobject3 \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        python3-dev

# Create virtual environment
RUN python3 -m venv $VIRTUAL_ENV

# Activate virtual environment
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# update pip
RUN /opt/venv/bin/python3 -m pip install --no-cache-dir pip

# Install Mopidy and its dependencies
RUN /opt/venv/bin/python3 -m pip install --no-cache-dir \
        Mopidy \
        Mopidy-Local \
        pygobject \
        cffi==1.15.0

# Stage 3: Final - i only need pulseaudio bc that's how I stream audio from Docker - you might need to adjust these binaries for your final image depending on your stream preferences
FROM alpine:3.18 AS final

# Install necessary runtime packages
RUN apk add --no-cache \
        bash \
        curl \
        dumb-init \
        git \
        gst-plugins-base \
        gst-plugins-good \
        gstreamer \
        pulseaudio \
        py3-cffi \
        py3-gobject3 \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        sudo \
        && addgroup -S mopidy \
        && adduser -S -G mopidy mopidy

# Copy build artifacts from Stage 2: aka mopidy
COPY --from=builder /usr/local/ /usr/local/

# Copy libgstspotify.so from gst-builder stage 1
COPY --from=libgstspotify-downloader /libgstspotify.so /usr/lib/gstreamer-1.0/libgstspotify.so

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Set environment variable to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy entrypoint, configuration, and pulseaudio files
COPY docker/mopidy/alpine.entrypoint.sh /entrypoint.sh
COPY docker/mopidy/mopidy.example.conf /etc/mopidy/mopidy.conf
COPY docker/mopidy/pulse-client.conf /etc/pulse/client.conf

# Install custom mopidy-spotify plugin
RUN git clone https://github.com/troyxmccall/mopidy-spotify.git mopidy-spotify \
 && cd mopidy-spotify \
 && /opt/venv/bin/python3 setup.py install \
 && cd .. \
 && rm -rf mopidy-spotify

# Remove git
RUN apk del --no-cache git

# @TODO - Add/install your custom mopidy plugin/front-end here

# persistant mnt point for our logs (Write)
RUN mkdir -p /home/mopidy/logs \
 && chown -R mopidy:mopidy /home/mopidy/logs

# alpine specific cache/config
RUN mkdir -p /home/mopidy/.cache/mopidy \
             /home/mopidy/.cache/gstreamer-1.0 \
             /home/mopidy/.config/mopidy \
             /home/mopidy/.local/share/mopidy/reactify \
             /home/mopidy/.local/share/mopidy/spotify \
             /home/mopidy/.local/share/mopidy/http \
 && chown -R mopidy:mopidy /home/mopidy/.cache/mopidy \
                           /home/mopidy/.cache/gstreamer-1.0 \
                           /home/mopidy/.config/mopidy \
                           /home/mopidy/.local/share/mopidy/reactify \
                           /home/mopidy/.local/share/mopidy/spotify \
                           /home/mopidy/.local/share/mopidy/http


USER mopidy

WORKDIR /home/mopidy

EXPOSE 6600 6680

```

# CI details:

## Workflow Configuration

The GitHub Actions workflow is triggered whenever a push is made to the `main` branch. The workflow is divided into three main jobs: `build_amd64`, `build_arm64`, and `create_release`.

- `build_amd64`: Builds the `libgstspotify.so` file for the amd64 architecture.
- `build_arm64`: Builds the `libgstspotify.so` file for the arm64 architecture.
- `create_release`: After both build jobs have completed successfully, this job creates a new GitHub release and uploads the generated artifacts.

## Dockerfile

The Dockerfile in this repository is used by the GitHub Actions workflow to build the `libgstspotify.so` file. It's a multi-stage build with two stages: `gst-builder` and `final`.

- `gst-builder`: This stage builds the GStreamer plugins written in Rust and installs the necessary dependencies.
- `final`: This stage copies the `libgstspotify.so` file from the `gst-builder` stage to the final image.

## Local Replication of the Github CI:

1. Clone this repository.
2. Make sure you have Docker installed on your system.
3. Run the following command to build the Docker image:

   ```
   docker build -t libgstspotify .
   ```

4. Once the build is complete, you can run the Docker container with the following command:

   ```
   docker run -it --rm libgstspotify
   ```

5. The `libgstspotify.so` file can be found in the `/usr/lib/gstreamer-1.0/` directory inside the container.

## License

This project is released under the [MIT License](LICENSE).
