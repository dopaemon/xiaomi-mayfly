#!/bin/bash
set -xe

# The kleaf branch is the only one with deviceinfo_kernel_extra_repos and
# deviceinfo_kernel_external_modules, which mayfly needs for sm8450-modules.
[ -d build ] || git clone -b "${BUILD_TOOLS_BRANCH:-personal/notkit/build-kleaf-modules}" \
    https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git build

# build-kernel.sh asks each module tree for the "modules" target, but only the
# QCOM Makefiles carrying a "%:" catch-all forward it to the kernel. The rest
# (datarmnet, datarmnet-ext/*, qcacld-3.0) define just all/modules_install/clean
# and die with "No rule to make target 'modules'". Every one of the 18 trees has
# a working "all", so ask for that instead.
before="$(sha1sum < build/build-kernel.sh)"
sed -i 's/ -j"$(nproc --all)" modules$/ -j"$(nproc --all)" all/' build/build-kernel.sh
[ "$before" != "$(sha1sum < build/build-kernel.sh)" ] || {
    echo "build-kernel.sh module target patch no longer applies, check upstream" >&2
    exit 1
}

./build/build.sh "$@"
