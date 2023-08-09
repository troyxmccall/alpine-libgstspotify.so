# Alpine Linux libgstspotify.so

This repository provides a GitHub Actions workflow to build and export `libgstspotify.so` as a GStreamer plugin for Spotify for Alpine Linux. The workflow is configured to build for both amd64 and arm64 architectures using Docker Buildx and QEMU. Upon a successful build, the artifacts are bundled and uploaded as a release.

# Download Release:

You can grab a pre-built .so for your Alpine system here:

https://github.com/troyxmccall/alpine-libgstspotify.so/releases

# Usage in your build

for a Alpine-based mopidy image 

```dockerfile
# Stage 1: download pre-build libgstspotify
FROM alpine:latest AS libgstspotify-downloader
ARG TARGETPLATFORM
RUN apk add --no-cache curl tar && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64") \
            curl -L -o libgstspotify-amd64.tar.gz https://github.com/troyxmccall/alpine-libgstspotify.so/releases/download/v1.22.5/libgstspotify-amd64.tar.gz && \
            tar -xzf libgstspotify-amd64.tar.gz \
            ;; \
        "linux/arm64") \
            curl -L -o libgstspotify-arm64.tar.gz https://github.com/troyxmccall/alpine-libgstspotify.so/releases/download/v1.22.5/libgstspotify-arm64.tar.gz && \
            tar -xzf libgstspotify-arm64.tar.gz \
            ;; \
        *) \
            echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 \
            ;; \
    esac


##############

# Stage 2: Build
FROM alpine:latest AS builder

# Set environment variables
ENV PYTHON_VERSION=3.11

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

# Install Mopidy and its dependencies
RUN pip install --no-cache-dir \
        Mopidy \
        Mopidy-Local \
        pygobject \
        cffi==1.15.0

# Stage 3: Final - i only need pulseaudio bc that's how I stream audio from Docker - you might need to adjust these binaries for your final image depending on your stream preferences
FROM alpine:latest AS reactify

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

# Copy build artifacts from Stage 1: aka mopidy
COPY --from=builder /usr/local/ /usr/local/

# Copy libgstspotify.so from gst-builder stage
COPY --from=libgstspotify-downloader /libgstspotify.so /usr/lib/gstreamer-1.0/libgstspotify.so

# Copy entrypoint, configuration, and pulseaudio files
COPY docker/mopidy/alpine.entrypoint.sh /entrypoint.sh
COPY docker/mopidy/mopidy.example.conf /etc/mopidy/mopidy.conf
COPY docker/mopidy/pulse-client.conf /etc/pulse/client.conf

# Install custom mopidy-spotify plugin
RUN git clone https://github.com/mopidy/mopidy-spotify.git mopidy-spotify \
 && cd mopidy-spotify \
 && python3 setup.py install \
 && cd .. \
 && rm -rf mopidy-spotify

# Remove git
RUN apk del --no-cache git

# Add/install your custom mopidy plugin/front-end here

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
