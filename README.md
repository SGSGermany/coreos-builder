CoreOS Builder
==============

CoreOS Builder (`coreos-builder`) is a container to ease reprovisioning some
bare metal [Fedora CoreOS][1] instances.

The single purpose of this container is to execute the [`coreos-builder`][2]
script which

* downloads the latest raw image of [Fedora CoreOS][1], and
* compiles a generic `x86_64` binary of [`coreos-installer`][3]
  (Rust target: `x86_64-unknown-linux-gnu`).

Both the `coreos-installer` binary as well as the downloaded CoreOS raw
images are being stored in `/var/local/coreos-builder`. Additionally a
`fedora-coreos-latest.x86_64.raw.xz` symlink that points to the latest
image is created. `/var/local/coreos-builder` is expected to be a volume.
You can (and probably should) delete this container right after execution.

The goal of this project is to ease reprovisioning a CoreOS instance on
bare metal platforms on which the recommended ISO-/PXE-based reprovisioning
process isn't possible.

To do so you first run this container to download CoreOS' latest raw image
and compile `coreos-installer`. You then reboot into an arbitrary live
system, mount the partition which stores `/var/local/coreos-builder`
and run `coreos-installer install` with the `--image-file` option.

[1]: https://getfedora.org/en/coreos/
[2]: ./src/usr/local/bin/coreos-builder
[3]: https://coreos.github.io/coreos-installer/
