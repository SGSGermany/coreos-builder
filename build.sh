#!/bin/bash
# coreos-builder
# A container to ease reprovisioning bare metal CoreOS instances.
#
# Copyright (c) 2021  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-debian.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

user_add "$CONTAINER" coreos-builder 65536 "/var/local/coreos-builder"

cmd buildah run "$CONTAINER" -- \
    chown -h coreos-builder:coreos-builder \
        "/usr/local/src/coreos-installer" \
        "/var/local/coreos-builder"

pkg_install "$CONTAINER" \
    curl

pkg_install "$CONTAINER" \
    gcc \
    libc6-dev \
    libssl-dev \
    pkg-config

cmd buildah run "$CONTAINER" -- \
    apt-mark auto \
        libc6-dev

pkg_install "$CONTAINER" \
    gpg \
    gpg-agent \
    ca-certificates

cmd buildah config \
    --env RUSTUP_HOME="/usr/local/rustup" \
    --env CARGO_HOME="/usr/local/cargo" \
    --env PATH="/usr/local/cargo/bin:\$PATH" \
    "$CONTAINER"

echo + "mkdir …/usr/local/rustup …/usr/local/cargo" >&2
mkdir "$MOUNT/usr/local/rustup" \
    "$MOUNT/usr/local/cargo"

echo + "chmod -R a+w …/usr/local/rustup …/usr/local/cargo" >&2
chmod -R a+w "$MOUNT/usr/local/rustup" \
    "$MOUNT/usr/local/cargo"

cmd buildah run "$CONTAINER" -- \
    sh -c 'curl -sSf https://sh.rustup.rs | sh -s -- --profile minimal --no-modify-path -y'

cmd buildah run "$CONTAINER" -- \
    cargo install cargo-download

echo + "rm -rf …/usr/local/cargo/{registry,git}" >&2
rm -rf \
    "$MOUNT/usr/local/cargo/registry" \
    "$MOUNT/usr/local/cargo/git"

cmd buildah run "$CONTAINER" -- \
    apt-get remove --autoremove --purge --yes \
        curl

cleanup "$CONTAINER"

cmd buildah config \
    --volume "/var/local/coreos-builder" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/local/coreos-builder" \
    --cmd '[ "coreos-builder" ]' \
    --user "coreos-builder" \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="CoreOS Builder" \
    --annotation org.opencontainers.image.description="A container to ease reprovisioning bare metal CoreOS instances." \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/coreos-builder" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
