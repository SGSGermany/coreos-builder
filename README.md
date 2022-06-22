CoreOS Builder
==============

CoreOS Builder (`coreos-builder`) is a container to ease reprovisioning some
bare metal [Fedora CoreOS][1] (FCOS) instances.

The single purpose of this container is to execute the [`coreos-builder`][2]
script which

* downloads the latest raw image of [Fedora CoreOS][1], and
* compiles a generic `x86_64` binary of [`coreos-installer`][3]
  (Rust target: `x86_64-unknown-linux-gnu`).

Both the `coreos-installer` binary as well as the downloaded FCOS raw
images are being stored in `/var/local/coreos-builder`. Additionally a
`fedora-coreos-latest.x86_64.raw.xz` symlink that points to the latest
image is created. `/var/local/coreos-builder` is expected to be a volume.
You can (and probably should) delete this container right after execution.

The goal of this project is to ease reprovisioning a FCOS instance on
bare metal platforms on which the recommended ISO-/PXE-based reprovisioning
process isn't possible. This can be true for some cloud platforms, too.

To do so you first run this container to download FCOS' latest raw image
and compile `coreos-installer`. You then reboot into an arbitrary live
system, mount the partition which stores `/var/local/coreos-builder`
and run `coreos-installer install` with the `--image-file` option.

`coreos-installer` is built from the latest [crates.io][4] sources. Running
this container will always give you the latest version of `coreos-installer`.
Due to the nature of this container, it doesn't need frequent rebuilds.
Thus it is rebuild only once a month, precisely on the 15th day at 22:20 UTC.

[1]: https://getfedora.org/en/coreos/
[2]: ./src/usr/local/bin/coreos-builder
[3]: https://coreos.github.io/coreos-installer/
[4]: https://crates.io/crates/coreos-installer
