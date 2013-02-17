#!/bin/sh

xset s off
xset -dpms

if [ -f "$HOME/.monitors" ] && [ ! -f "$HOME/.calibration_data" ]; then
  echo "Assuming incorrect monitor selection."
  rm -f "$HOME/.monitors"
fi

if [ ! -f "$HOME/.monitors" ]; then
  rm -f /tmp/monitors.conf

  xrandr | grep ' connected' | sed 's,\([^ ]*\) connected \([0-9]*\)x\([0-9]*\).*$,monitor="\1" width=\2 height=\3,' | while read line; do
    echo "-> $line"
    eval "$line"
    if [ -f /tmp/monitors.conf ]; then
      . /tmp/monitors.conf
      if [ "$width" -ne "$WIDTH" -o "$height" -ne "$HEIGHT" ]; then
        exec xterm -e 'echo Incompatible resolutions.; xrandr; read line'
      fi

      echo "SECONDARY_MONITOR=$monitor" >> /tmp/monitors.conf
    else
      echo "PRIMARY_MONITOR=$monitor" > /tmp/monitors.conf
      echo "WIDTH=$width" >> /tmp/monitors.conf
      echo "HEIGHT=$height" >> /tmp/monitors.conf
    fi
  done

  . /tmp/monitors.conf
  if [ ! -z "$SECONDARY_MONITOR" ]; then
    xrandr --output $PRIMARY_MONITOR --mode ${WIDTH}x${HEIGHT} --pos 0x0 --output $SECONDARY_MONITOR --mode ${WIDTH}x${HEIGHT} --pos ${WIDTH}x0

                       cat > ui_helper.sh <<EOF
echo "On which monitor is this window displayed?"
echo "Enter 'top' or 'bottom'."
read line
echo "\$line" > /tmp/detect

app_yml="/home/terminal/www/smartkiosk-mkb/shared/config/application.yml"
dkeyword=\$(grep ^keyword "\$app_yml" | cut -d"'" -f 2)
dhost=\$(grep ^host "\$app_yml" | cut -d" " -f 2 | sed 's,http://,,')

echo -n "Please enter keyword for this kiosk ["\$dkeyword"]: "
read keyword
echo -n "Please enter server address ["\$dhost"]: "
read host
[ -z "\$keyword" ] || sed --in-place "s,^keyword: .*,keyword: '\$keyword'," "\$app_yml"
[ -z "\$host" ] || sed --in-place "s,^host: .*,host: http://\$host," "\$app_yml"
EOF

    while [ ! -f "$HOME/.monitors" ]; do
      rm -f /tmp/detect
      xterm -e 'sh ui_helper.sh'
      /usr/bin/smartguardctl restart
      if [ -f /tmp/detect ]; then
        echo "Detect:"
        cat /tmp/detect
        echo "---"

        read monitor < /tmp/detect
        echo "Window on $monitor monitor."
        case "$monitor" in
        top)
          echo "PRIMARY_MONITOR=$SECONDARY_MONITOR" > /tmp/monitors.conf
          echo "WIDTH=$WIDTH" >> /tmp/monitors.conf
          echo "HEIGHT=$HEIGHT" >> /tmp/monitors.conf
          echo "SECONDARY_MONITOR=$PRIMARY_MONITOR" >> /tmp/monitors.conf
          . /tmp/monitors.conf
          mv /tmp/monitors.conf "$HOME/.monitors"
          ;;

        bottom)
                      mv /tmp/monitors.conf "$HOME/.monitors"
          ;;
        esac
      fi
    done

    rm -f /tmp/detect

  else
    mv /tmp/monitors.conf "$HOME/.monitors"
    cat > ui_helper.sh <<EOF
app_yml="/home/terminal/www/smartkiosk-mkb/shared/config/application.yml"
dkeyword=$(grep ^keyword "\$app_yml" | cut -d"'" -f 2)
dhost=$(grep ^host "\$app_yml" | cut -d" " -f 2 | sed 's,http://,,')

echo -n "Please enter keyword for this kiosk ["\$dkeyword"]: "
read keyword
echo -n "Please enter server address ["\$dhost"]: "
read host
[ -z "\$keyword" ] || sed --in-place "s,^keyword: .*,keyword: '\$keyword'," "\$app_yml"
[ -z "\$host" ] || sed --in-place "s,^host: .*,host: http://\$host," "\$app_yml"
EOF
    xterm -e 'sh ui_helper.sh'
    /usr/bin/smartguardctl restart
  fi
else
  . "$HOME/.monitors"
fi

if [ ! -z "$SECONDARY_MONITOR" ]; then
  xrandr --output $PRIMARY_MONITOR --mode ${WIDTH}x${HEIGHT} --pos 0x0 --output $SECONDARY_MONITOR --mode ${WIDTH}x${HEIGHT} --pos ${WIDTH}x0
fi

xinput --map-to-output "$(xinput_calibrator --list | sed 's,.* id=\([0-9]*\)$,\1,' | head -n 1)" "$PRIMARY_MONITOR"

while [ ! -f "$HOME/.calibration_data" ]; do
  rm -f /tmp/calibration.log
  xinput_calibrator | tee /tmp/calibration.log
  if grep -q "Making the calibration permanent" /tmp/calibration.log; then
    grep '^ *xinput' /tmp/calibration.log > "$HOME/.calibration_data"
  fi
done

rm -f /tmp/calibration.log

. "$HOME/.calibration_data"

exec firefox -app "$HOME/kioskui/application.ini"
