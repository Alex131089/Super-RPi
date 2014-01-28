WII_WAIT_OTHER=0

# If not SSH connection (in this case, the screen)
[ -n "${SSH_CONNECTION}" ] || (
  # Start Wii remote connect polling (as root)
  sudo bash /home/pi/WiimoteConnect.sh &

  # Wait the first remote at least, 
  # because it's needed to control emulationstation
  while [ ! -e /dev/input/js0 ]; do sleep 1; done

  # Then the others if wanted
  if [ $WII_WAIT_OTHER -ne 0 ]; then
    echo -n "Waiting for other remotes ...";
    for i in {10..1}; do
      sleep 1
      echo -n " $i"
    done
  fi

  # Go !
  echo
)

