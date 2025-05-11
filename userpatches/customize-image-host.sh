#!/usr/bin/env bash
set -e

# ────────── host-side folder map ──────────────────────────
PATCHES_DIR="${USERPATCHES_PATH}/src"         # where we keep our “master” clones
OVL_DIR="${USERPATCHES_PATH}/overlay"        # bind-mounted later at /tmp/overlay
OVL_SRC="${OVL_DIR}/src"                     # chroot will see this as /tmp/overlay/src

# ensure directories exist
mkdir -p "${PATCHES_DIR}" "${OVL_DIR}" "${OVL_SRC}"

# ────────── helper: clone or refresh repo ─────────────────
clone_or_update() {
    local url=$1
    local repo_name=$2
    local ref=${3:-main}

    local local_repo="${PATCHES_DIR}/${repo_name}"
    local overlay_repo="${OVL_SRC}/${repo_name}"

    # avoid safe.directory errors inside Docker
    git config --global --add safe.directory "${local_repo}"

    if [[ -d "${local_repo}/.git" ]]; then
        echo "[host] Updating ${repo_name} → ${ref}"
        git -C "${local_repo}" fetch --prune --tags
        git -C "${local_repo}" checkout "${ref}"
        # only pull if it's really a branch
        if git -C "${local_repo}" rev-parse --verify --quiet "origin/${ref}"; then
            git -C "${local_repo}" pull --ff-only
        fi
    else
        echo "[host] Cloning ${repo_name} → ${ref}"
        if git ls-remote --heads "${url}" "${ref}" &>/dev/null; then
            git clone --depth 1 --branch "${ref}" "${url}" "${local_repo}"
        else
            git clone "${url}" "${local_repo}"
            git -C "${local_repo}" checkout --detach "${ref}"
        fi
    fi

    # ────────── mirror into overlay ─────────────────────────
    rm -rf "${overlay_repo}"
    mkdir -p "${OVL_SRC}"
    cp -a "${local_repo}" "${overlay_repo}"
}

# ────────── versions & repo list ──────────────────────────
QtV=6.8.3
ECMV=v6.2.0
KEYV=0.14.3

clone_or_update https://gitlab.freedesktop.org/mesa/mesa.git             mesa                 24.0
clone_or_update https://github.com/nyanmisaka/mpp.git                   rkmpp                jellyfin-mpp
clone_or_update https://github.com/nyanmisaka/rk-mirrors.git            rkrga                jellyfin-rga
clone_or_update https://github.com/nyanmisaka/ffmpeg-rockchip.git       ffmpeg-rockchip      master

clone_or_update https://github.com/qt/qtbase.git                        qtbase               $QtV
clone_or_update https://github.com/qt/qtshadertools.git                 qtshadertools        $QtV
clone_or_update https://github.com/qt/qtwebsockets.git                  qtwebsockets         $QtV
clone_or_update https://github.com/qt/qtdeclarative.git                 qtdeclarative        $QtV
clone_or_update https://github.com/qt/qtmultimedia.git                  qtmultimedia         $QtV
clone_or_update https://github.com/qt/qtnetworkauth.git                 qtnetworkauth        $QtV
clone_or_update https://github.com/qt/qthttpserver.git                  qthttpserver         $QtV
clone_or_update https://github.com/qt/qtremoteobjects.git               qtremoteobjects      $QtV

clone_or_update https://github.com/KDE/extra-cmake-modules.git          extra-cmake-modules  $ECMV
clone_or_update https://github.com/KDE/ktexttemplate.git                ktexttemplate        $ECMV
clone_or_update https://github.com/frankosterfeld/qtkeychain.git        qtkeychain           $KEYV
git config --global --add safe.directory /root/armbian/swdev/wulf-linux-config-bare
git config --global --add safe.directory /root/armbian/swdev/background_recorder_bare

clone_or_update /root/armbian/swdev/wulf-linux-config-bare				wulf-linux-config	master
clone_or_update /root/armbian/swdev/background_recorder_bare			background_recorder	master
