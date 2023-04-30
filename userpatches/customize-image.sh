#!/bin/bash
# shellcheck disable=SC2034

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	case $BOARD in
		bananapim2ultra)
			# disable eMMC
			echo "Disabling eMMC.."
			cp /tmp/overlay/bananapim2ultra-mmc2-disable.dts ./mmc2-disable.dts
			armbian-add-overlay ./mmc2-disable.dts

			# install battery-info
			echo "Installing battery-info.."
			cp /tmp/overlay/bananapim2ultra-battery-info.sh /usr/local/bin/battery-info
			chmod a+x /usr/local/bin/battery-info

			# install battery-info
			echo "Installing cooling-fan service.."
			cp /tmp/overlay/bananapim2ultra-cooling-fan.service /etc/systemd/system/cooling-fan.service
			;;
	esac

	case $RELEASE in
		bullseye)
			# wsdd isn't available as a pacakge, so install manually
			echo "Installing wsdd.."
			wget -qO- https://github.com/zhiverbox/armbian-userpatches/raw/master/customize-image.sh >/usr/bin/wsdd
			chmod a+x /usr/bin/wsdd
			useradd --system wsdd
			wget -qO- https://github.com/christgau/wsdd/raw/master/etc/systemd/wsdd.defaults >/etc/default/wsdd
			wget -qO- https://github.com/christgau/wsdd/raw/master/etc/systemd/wsdd.service >/etc/systemd/system/wsdd.service

			# adding .profile to root to source .bashrc and give coloured prompts
			echo "Installing root profile.."
			cp /tmp/overlay/root.profile /root/.profile
			;;
	esac
} # Main

Main "$@"
