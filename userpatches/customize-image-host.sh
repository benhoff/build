#!/usr/bin/env bash
set -e

# ────────── host‑side folder map ──────────────────────────
OVL_DIR="${USERPATCHES_PATH}/overlay"          # bind‑mounted later at /tmp/overlay
SRC_DIR="${OVL_DIR}/src"                       # chroot will see this as /tmp/overlay/src
GIT_CACHE="$(dirname "$USERPATCHES_PATH")/repos"   # purely host; not used by Armbian

mkdir -p "${OVL_DIR}" "${SRC_DIR}" "${GIT_CACHE}"

# ────────── helper: clone or refresh repo ─────────────────
clone_or_update() {
    local url=$1   repo_name=$2   ref=${3:-main}
    local repo_path="${GIT_CACHE}/${repo_name}"

    # Git “safe.directory” so UID mismatch inside Docker isn’t an issue
    git config --global --add safe.directory "${repo_path}"

    if [[ -d "${repo_path}/.git" ]]; then
        echo "[host] Updating ${repo_name} → ${ref}"
        git -C "${repo_path}" fetch --prune --tags
        git -C "${repo_path}" checkout "${ref}"
        # pull only if it's a branch
        git -C "${repo_path}" rev-parse --verify --quiet "origin/${ref}" && \
          git -C "${repo_path}" pull --ff-only || true
    else
        echo "[host] Cloning ${repo_name} → ${ref}"
        if git ls-remote --heads "${url}" "${ref}" &>/dev/null; then
            git clone --depth 1 --branch "${ref}" "${url}" "${repo_path}"
        else
            git clone "${url}" "${repo_path}"
            git -C "${repo_path}" checkout --detach "${ref}"
        fi
    fi

    # expose clean tree (no .git) to chroot
    rsync -a --delete --exclude=.git "${repo_path}/" "${SRC_DIR}/${repo_name}/"
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

