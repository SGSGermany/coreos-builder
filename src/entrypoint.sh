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

[ $# -gt 0 ] || set -- coreos-builder
if [ "$1" == "coreos-builder" ]; then
    # run coreos-builder unprivileged
    exec su -p -s /bin/bash coreos-builder -c '"$@"' -- '/bin/bash' "$@"
fi

exec "$@"
