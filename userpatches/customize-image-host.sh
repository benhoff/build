#!/usr/bin/env bash
set -e pipefail


git config --global --add safe.directory "${USERPATCHES_PATH}/src"

# Everything you put in ${USERPATCHES_PATH}/overlay will be visible later
OVL="${USERPATCHES_PATH}/overlay"

BASE="$(dirname "$USERPATCHES_PATH")"
GITSRC="${BASE}/repos"            # <-- outside userpatches
mkdir -p "${OVL}" "${GITSRC}"


clone_or_update () {
    local repo_url=$1
    local name=$2
    local ref=${3:-main}          # default to 'main' if not given
    local repo_path="${GITSRC}/${name}"

    if [[ -d "${GITSRC}/${name}/.git" ]]; then
        echo "[host] Marking ${target} as safe"
        git config --global --add safe.directory "${repo_path}"

        echo "[host] Updating ${name} → ${ref}"
        git -C "${GITSRC}/${name}" fetch --prune --tags

        # Is <ref> a branch that exists in remotes/origin?
        if git -C "${GITSRC}/${name}" show-ref --verify --quiet "refs/remotes/origin/${ref}"; then
            git -C "${GITSRC}/${name}" checkout "${ref}"
            git -C "${GITSRC}/${name}" pull --ff-only
        else
            # Assume tag or commit → detach; no further pulls
            git -C "${GITSRC}/${name}" checkout --detach "${ref}"
        fi
    else
        echo "[host] Cloning ${name} → ${ref}"
        # If <ref> is a branch we can shallow‑clone it; else get full history for tag/sha
        if git ls-remote --heads "${repo_url}" "${ref}" &>/dev/null; then
            git clone --depth 1 --branch "${ref}" "${repo_url}" "${GITSRC}/${name}"
        else
            git clone "${repo_url}" "${GITSRC}/${name}"
            git -C "${GITSRC}/${name}" checkout --detach "${ref}"
        fi
		echo "[host] Marking ${target} as safe"
        git config --global --add safe.directory "${repo_path}"
    fi
}

EXTRA_CMAKE_MODULES_VERSION="v6.2.0"
QT_VERSION=6.8.3
QTKEYCHAIN_VERSION="0.14.3"

clone_or_update https://github.com/nyanmisaka/ffmpeg-rockchip.git ffmpeg-rockchip master
clone_or_update https://github.com/qt/qtbase.git qtbase $QT_VERSION
clone_or_update https://github.com/qt/qtshadertools.git qtshadertools $QT_VERSION
clone_or_update https://github.com/qt/qtwebsockets.git qtwebsockets $QT_VERSION
clone_or_update https://github.com/qt/qtdeclarative.git qtdeclarative $QT_VERSION
clone_or_update https://github.com/qt/qtmultimedia.git qtmultimedia $QT_VERSION
clone_or_update https://github.com/qt/qtnetworkauth.git qtnetworkauth $QT_VERSION
clone_or_update https://github.com/qt/qthttpserver.git qthttpserver $QT_VERSION
clone_or_update https://github.com/qt/qtwebsockets.git qtwebsockets $QT_VERSION
clone_or_update https://github.com/qt/qtremoteobjects.git qtremoteobjects $QT_VERSION
clone_or_update https://github.com/KDE/extra-cmake-modules.git extra-cmake-modules "$EXTRA_CMAKE_MODULES_VERSION"
clone_or_update https://github.com/KDE/ktexttemplate.git ktexttemplate "$EXTRA_CMAKE_MODULES_VERSION"
clone_or_update https://github.com/frankosterfeld/qtkeychain.git qtkeychain "$QTKEYCHAIN_VERSION"
