# Banana Pi M2 Ultra

## battery-info
The images include a `battery-info` script that dumps a bunch of data about
the power and battery status of the device. The source is in
[userpatches/](userpatches/).

`i2c-tools` will need to be installed to run the script. (Currently, the Armbian
build system complains about readonly variables when trying to install it during
the build.)

## Cooling Fan
A systemd service for a fan, `cooling-fan.service`, is created but not enabled
by default. This service sets a GPIO pin (13, BCM 277) high early in the boot
process, which can be used to switch a fan on through appropriate circuity (see
[Single Board Computer Power and LED Status Boards](https://github.com/moonbuggy/sbc-power-status-boards)
for an example).

## eMMC
The eMMC doesn't seem to work on my Banana Pi M2 Ultra. This is a problem
because Armbian scans available disks very early in the boot process and locks
up when it finds the eMMC.

These images have the eMMC disabled by an `mmc2-disable` device tree overlay,
which allows the system to boot. Removing this overlay from
`/boot/armbianEnv.txt` will re-enable the eMMC.

## WiFi
The images are built with `EXTRAWIFI="no"`, so external USB WiFi adapters
probably won't work.

## wsdd
As there's no APT package available for Debian Bullseye, wsdd is installed from
the [Github repo](https://github.com/christgau/wsdd) for this release. A `wsdd`
user and systemd service is created, however the service is not enabled by
default.
