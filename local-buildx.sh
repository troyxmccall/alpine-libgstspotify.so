#!/bin/bash

set -euo pipefail

ALPINE_VERSION="${ALPINE_VERSION:-3.20}"
GST_PLUGINS_RS_TAG="${GST_PLUGINS_RS_TAG:-0.14.3}"
PLATFORM="${PLATFORM:-$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')}"

echo "Building libgstspotify.so for Alpine ${ALPINE_VERSION} on platform ${PLATFORM}"

docker buildx build \
    --platform "${PLATFORM}" \
    --tag "libgstspotify-alpine${ALPINE_VERSION}" \
    --load \
    --target final \
    --build-arg "ALPINE_VERSION=${ALPINE_VERSION}" \
    --build-arg "GST_PLUGINS_RS_TAG=${GST_PLUGINS_RS_TAG}" \
    --progress=plain \
    .

echo "Build completed for Alpine ${ALPINE_VERSION}"
echo "Extracting libgstspotify.so..."

mkdir -p "./output/$(uname -m)/alpine${ALPINE_VERSION}"

docker create --name "libgstspotify-container-alpine${ALPINE_VERSION}" "libgstspotify-alpine${ALPINE_VERSION}"
docker cp "libgstspotify-container-alpine${ALPINE_VERSION}:/usr/lib/gstreamer-1.0/libgstspotify.so" "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify.so"
docker rm "libgstspotify-container-alpine${ALPINE_VERSION}"

sha256sum "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify.so" > "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify.so.sha256"
tar czf "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify-$(uname -m)-alpine${ALPINE_VERSION}.tar.gz" -C "./output/$(uname -m)/alpine${ALPINE_VERSION}" libgstspotify.so
sha256sum "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify-$(uname -m)-alpine${ALPINE_VERSION}.tar.gz" > "./output/$(uname -m)/alpine${ALPINE_VERSION}/libgstspotify-$(uname -m)-alpine${ALPINE_VERSION}.tar.gz.sha256"

echo "Artifacts saved to ./output/$(uname -m)/alpine${ALPINE_VERSION}/"
echo "Files created:"
ls -la "./output/$(uname -m)/alpine${ALPINE_VERSION}/"
