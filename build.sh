#!/bin/bash
set -xe

# The kleaf branch is the only one with deviceinfo_kernel_extra_repos and
# deviceinfo_kernel_external_modules, which mayfly needs for sm8450-modules.
[ -d build ] || git clone -b "${BUILD_TOOLS_BRANCH:-personal/notkit/build-kleaf-modules}" \
    https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git build

./build/build.sh "$@"
