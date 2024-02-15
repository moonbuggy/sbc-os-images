#!/bin/sh
#
# Get battery and power data from AXP221
#
# AXP221 reference: https://linux-sunxi.org/AXP221
#

## bus and address of the AXP221
#
I2C_BUS="1"
AXP_ADDR="0x34"


## describe the NTC thermistor attached to the battery
#
BAT_TS_BETA=3950
BAT_TS_T0=298.15
BAT_TS_R0=10000


## i2cget wants to run as root, abort here if it can't
#
[ x"$(id -u)" != x"0" ] \
        && echo "Root privileges are required." && exit 1


## i2c-tools needs to be installed
#
if ! command -V i2cget >/dev/null 2>&1; then
        echo "i2c-tools needs to be installed."
        exit 1
fi


## number conversion
#
bin_to_dec() {
	echo "obase=A; ibase=2; ${1}" | bc
}

bin_to_hex() {
	echo "obase=16; ibase=2; x=${1}; if(x<2) print 0; x" | bc | tr '[:upper:]' '[:lower:]'
}

dec_to_bin() {
	echo "obase=2; ibase=A; ${1}" | bc
}

dec_to_hex() {
	echo "obase=16; ibase=A; x=${1}; if(x<2) print 0; x" | bc | tr '[:upper:]' '[:lower:]'
}

hex_to_bin() {
	hex="$(echo ${1#0x*} | tr '[:lower:]' '[:upper:]')"
	echo "obase=2; ibase=16; ${hex}" | bc | awk '{ printf "%08d\n", $0 }'
}


# get_bit <binary or hex string> <bit> [<bit>..]
get_bit() {
	bin_str="$1"

	echo $bin_str | grep -qoE '[^01]' \
		&& bin_str="$(hex_to_bin $bin_str)"
	bin_str="$(echo $bin_str | rev)"

	shift

	for bit in "$@"; do
		printf "$(expr substr $bin_str $((bit+1)) 1)"
	done
	echo
}


## force ADC enable for battery voltage and current
#
i2cset -y -f $I2C_BUS $AXP_ADDR 0x82 0xE3


# if given "set capacity <x>" as arguments, set the battery capacity
# (<x> is integer mAh)
#
if [ "${1}" = "set" ]; then
	case "${2}" in
		"capacity")
			bat_cap="${3}"
			bat_cap_bin="$(dec_to_bin "$(echo "${bat_cap}/1.456" | bc)" | awk '{ printf "%015d\n", $0 }')"

			echo "Setting battery capacity to: $bat_cap mAh.. (${bat_cap_bin})"

			bat_cap_msb="$(bin_to_hex "$(echo "${bat_cap_bin}" | cut -b1-8)")"
			bat_cap_lsb="$(bin_to_hex "$(echo "${bat_cap_bin}" | cut -b9-15)1")"

			i2cset -y -f $I2C_BUS $AXP_ADDR	0xe0 "0x${bat_cap_lsb}"
			i2cset -y -f $I2C_BUS $AXP_ADDR	0xe1 "0x${bat_cap_msb}"

			echo "Done.\n"
			;;
		*)	pass	;;
	esac
fi


## REG 00h: Power input status
#
POWER_STATUS=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x00)
echo "REG 00h: Power input status ($(hex_to_bin $POWER_STATUS))"
echo "---------------------------"

AC_STATUS="$(get_bit $POWER_STATUS 7)"
printf "AC Power: "
if [ x"$AC_STATUS" = x"0" ]; then
	echo "missing"
else
	printf "present, "
	AC_USABLE="$(get_bit $POWER_STATUS 6)"
	[ x"$AC_USABLE" = x"0" ] \
		&& echo "NOT usable" \
		|| echo "usable"
fi

BAT_DIRECTION="$(get_bit $POWER_STATUS 4)"
printf "Battery direction: "
[ x"$BAT_DIRECTION" = x"0" ] \
	&& echo "discharge" \
	|| echo "charge"


## REG 01h: Power operation mode and charge status
#
POWER_OP_MODE=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x01)
echo "\nREG 01h: Power operation mode and charge status ($(hex_to_bin $POWER_OP_MODE))"
echo "-----------------------------------------------"

BAT_EXIST="$(get_bit $POWER_OP_MODE 5)"
printf "Battery: "
[ x"$BAT_EXIST" = x"0" ] \
	&& echo "missing" \
	|| echo "exists"

CHARGE_IND="$(get_bit $POWER_OP_MODE 6)"
printf "Battery: "
[ x"$CHARGE_IND" = x"0" ] \
	&& echo "not charging" \
	|| echo "charging"

AXP_OVERHEAT="$(get_bit $POWER_OP_MODE 7)"
printf "AXP221 Overheat: "
[ x"$AXP_OVERHEAT" = x"0" ] \
	&& echo "false" \
	|| echo "true"


## REG 33h: Charge control 1
#
CHARGE_CTL=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x33)
echo "\nREG 33h: Charge control 1 ($(hex_to_bin $CHARGE_CTL))"
echo "-------------------------"

CHARGE_ENABLED="$(get_bit $CHARGE_CTL 7)"
printf "Charging: "
[ x"$CHARGE_ENABLED" = x"0" ] \
	&& echo "disabled" \
	|| echo "enabled"

CHARGE_TARGET="$(get_bit $CHARGE_CTL 6 5)"
case $CHARGE_TARGET in
	00)	charge_target_v="4.10"	;;
	01)	charge_target_v="4.15"	;;
	10)	charge_target_v="4.20"	;;
	11)	charge_target_v="4.35"	;;
esac
echo "Charge target: $charge_target_v V"

CHARGE_CURRENT="$(get_bit $CHARGE_CTL 3 2 1 0)"
echo "Charge current: $((300+$(bin_to_dec $CHARGE_CURRENT)*150)) mA"

CHARGE_END_CURRENT="$(get_bit $CHARGE_CTL 4)"
printf "Charge end current: "
[ x"$CHARGE_END_CURRENT" = x"0" ] \
	&& echo "10%" \
	|| echo "15%"


## REG 34h: Charge control 2
#
CHARGE_CTL2=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x34)
echo "\nREG 34h: Charge control 2 ($(hex_to_bin $CHARGE_CTL2))"
echo "-------------------------"


## REG 35h: Charge control 3
#
CHARGE_CTL3=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x35)
echo "\nREG 35h: Charge control 3 ($(hex_to_bin $CHARGE_CTL3))"
echo "-------------------------"

CHARGE_CURRENT_LIMIT="$(get_bit $CHARGE_CTL3 3 2 1 0)"
echo "Charge current limit: $((300+$(bin_to_dec $CHARGE_CURRENT_LIMIT)*150)) mA"


## REG 38h-3Dh Battery temperature thresholds
#
echo "\nREG 38h-3Dh Battery temperature thresholds"
echo "------------------------------------------"

get_temp_threshold_voltage() {
	echo "($(($1 << 4))*0.0008)" | bc | awk '{printf "%.4f", $0}'
}

CHARGE_V_HTF=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x38)
echo "Charge high temp threshold: $(get_temp_threshold_voltage $CHARGE_V_HTF) V"

CHARGE_V_LTF=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x39)
echo "Charge low temp threshold: $(get_temp_threshold_voltage $CHARGE_V_LTF) V"

DISCHARGE_V_HTF=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x3C)
echo "Discharge high temp threshold: $(get_temp_threshold_voltage $DISCHARGE_V_HTF) V"

DISCHARGE_V_LTF=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x3D)
echo "Discharge low temp threshold: $(get_temp_threshold_voltage $DISCHARGE_V_LTF) V"


## REG B8h: Fuel Gauge Control
#
FUEL_GAUGE=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0xB8)
echo "\nREG B8h: Fuel Gauge Control"
echo "---------------------------"

FUEL_GAUGE_ENABLED="$(get_bit $FUEL_GAUGE 7)"
printf "Fuel Gauge: "
[ x"$FUEL_GAUGE_ENABLED" = x"0" ] \
	&& echo "disabled" \
	|| echo "enabled"

COULOMB_COUNT_ENABLED="$(get_bit $FUEL_GAUGE 6)"
printf "Coulomb counter: "
[ x"$COULOMB_COUNT_ENABLED" = x"0" ] \
	&& echo "disabled" \
	|| echo "enabled"

BAT_CAP_ENABLE="$(get_bit $FUEL_GAUGE 5)"
printf "Battery calibration: "
[ x"$BAT_CAP_ENABLE" = x"0" ] \
	&& echo "disabled" \
	|| echo "enabled"

BAT_CAP_STATUS="$(get_bit $FUEL_GAUGE 4)"
printf "Battery calibration: "
[ x"$BAT_CAP_STATUS" = x"0" ] \
	&& echo "not running" \
	|| echo "in progress"


## REG B9h: Battery Charge Reading
#
BATTERY_CHARGE=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0xB9)
echo "\nREG B9h: Battery Charge Reading"
echo "-------------------------------"

BATTERY_CHARGE_CALCULATED="$(get_bit $BATTERY_CHARGE 7)"
printf "Battery charge: "
[ x"$BATTERY_CHARGE_CALCULATED" = x"0" ] \
	&& echo "NOT correctly calculated" \
	|| echo "correctly calculated"

BATTERY_CHARGE_PERCENT="$(get_bit $BATTERY_CHARGE 6 5 4 3 2 1 0)"
echo "Battery charge: $(bin_to_dec $BATTERY_CHARGE_PERCENT) %"


## REG E0h-E1h: Battery Capacity Setting 1
#
echo "\nREG E0h-E1h: Battery Capacity Setting 1"
echo "---------------------------------------"
BATTERY_CAPACITY_LSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0xe0)
BATTERY_CAPACITY_MSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0xe1)

BATTERY_CAP_SET="$(get_bit $BATTERY_CAPACITY1 7)"
printf "Battery capacity: "
[ x"$BATTERY_CAP_SET" = x"0" ] \
	&& echo "unset" \
	|| echo "set"

BATTERY_CAP_BIT="$(hex_to_bin $BATTERY_CAPACITY_MSB)$(get_bit $BATTERY_CAPACITY_LSB 7 6 5 4 3 2 1)"
printf "Battery capacity: %.0f mAh\n" "$(echo "scale=0;$(bin_to_dec $BATTERY_CAP_BIT)*1.456" | bc)"


## REG E6h: Battery Low Warning Threshold Setting 1
#
BATTERY_LOW_THRESHOLD=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0xe6)
echo "\nREG E6h: Battery Low Warning Threshold Setting 1"
echo "------------------------------------------------"

BATTERY_LOW_WARNING="$(get_bit $BATTERY_LOW_THRESHOLD 7 6 5 4)"
echo "Warning Threshold: $(echo "$(bin_to_dec $BATTERY_LOW_WARNING)+5" | bc) %"

BATTERY_LOW_OFF="$(get_bit $BATTERY_LOW_THRESHOLD 3 2 1 0)"
echo "Off Threshold: $(echo "$(bin_to_dec $BATTERY_LOW_OFF)" | bc) %"


## ADC data
#
echo "\nADC Data"
echo "--------"


## read battery voltage    79h, 78h    0 mV -> 000h,    1.1 mV/bit    FFFh -> 4.5045 V
#
BAT_VOLT_LSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x79)
BAT_VOLT_MSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x78)

BAT_BIN=$(( $(($BAT_VOLT_MSB << 4)) | $(($(($BAT_VOLT_LSB & 0xF0)) >> 4)) ))

BAT_VOLT=$(echo "scale=4; ($BAT_BIN*1.1/1000)" | bc)
echo "Battery voltage: $BAT_VOLT V"


## read Battery Discharge Current    7Ah, 7Bh    0 mV -> 000h,    0.5 mA/bit    FFFh -> 4.095 V
#
BAT_IDISCHG_LSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x7B)
BAT_IDISCHG_MSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x7A)

BAT_IDISCHG_BIN=$(( $(($BAT_IDISCHG_MSB << 4)) | $(($(($BAT_IDISCHG_LSB & 0xF0)) >> 4)) ))

BAT_IDISCHG=$(echo "($BAT_IDISCHG_BIN*0.5)" | bc)
echo "Battery discharge current: $BAT_IDISCHG mA"


## read Battery Charge Current    7Ch, 7Dh    0 mV -> 000h,    0.5 mA/bit    FFFh -> 4.095 V
#
BAT_ICHG_LSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x7D)
BAT_ICHG_MSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x7C)

BAT_ICHG_BIN=$(( $(($BAT_ICHG_MSB << 4)) | $(($(($BAT_ICHG_LSB & 0xF0)) >> 4)) ))

BAT_ICHG=$(echo "($BAT_ICHG_BIN*0.5)" | bc)
echo "Battery charge current: $BAT_ICHG mA"


## read Battery TS voltage    58h, 59h    0 mV -> 000h,    0.8 mV/bit    FFFh -> 3.276 V
#
BAT_TS_LSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x59)
BAT_TS_MSB=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x58)

BAT_TS_BIN=$(( $(($BAT_TS_MSB << 4)) | $(($(($BAT_TS_LSB & 0xF0)) >> 4)) ))

BAT_TS_V=$(echo "scale=4; x=$BAT_TS_BIN*0.8/1000; if(x<1) print 0; x" | bc)
echo "Battery TS voltage: $BAT_TS_V V"


## read Battery TS current, set at 0x84h (default: 80uA)
#
BAT_TS_PIN_CTRL=$(i2cget -y -f $I2C_BUS $AXP_ADDR 0x84)

BAT_TS_OUTPUT_BIN="$(get_bit $BAT_TS_PIN_CTRL 5 4)"
BAT_TS_OUTPUT_C="$((20+20*$(bin_to_dec $BAT_TS_OUTPUT_BIN)))"
BAT_TS_C=$(echo "scale=6; ($BAT_TS_OUTPUT_C/1000000)" | bc)
echo "TS output current: $BAT_TS_OUTPUT_C \302\265A"


## calculate Battery Temperature
#
BAT_TS_R=$(echo "($BAT_TS_V/$BAT_TS_C)" | bc)
# echo "Battery TS resistance = $BAT_TS_R ohm"

BAT_TS_Rinf=$(echo "$BAT_TS_R0*e(-$BAT_TS_BETA/$BAT_TS_T0)" | bc -l)
# echo "Battery TS Rinf: $BAT_TS_Rinf"

BAT_TS_TEMP=$(echo "$BAT_TS_BETA/l($BAT_TS_R/$BAT_TS_Rinf)" | bc -l)
# echo "Battery TS Temp: $BAT_TS_TEMP"

BAT_TS_TEMP_C=$(echo "scale=2; $BAT_TS_TEMP-273.15" | bc)
printf "Battery temperature: %.2f \302\260C\n" $BAT_TS_TEMP_C
