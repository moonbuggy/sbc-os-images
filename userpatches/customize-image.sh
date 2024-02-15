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

install_overlays() {
	for overlay in "$@"; do
		dtc -@ -q -I dts -O dtb -o "/boot/overlay-user/${overlay}.dtbo" "${overlay}.dts"
	done
}

install_and_enable_overlays() {
	for overlay in "$@"; do
		armbian-add-overlay "${overlay}.dts"
	done
}

Main() {
	case $BOARD in
		bananapim2ultra)
			echo "Disabling eMMC.."
			install_and_enable_overlays mmc2-disable

			echo "Installing battery-info.."
			cp /tmp/overlay/bananapim2ultra-battery-info.sh /usr/local/bin/battery-info
			chmod a+x /usr/local/bin/battery-info

			echo "Installing cooling-fan service.."
			cp /tmp/overlay/bananapim2ultra-cooling-fan.service /etc/systemd/system/cooling-fan.service

			echo "Setting 'console=serial'.."
			sed -E 's|(^console=)(.*)|\1serial|' -i /boot/armbianEnv.txt
			;;

		bananapim3)
			echo "Installing battery-info.."
			cp /tmp/overlay/bananapim2ultra-battery-info.sh /usr/local/bin/battery-info
			chmod a+x /usr/local/bin/battery-info

			echo "Setting 'console=serial'.."
                        sed -E 's|(^console=)(.*)|\1serial|' -i /boot/armbianEnv.txt
			;;

		orangepizero)
			cd /boot/overlay-user/ || true

			echo "Installing ST7789V SPI display overlays.."
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/overlays/st7789v-240x280.dts
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/overlays/st7789v-240x320.dts
			install_overlays st7789v-240x280
			install_and_enable_overlays st7789v-240x320

			echo "Installing DS3231N RTC overlay.."
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/overlays/rtc-ds3231n.dts
			install_and_enable_overlays rtc-ds3231n

			echo "Installing power switch overlays.."
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/overlays/gpio-key-power.dts
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/overlays/sun8i-h3-gpio-poweroff.dts
			install_and_enable_overlays gpio-key-power sun8i-h3-gpio-poweroff

			cd /tmp/ || true

			echo "Installing fbgpsclock.."
			wget -qO fbgpsclock https://github.com/moonbuggy/fbgpsclock/raw/main/bin/fbgpsclock.armv7
			wget -q https://github.com/moonbuggy/fbgpsclock/raw/main/fbgpsclock.ini
			wget -q https://github.com/moonbuggy/fbgpsclock/raw/main/fbgpsclock.service

			install -c fbgpsclock '/usr/local/bin'
			install -c -m 644 fbgpsclock.ini '/usr/local/etc'
			install -c -m 644 fbgpsclock.service '/lib/systemd/system'

			rm -f fbgpsclock fbgpsclock.ini fbgpsclock.service

			echo "Configuring chrony and gpsd.."
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/root/etc/chrony/conf.d/gpsd.conf \
				-O /etc/chrony/conf.d/gpsd.conf
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/root/etc/default/chrony \
				-O /etc/default/chrony
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/root/etc/default/gpsd \
				-O /etc/default/gpsd
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/root/usr/lib/systemd/system/ready-led.service \
				-O /usr/lib/systemd/system/ready-led.service
			wget -q https://github.com/moonbuggy/Orange-Pi-Zero-GPS-NTP/raw/main/root/usr/lib/systemd/system/ready.target \
				-O /usr/lib/systemd/system/ready.target
			echo 'param_pps_pin=PA3' >> /boot/armbianEnv.txt

			echo "Enabling Armbian overlays.."
			sed -E 's|(^overlays=.*)|\1 cpu-clock-1.2GHz-1.3v i2c0 pps-gpio uart2|' -i /boot/armbianEnv.txt

			echo "Setting 'console=serial'.."
			sed -E 's|(^console=)(.*)|\1serial|' -i /boot/armbianEnv.txt

			echo "Holding kernel packages.."
			apt-mark hold \
				armbian-firmware \
				linux-dtb-current-sunxi \
				linux-image-current-sunxi \
				linux-u-boot-orangepizero-current

			echo "Enabling services.."
			systemctl enable gpsd
			systemctl enable fbgpsclock
			systemctl enable ready-led
			systemctl set-default ready.target
			;;
		esac

		case $RELEASE in
#			bullseye)
				# wsdd isn't available as a pacakge for Bullseye, so install manually
				# prebuilt binaries don't seem to be available anymore
#				echo "Installing wsdd.."
#				wget -qO- <?> >/usr/bin/wsdd
#				chmod a+x /usr/bin/wsdd
#				useradd --system wsdd
#				wget -qO- https://github.com/christgau/wsdd/raw/master/etc/systemd/wsdd.defaults >/etc/default/wsdd
#				wget -qO- https://github.com/christgau/wsdd/raw/master/etc/systemd/wsdd.service >/etc/systemd/system/wsdd.service
#				;;&
			*)
				# adding .profile to root to source .bashrc and give coloured prompts
				echo "Installing root profile.."
				cp /tmp/overlay/root.profile /root/.profile
				;;
		esac
	} # Main

	Main "$@"
