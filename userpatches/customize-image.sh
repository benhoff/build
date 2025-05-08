#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.
set -euo pipefail

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

SRC=/tmp/overlay/src
STAGE=""
JOBS=$(nproc)

: "${CACHE_ROOT:=/var/cache/ccache/build-artifacts}"
mkdir -p "${CACHE_ROOT}"


# ────────── ccache setup (mirrors Armbian kernel build) ────────────────────
export CCACHE_DIR="/var/cache/ccache"       # already bind-mounted rw
export CCACHE_TEMPDIR="/dev/shm/ccache-tmp"
export CCACHE_BASEDIR="/tmp/overlay/src"
mkdir -p "${CCACHE_DIR}" "${CCACHE_TEMPDIR}"
export PATH="/usr/lib/ccache:${PATH}"

# Optional distcc forwards (safe with set -u thanks to defaults)
export DISTCC_DIR="${DISTCC_DIR:-}"
export DISTCC_HOSTS="${DISTCC_HOSTS:-}"
export DISTCC_POTENTIAL_HOSTS="${DISTCC_POTENTIAL_HOSTS:-}"

# ────────── mark every repo in /tmp/overlay/src as “safe” for Git ──────────
if command -v git >/dev/null; then
    for repo in "${SRC}"/*; do
        [[ -d "${repo}/.git" ]] && git config --global --add safe.directory "${repo}"
    done
fi


# ---------------------------------------------------------------------------
build_and_stage() {
    local name=$1 conf_cmd=$2 build_cmd=$3 install_cmd=$4
    local rev cache_dir artefact_tar build_tar

    if [[ -d "${SRC}/${name}/.git" ]]; then
        rev="$(git -C "${SRC}/${name}" rev-parse --short HEAD)"
    else
        rev="$(stat -c %Y "${SRC}/${name}")"   # fallback: mtime
    fi
    local cache_dir="${CACHE_ROOT}/${name}"
    local artefact_tar="${cache_dir}/${rev}.tar.zst"
    local build_tar="${cache_dir}/${rev}.build.tar.zst"
	mkdir -p "${cache_dir}"

   # ---------- fast-path: restore from cache ------------------------------
    if [[ -f "${artefact_tar}" ]]; then
        echo "[cache  ] ${name} – restoring artefacts (${rev})"
        tar --zstd -xf "${artefact_tar}" -C "${STAGE:-/}"
        if [[ -f "${build_tar}" ]]; then
            local WRK="/tmp/build-${name}"
            rm -rf "${WRK}"
            mkdir -p "${WRK}"
            tar --zstd -xf "${build_tar}" -C "${WRK}"
        fi
        return
    fi

    # ---------- full build --------------------------------------------------
    echo "[build  ] ${name}"
    local WRK="/tmp/build-${name}"
    rm -rf "${WRK}"
    rsync -a --delete "${SRC}/${name}/" "${WRK}/"
    pushd "${WRK}" >/dev/null

    eval "${conf_cmd}"
    eval "${build_cmd}"

    # Install into a private dir first
    local PKGDIR
    PKGDIR="$(mktemp -d /tmp/pkg-${name}-XXXXXX)"
    DESTDIR="${PKGDIR}" eval "${install_cmd}"

    # Archive artefacts & build dir
    tar --zstd -C "${PKGDIR}" -cf "${artefact_tar}.tmp" .
    mv "${artefact_tar}.tmp" "${artefact_tar}"
    tar --zstd -C "${WRK}"   -cf "${build_tar}.tmp" .
    mv "${build_tar}.tmp"    "${build_tar}"

    # Copy into live root (or $STAGE)
    rsync -a "${PKGDIR}/" "${STAGE:-/}/"

    popd >/dev/null
    rm -rf "${WRK}" "${PKGDIR}"
}

Main() {
	case $RELEASE in
		noble)
			apt-get update && \
				apt-get install -y --no-install-recommends \
				ccache \
				build-essential \
				locales \
				git \
				ca-certificates \
				cmake \
				ninja-build \
				brotli \
				dbus \
				meson \
				libva-dev \
				libva-drm2 \
				libdouble-conversion-dev \
				libfontconfig1-dev \
				libfreetype6-dev \
				libdrm-dev \
				libglib2.0-dev \
				libharfbuzz-dev \
				libicu-dev \
				libkrb5-dev \
				libb2-dev \
				libdrm-dev \
				libice-dev \
				libinput-dev \
				libjpeg-dev \
				libpipewire-0.3-dev \
				libpng-dev \
				libproxy-dev \
				libcurl4-openssl-dev \
				libsm-dev \
				libx11-dev \
				libxcb1-dev \
				libxkbcommon-dev \
				libxkbcommon-x11-dev \
				libegl-dev \
				libgles-dev \
				libgl-dev \
				libgbm-dev \
				openssl \
				libssl-dev \
				libpcre2-dev \
				shared-mime-info \
				libsqlite3-dev \
				libsystemd-dev \
				libts-dev \
				libvulkan-dev \
				libwayland-dev \
				libxcb-util-dev \
				libxcb-cursor-dev \
				libxcb-image0-dev \
				libxcb-keysyms1-dev \
				libxcb-render-util0-dev \
				libxcb-icccm4-dev \
				libxcb-sync-dev \
				libxdg-basedir-dev \
				zlib1g-dev \
				zstd \
				libasound2-dev \
				freetds-dev \
				libgstreamer1.0-dev \
				gstreamer1.0-plugins-good \
				libgtk-3-dev \
				libfbclient2 \
				libpulse-dev \
				libmariadb-dev \
				libpq-dev \
				unixodbc-dev \
				xmlstarlet \
				perl \
				libglvnd-dev \
				libglx-dev \
				libopengl-dev \
				libspeexdsp-dev \
				libboost-all-dev \
				pkg-config \
				libpci-dev \
				libmsgsl-dev \
				libsecret-1-dev \
				llvm-dev \
				libclang-dev \
				libclc-18-dev \
				python3-mako \
				python3-markupsafe \
				python3-ply \
				python3-pygments \
				gstreamer1.0-plugins-base \
				va-driver-all \
				libexpat1-dev \
				libxext-dev \
				libxcb-xfixes0-dev \
				libxfixes-dev \
				libxcb-shm0-dev \
				libxxf86vm-dev \
				libxshmfence-dev \
				libxcb-glx0 \
				libxcb-dri2-0-dev \
				libxcb-dri3-dev \
				libxcb-glx0-dev \
				libva-wayland2 \
				libx11-xcb-dev \
				libxshmfence-dev \
				libxxf86vm-dev \
				wayland-protocols \
				glslang-tools \
				icu-devtools \
				libwayland-dev \
				libvdpau-dev \
				libvdpau1 \
				libvulkan-dev \
				libvulkan1 \
				libwayland-egl-backend-dev \
				libxcb-present-dev \
				libxcb-randr0 \
				libxcb-randr0-dev \
				libxcb-sync-dev \
				libxrandr-dev \
				libllvmspirvlib-18-dev
			;;
		stretch)
			# your code here
			# InstallOpenMediaVault # uncomment to get an OMV 4 image
			;;
		buster)
			# your code here
			;;
		bullseye)
			# your code here
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
	esac
	if [[ -d ${SRC}/mesa ]]; then
		build_and_stage mesa \
			"meson setup build -Dvulkan-drivers= -Dgallium-drivers=panfrost -Degl=true -Dgbm=true -Dglvnd=true" \
			"ninja -C build -j$JOBS" \
			"DESTDIR=${STAGE} ninja -C build install"
	fi

	# 2) rkmpp
	build_and_stage rkmpp \
   "rm -rf rkmpp_build && mkdir rkmpp_build && cmake -S . -B rkmpp_build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF" \
   "make -C rkmpp_build -j$JOBS" \
   "make -C rkmpp_build install"

	build_and_stage rkrga \
	  "meson setup rkrga_build --prefix=/usr --libdir=lib --buildtype=release --default-library=shared -Dcpp_args=-fpermissive -Dlibdrm=false -Dlibrga_demo=false" \
	  "ninja -C rkrga_build -j$JOBS" \
	  "ninja -C rkrga_build install"

	# 4) ffmpeg‑rockchip
	build_and_stage ffmpeg-rockchip \
	  "./configure --prefix=/usr --enable-version3 \
				   --enable-libdrm --enable-rkmpp --enable-rkrga \
				   --disable-xlib --disable-libxcb --disable-libxcb-shm \
				   --disable-libxcb-xfixes --disable-libxcb-shape" \
	  "make -j$JOBS" \
	  "make install"

	# 5) Qt base
	QtV=6.8.3
        build_and_stage qtbase \
          "rm -rf build && cmake -S . -B build -G Ninja \
		      -DCMAKE_INSTALL_PREFIX=/usr \
				-DCMAKE_BUILD_TYPE=RelWithDebInfo \
				-DINSTALL_BINDIR=lib/qt6/bin \
				-DINSTALL_PUBLICBINDIR=usr/bin \
				-DINSTALL_LIBEXECDIR=lib/qt6 \
				-DINSTALL_DOCDIR=share/doc/qt6 \
				-DINSTALL_ARCHDATADIR=lib/qt6 \
				-DINSTALL_DATADIR=share/qt6 \
				-DINSTALL_INCLUDEDIR=include/qt6 \
				-DINSTALL_MKSPECSDIR=lib/qt6/mkspecs \
				-DQT_NO_MAKE_EXAMPLES=ON \
				-DQT_INSTALL_EXAMPLES_SOURCES_BY_DEFAULT=OFF \
				-DQT_BUILD_EXAMPLES_BY_DEFAULT=OFF \
				-DQT_BUILD_TESTS_BY_DEFAULT=OFF \
				-DQT_BUILD_EXAMPLES=OFF \
				-DQT_BUILD_TESTS=OFF \
				-DFEATURE_journald=ON \
				-DFEATURE_libproxy=ON \
				-DQT_FEATURE_eglfs=ON \
				-DFEATURE_openssl_linked=ON \
				-DFEATURE_system_sqlite=ON \
				-DFEATURE_no_direct_extern_access=OFF \
				-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
				-DQT_FEATURE_opengles2=ON \
				-DQT_FEATURE_opengles3=ON" \
          "cmake --build build -j$JOBS" \
          "cmake --install build"
	# 6..9) Qt modules, ECM, ktexttemplate, qtkeychain  (loop)
	for mod in qtshadertools qtwebsockets qtdeclarative ; do
	  [[ -d ${SRC}/${mod} ]] || continue
      build_and_stage "${mod}" \
        "rm -rf build && \
		 export CFLAGS=\"\$(pkg-config --cflags libva libva-drm)\" && \
		 export LDFLAGS=\"\$(pkg-config --libs libva libva-drm)\" && \
		cmake -S . -B build -G Ninja \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DINSTALL_BINDIR=lib/qt6/bin \
            -DINSTALL_PUBLICBINDIR=usr/bin \
            -DINSTALL_LIBEXECDIR=lib/qt6 \
            -DINSTALL_DATADIR=share/qt6 \
            -DINSTALL_INCLUDEDIR=include/qt6 \
            -DINSTALL_MKSPECSDIR=lib/qt6/mkspecs \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON" \
        "cmake --build build -j$JOBS" \
        "cmake --install build"
	done

        build_and_stage qtmultimedia \
        "rm -rf build && \
		cmake -S . -B build -G Ninja \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DINSTALL_BINDIR=lib/qt6/bin \
            -DINSTALL_PUBLICBINDIR=usr/bin \
            -DINSTALL_LIBEXECDIR=lib/qt6 \
            -DINSTALL_DATADIR=share/qt6 \
            -DINSTALL_INCLUDEDIR=include/qt6 \
            -DINSTALL_MKSPECSDIR=lib/qt6/mkspecs \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
			-DQT_FEATURE_ffmpeg=OFF "\
        "cmake --build build -j$JOBS" \
        "cmake --install build"

	for mod in qtnetworkauth qthttpserver qtremoteobjects extra-cmake-modules ktexttemplate qtkeychain; do
	  [[ -d ${SRC}/${mod} ]] || continue


		# ---- default flags shared by most Qt‑based modules --------------------
		cmake_flags="-DCMAKE_INSTALL_PREFIX=/usr \
					 -DCMAKE_BUILD_TYPE=RelWithDebInfo \
					 -DINSTALL_BINDIR=lib/qt6/bin \
					 -DINSTALL_PUBLICBINDIR=usr/bin \
					 -DINSTALL_LIBEXECDIR=lib/qt6 \
					 -DINSTALL_DATADIR=share/qt6 \
					 -DINSTALL_INCLUDEDIR=include/qt6 \
					 -DINSTALL_MKSPECSDIR=lib/qt6/mkspecs \
					 -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
					 -DCMAKE_MESSAGE_LOG_LEVEL=STATUS"

		# ---- module‑specific tweaks ------------------------------------------
		case "$mod" in
			extra-cmake-modules)
				# ECM is a pure CMake helper library: no Qt‑specific install dirs
				cmake_flags="-DCMAKE_INSTALL_PREFIX=/usr \
							 -DCMAKE_BUILD_TYPE=RelWithDebInfo \
							 -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
							 -DCMAKE_MESSAGE_LOG_LEVEL=STATUS"
				;;
			ktexttemplate)
				# already fine with default flags (needs Qt‑style install dirs)
				;;
			qtkeychain)
				cmake_flags="${cmake_flags} \
							 -DBUILD_WITH_QT6=ON \
							 -DBUILD_TRANSLATIONS=OFF"
				;;
			esac

		build_and_stage "$mod" \
			"rm -rf build && cmake -S . -B build -G Ninja ${cmake_flags}" \
			"cmake --build build -j${JOBS}" \
			"cmake --install build"

	done
} # Main


Main "$@"
