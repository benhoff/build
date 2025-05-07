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

InstallOpenMediaVault() {
	# use this routine to create a Debian based fully functional OpenMediaVault
	# image (OMV 3 on Jessie, OMV 4 with Stretch). Use of mainline kernel highly
	# recommended!
	#
	# Please note that this variant changes Armbian default security
	# policies since you end up with root password 'openmediavault' which
	# you have to change yourself later. SSH login as root has to be enabled
	# through OMV web UI first
	#
	# This routine is based on idea/code courtesy Benny Stark. For fixes,
	# discussion and feature requests please refer to
	# https://forum.armbian.com/index.php?/topic/2644-openmediavault-3x-customize-imagesh/

	echo root:openmediavault | chpasswd
	rm /root/.not_logged_in_yet
	. /etc/default/cpufrequtils
	export LANG=C LC_ALL="en_US.UTF-8"
	export DEBIAN_FRONTEND=noninteractive
	export APT_LISTCHANGES_FRONTEND=none

	case ${RELEASE} in
		jessie)
			OMV_Name="erasmus"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all3.deb"
			;;
		stretch)
			OMV_Name="arrakis"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all4.deb"
			;;
	esac

	# Add OMV source.list and Update System
	cat > /etc/apt/sources.list.d/openmediavault.list <<- EOF
	deb https://openmediavault.github.io/packages/ ${OMV_Name} main
	## Uncomment the following line to add software from the proposed repository.
	deb https://openmediavault.github.io/packages/ ${OMV_Name}-proposed main

	## This software is not part of OpenMediaVault, but is offered by third-party
	## developers as a service to OpenMediaVault users.
	# deb https://openmediavault.github.io/packages/ ${OMV_Name} partner
	EOF

	# Add OMV and OMV Plugin developer keys, add Cloudshell 2 repo for XU4
	if [ "${BOARD}" = "odroidxu4" ]; then
		add-apt-repository -y ppa:kyle1117/ppa
		sed -i 's/jessie/xenial/' /etc/apt/sources.list.d/kyle1117-ppa-jessie.list
	fi
	mount --bind /dev/null /proc/mdstat
	apt-get update
	apt-get --yes --force-yes --allow-unauthenticated install openmediavault-keyring
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7AA630A1EDEE7D73
	apt-get update

	# install debconf-utils, postfix and OMV
	HOSTNAME="${BOARD}"
	debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		debconf-utils postfix
	# move newaliases temporarely out of the way (see Ubuntu bug 1531299)
	cp -p /usr/bin/newaliases /usr/bin/newaliases.bak && ln -sf /bin/true /usr/bin/newaliases
	sed -i -e "s/^::1         localhost.*/::1         ${HOSTNAME} localhost ip6-localhost ip6-loopback/" \
		-e "s/^127.0.0.1   localhost.*/127.0.0.1   ${HOSTNAME} localhost/" /etc/hosts
	sed -i -e "s/^mydestination =.*/mydestination = ${HOSTNAME}, localhost.localdomain, localhost/" \
		-e "s/^myhostname =.*/myhostname = ${HOSTNAME}/" /etc/postfix/main.cf
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		openmediavault

	# install OMV extras, enable folder2ram and tweak some settings
	FILE=$(mktemp)
	wget "$OMV_EXTRAS_URL" -qO $FILE && dpkg -i $FILE

	/usr/sbin/omv-update
	# Install flashmemory plugin and netatalk by default, use nice logo for the latter,
	# tweak some OMV settings
	. /usr/share/openmediavault/scripts/helper-functions
	apt-get -y -q install openmediavault-netatalk openmediavault-flashmemory
	AFP_Options="mimic model = Macmini"
	SMB_Options="min receivefile size = 16384\nwrite cache size = 524288\ngetwd cache = yes\nsocket options = TCP_NODELAY IPTOS_LOWDELAY"
	xmlstarlet ed -L -u "/config/services/afp/extraoptions" -v "$(echo -e "${AFP_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/smb/extraoptions" -v "$(echo -e "${SMB_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/flashmemory/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/permitrootlogin" -v "0" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/ntp/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "UTC" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/network/dns/hostname" -v "${HOSTNAME}" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/monitoring/perfstats/enable" -v "0" /etc/openmediavault/config.xml
	echo -e "OMV_CPUFREQUTILS_GOVERNOR=${GOVERNOR}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MINSPEED=${MIN_SPEED}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MAXSPEED=${MAX_SPEED}" >>/etc/default/openmediavault
	for i in netatalk samba flashmemory ssh ntp timezone interfaces cpufrequtils monit collectd rrdcached ; do
		/usr/sbin/omv-mkconf $i
	done
	/sbin/folder2ram -enablesystemd || true
	sed -i 's|-j /var/lib/rrdcached/journal/ ||' /etc/init.d/rrdcached

	# Fix multiple sources entry on ARM with OMV4
	sed -i '/stretch-backports/d' /etc/apt/sources.list

	# rootfs resize to 7.3G max and adding omv-initsystem to firstrun -- q&d but shouldn't matter
	echo 15500000s >/root/.rootfs_resize
	sed -i '/systemctl\ disable\ armbian-firstrun/i \
	mv /usr/bin/newaliases.bak /usr/bin/newaliases \
	export DEBIAN_FRONTEND=noninteractive \
	sleep 3 \
	apt-get install -f -qq python-pip python-setuptools || exit 0 \
	pip install -U tzupdate \
	tzupdate \
	read TZ </etc/timezone \
	/usr/sbin/omv-initsystem \
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "${TZ}" /etc/openmediavault/config.xml \
	/usr/sbin/omv-mkconf timezone \
	lsusb | egrep -q "0b95:1790|0b95:178a|0df6:0072" || sed -i "/ax88179_178a/d" /etc/modules' /usr/lib/armbian/armbian-firstrun
	sed -i '/systemctl\ disable\ armbian-firstrun/a \
	sleep 30 && sync && reboot' /usr/lib/armbian/armbian-firstrun

	# add USB3 Gigabit Ethernet support
	echo -e "r8152\nax88179_178a" >>/etc/modules

	# Special treatment for ODROID-XU4 (and later Amlogic S912, RK3399 and other big.LITTLE
	# based devices). Move all NAS daemons to the big cores. With ODROID-XU4 a lot
	# more tweaks are needed. CS2 repo added, CS1 workaround added, coherent_pool=1M
	# set: https://forum.odroid.com/viewtopic.php?f=146&t=26016&start=200#p197729
	# (latter not necessary any more since we fixed it upstream in Armbian)
	case ${BOARD} in
		odroidxu4)
			HMP_Fix='; taskset -c -p 4-7 $i '
			# Cloudshell stuff (fan, lcd, missing serials on 1st CS2 batch)
			echo "H4sIAKdXHVkCA7WQXWuDMBiFr+eveOe6FcbSrEIH3WihWx0rtVbUFQqCqAkYGhJn
			tF1x/vep+7oebDfh5DmHwJOzUxwzgeNIpRp9zWRegDPznya4VDlWTXXbpS58XJtD
			i7ICmFBFxDmgI6AXSLgsiUop54gnBC40rkoVA9rDG0SHHaBHPQx16GN3Zs/XqxBD
			leVMFNAz6n6zSWlEAIlhEw8p4xTyFtwBkdoJTVIJ+sz3Xa9iZEMFkXk9mQT6cGSQ
			QL+Cr8rJJSmTouuuRzfDtluarm1aLVHksgWmvanm5sbfOmY3JEztWu5tV9bCXn4S
			HB8RIzjoUbGvFvPw/tmr0UMr6bWSBupVrulY2xp9T1bruWnVga7DdAqYFgkuCd3j
			vORUDQgej9HPJxmDDv+3WxblBSuYFH8oiNpHz8XvPIkU9B3JVCJ/awIAAA==" \
			| tr -d '[:blank:]' | base64 --decode | gunzip -c >/usr/local/sbin/cloudshell2-support.sh
			chmod 755 /usr/local/sbin/cloudshell2-support.sh
			apt install -y i2c-tools odroid-cloudshell cloudshell2-fan
			sed -i '/systemctl\ disable\ armbian-firstrun/i \
			lsusb | grep -q -i "05e3:0735" && sed -i "/exit\ 0/i echo 20 > /sys/class/block/sda/queue/max_sectors_kb" /etc/rc.local \
			/usr/sbin/i2cdetect -y 1 | grep -q "60: 60" && /usr/local/sbin/cloudshell2-support.sh' /usr/lib/armbian/armbian-firstrun
			;;
		bananapim3)
			HMP_Fix='; taskset -c -p 4-7 $i '
			;;
		edge*|ficus|firefly-rk3399|nanopct4|nanopim4|nanopineo4|renegade-elite|roc-rk3399-pc|rockpro64|station-p1)
			HMP_Fix='; taskset -c -p 4-5 $i '
			;;
	esac
	echo "* * * * * root for i in \`pgrep \"ftpd|nfsiod|smbd|afpd|cnid\"\` ; do ionice -c1 -p \$i ${HMP_Fix}; done >/dev/null 2>&1" \
		>/etc/cron.d/make_nas_processes_faster
	chmod 600 /etc/cron.d/make_nas_processes_faster

	# add SATA port multiplier hint if appropriate
	[ "${LINUXFAMILY}" = "sunxi" ] && \
		echo -e "#\n# If you want to use a SATA PM add \"ahci_sunxi.enable_pmp=1\" to bootargs above" \
		>>/boot/boot.cmd

	# Filter out some log messages
	echo ':msg, contains, "do ionice -c1" ~' >/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "action " ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "netsnmp_assert" ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "Failed to initiate sched scan" ~' >>/etc/rsyslog.d/omv-armbian.conf

	# Fix little python bug upstream Debian 9 obviously ignores
	if [ -f /usr/lib/python3.5/weakref.py ]; then
		wget -O /usr/lib/python3.5/weakref.py \
		https://raw.githubusercontent.com/python/cpython/9cd7e17640a49635d1c1f8c2989578a8fc2c1de6/Lib/weakref.py
	fi

	# clean up and force password change on first boot
	umount /proc/mdstat
	chage -d 0 root
} # InstallOpenMediaVault


Main "$@"
