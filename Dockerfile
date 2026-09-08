# Build environment for the port. Mirrors the CI image (ubuntu:22.04): noble
# has neither libtinfo5 nor python2, both of which the kernel build tools want.
FROM ubuntu:22.04

# Package list is the union of the CI jobs: build (kernel + module trees) and
# devel-flashable (rootfs image from the device tarball).
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bc bison build-essential ca-certificates cpio curl fakeroot flex git \
      img2simg jq kmod libbpf-dev libelf-dev libssl-dev libtinfo5 lz4 pahole \
      python2 python3 rsync sudo unzip wget xz-utils zstd \
 && ln -sf python2 /usr/bin/python \
 && rm -rf /var/lib/apt/lists/*

# The adaptation tools clone into ./build and build into ./workdir, both
# relative to the port checkout.
WORKDIR /src

ENV BUILD_TOOLS_BRANCH=personal/notkit/build-kleaf-modules

CMD ["./build.sh"]
