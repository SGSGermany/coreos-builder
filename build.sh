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

cmd() {
    echo + "$@"
    "$@"
    return $?
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $BASE_IMAGE)\""
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/"
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

cmd buildah run "$CONTAINER" -- \
    adduser --uid 65536 --shell "/sbin/nologin" --disabled-login \
        --home "/var/local/coreos-builder" --no-create-home --gecos "" \
        coreos-builder

cmd buildah run "$CONTAINER" -- \
    chown -h coreos-builder:coreos-builder \
        "/usr/local/src/coreos-installer" \
        "/var/local/coreos-builder"

cmd buildah run "$CONTAINER" -- \
    rustup target add x86_64-unknown-linux-gnu

cmd buildah run "$CONTAINER" -- \
    apt-get update

# build dependencies
cmd buildah run "$CONTAINER" -- \
    apt-get install --no-install-recommends -y pkg-config libssl-dev

# runtime dependencies
cmd buildah run "$CONTAINER" -- \
    apt-get install --no-install-recommends -y gpg gpg-agent

cmd buildah run "$CONTAINER" -- \
    apt-get clean

cmd buildah run "$CONTAINER" -- \
    find /var/lib/apt/lists/ -mindepth 1 -delete

cmd buildah run "$CONTAINER" -- \
    cargo install cargo-download

cmd buildah run "$CONTAINER" -- \
    rm -rf /usr/local/cargo/registry /usr/local/cargo/git

cmd buildah config \
    --volume "/var/local/coreos-builder" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/local/coreos-builder" \
    --cmd "coreos-builder" \
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

cmd buildah commit "$CONTAINER" "$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "$IMAGE:${TAGS[0]}" "$IMAGE:$TAG"
done
