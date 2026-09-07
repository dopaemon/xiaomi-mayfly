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

# The two qcacld-3.0 entries are the symlinks .qca6490 and .qca6750, both
# pointing at ".". qcacld's Makefile derives WLAN_PROFILE from the last
# component of M, so the link name is the only thing selecting
# configs/<chip>_defconfig. build-kernel.sh resolves M with realpath, which
# collapses the link and leaves WLAN_PROFILE=qcacld-3.0 -> Kbuild:52 includes a
# defconfig that does not exist. -s keeps the path lexical; no other module
# path contains a symlink.
before="$(sha1sum < build/build-kernel.sh)"
sed -i 's|m_rel="$(realpath |m_rel="$(realpath -s |' build/build-kernel.sh
[ "$before" != "$(sha1sum < build/build-kernel.sh)" ] || {
    echo "build-kernel.sh m_rel patch no longer applies, check upstream" >&2
    exit 1
}

# modpost only sees KBUILD_EXTRA_SYMBOLS from a tree's Kbuild, never from its
# Makefile (scripts/Makefile.modpost prefers Kbuild when both exist). datarmnet-ext
# sets it in the Makefile only, so rmnet_core's exports are invisible and modpost
# fails with "rmnet_aps_set_prio undefined". Hand every tree the whole set through
# the environment instead; paths are relative to KERNEL_OBJ, and modpost ignores
# the ones not built yet ($(wildcard ...) in Makefile.modpost).
source ./deviceinfo
for m in $deviceinfo_kernel_external_modules; do
    KBUILD_EXTRA_SYMBOLS="$KBUILD_EXTRA_SYMBOLS ../$m/Module.symvers"
done
export KBUILD_EXTRA_SYMBOLS

./build/build.sh "$@"
