#	WiimoteConnect.sh
#

MACFILE="WiimoteList.txt"
HCIDEV="hci0"


# Connection function
connect() {
  #Check mac
  if [[ "$1" =~ ([0-9A-F]{2}:){5}[0-9A-F]{2} ]]; then
    mac=$1
  else
    return 1
  fi
  echo "`date +'%T'` Connecting to $mac"
  
  # Already connected ? Don't reassociate it broke connection
  if [ `hidd --list | grep -c "$mac"` -ge 1 ]; then
    echo "Already connected"
    return 0
  else
    # No ? Then try to connect & set leds
    hidd --connect "$mac"
    if [ $? -eq 0 ]; then
      echo "Connected"
      sleep 0.5
      set_leds "$mac"
    else
      echo "Failed"
    fi
    
  fi
}

# Set leds function .. not easy
set_leds() {
  # pi@raspberrypi /sys/class/input $ ls -la js*
  # lrwxrwxrwx 1 root root 0 Jan 19 01:16 js0 -> ../../devices/platform/bcm2708_usb/usb1/1-1/1-1.3/1-1.3:1.0/bluetooth/hci0/hci0:71/0005:057E:0306.001B/input/input124/js0
  # pi@raspberrypi /sys/class/input $ ls js*/device/device/leds/*/brightness
  # js0/device/device/leds/0005:057E:0306.001B:blue:p0/brightness  js2/device/device/leds/0005:057E:0306.001A:blue:p0/brightness
  # https://github.com/raspberrypi/linux/blob/rpi-3.11.y/drivers/hid/hid-wiimote.h
  # https://github.com/raspberrypi/linux/blob/rpi-3.6.y/drivers/hid/hid-wiimote.h
  # readlink -e
  # realpath -e
  
  # From hid-wiimote.h
  WIIMOTE_STR="Nintendo Wii Remote"

  #Check mac
  if [[ "$1" =~ ([0-9A-F]{2}:){5}[0-9A-F]{2} ]]; then
    mac=$1
  else
    return 1
  fi
  echo "`date +'%T'` Setting LEDS for $mac"

  # Search BT Device
  subhci=-1
  for dev in /sys/class/bluetooth/$HCIDEV\:*; do
    if [ `grep -c "$mac" $dev/address` -eq 1 ]; then
      subhci=$(echo $dev | sed -r 's/.*:([0-9]+)$/\1/')
      break;
    fi
  done
  echo "SubHCI : $subhci"
  # BT Device found ?
  if [ $subhci -ge 0 ]; then
    count=-1
    # For each input (must be in numerical order of js*)
    for i in /sys/class/input/js*; do
      # If Nintendo remote, count it
      if [ "`cat $i/device/name`" = "$WIIMOTE_STR" ]; then
        count=$((count+1))
        echo -n "$i : Wiimote found (#$((count+1)))"
        # If mine, set position & quit
        if [[ "`readlink -e $i`" =~ "$HCIDEV:$subhci" ]]; then
          echo " .. setting leds"
          for led in $i/device/device/leds/*p*; do
            echo 0 > $led/brightness
          done
          echo 1 > $i/device/device/leds/*p$count/brightness
          return 0;
        fi
        echo
      fi
    done
    echo "No input device or not for this hci"
    return 3 # No input or mine not found
  else
    echo "Not found"
    return 2
  fi
}

# Main
#######
# No args
if [ $# -lt 1 ]; then
  # If know mac, associate them (using "threads")
  if [ -e "$MACFILE" ]; then
    for mac in `cat "$MACFILE" | grep -v '^\s*#'`; do
      bash $0 "$mac" &
    done
  # Else scan all HID
  else
    while(true); do
      echo "`date +'%T'` Scanning ..."
      for mac in `hidd --search | grep -oE "([0-9A-F]{2}:){5}[0-9A-F]{2}"`; do
        echo "`date +'%T'` Connected to $mac"
        set_leds $mac
        sleep 0.5
      done
      sleep 30 # Long sleep because it will scan everything
    done
  fi
# We know which mac to connect, we try indefinitely
else
  while(true); do
    connect $1
    sleep 5 # Short sleep, only used to reconnect if lost (no scan)
  done;
fi
