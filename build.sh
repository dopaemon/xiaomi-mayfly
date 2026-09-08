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

# Kernel plus 18 module trees is ~35 min of clang. build.sh rebuilds PATH from
# scratch for the LLVM branch (ALLOWED_HOST_TOOLS + the prebuilt toolchains), so
# a ccache in the ambient PATH is simply not seen. Hand it an extra directory
# instead, holding the usual ccache masquerade symlinks: ccache skips its own
# directory when resolving the real compiler, so it still finds the prebuilt
# clang further down the same PATH. No ccache installed -> CCACHE_SHIM stays
# empty and the substitution expands to nothing.
if command -v ccache >/dev/null; then
    CCACHE_SHIM="$(pwd)/workdir/ccache-shim"
    mkdir -p "$CCACHE_SHIM"
    for tool in clang clang++; do
        ln -sf "$(command -v ccache)" "$CCACHE_SHIM/$tool"
    done
    export CCACHE_SHIM
    before="$(sha1sum < build/build.sh)"
    sed -i 's|PATH="$CLANG_PATH/bin:|PATH="${CCACHE_SHIM:+${CCACHE_SHIM}:}$CLANG_PATH/bin:|' build/build.sh
    [ "$before" != "$(sha1sum < build/build.sh)" ] || {
        echo "build.sh PATH patch no longer applies, check upstream" >&2
        exit 1
    }
    ccache -z >/dev/null || true
fi

# make-bootimage.sh applies ramdisk-overlay/ by appending it to the boot ramdisk
# as a second cpio archive (make-bootimage.sh:194). The kernel concatenated-
# archive path only works when it can find where one archive ends, and its lz4
# legacy decompressor consumes the trailing bytes, so with
# deviceinfo_ramdisk_compression=lz4 the overlay is silently dropped -- no error,
# no log, and the initrd runs upstream's scripts/halium. mayfly needs the
# patched one (slot_suffix from bootconfig), so merge the overlay into the base
# archive instead of appending a second one.
before="$(sha1sum < build/make-bootimage.sh)"
sed -i 's#    find \. | cpio -o -H newc | $COMPRESSION_CMD >> "$RAMDISK"#    rm -rf "$TMPDOWN/boot-ramdisk" \&\& mkdir -p "$TMPDOWN/boot-ramdisk" \&\& ( cd "$TMPDOWN/boot-ramdisk" \&\& ${COMPRESSION_CMD%% *} -dc < "$RAMDISK" | cpio -idmu --quiet ) \&\& cp -a "$HERE/ramdisk-overlay"/. "$TMPDOWN/boot-ramdisk"/ \&\& ( cd "$TMPDOWN/boot-ramdisk" \&\& find . | cpio -o -H newc --quiet ) | $COMPRESSION_CMD > "$RAMDISK.new" \&\& mv "$RAMDISK.new" "$RAMDISK"#' build/make-bootimage.sh
[ "$before" != "$(sha1sum < build/make-bootimage.sh)" ] || {
    echo "make-bootimage.sh ramdisk-overlay merge patch no longer applies, check upstream" >&2
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

# set -e: the guard must not be the failing last command
command -v ccache >/dev/null && ccache -s | head -5 || true
