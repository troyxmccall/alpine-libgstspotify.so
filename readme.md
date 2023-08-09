# Alpine Linux libgstspotify.so

This repository provides a GitHub Actions workflow to build and export `libgstspotify.so` as a GStreamer plugin for Spotify for Alpine Linux. The workflow is configured to build for both amd64 and arm64 architectures using Docker Buildx and QEMU. Upon a successful build, the artifacts are bundled and uploaded as a release.

# Download Release:

You can grab a pre-built .so for your Alpine system here:

https://github.com/troyxmccall/alpine-libgstspotify.so/releases

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
