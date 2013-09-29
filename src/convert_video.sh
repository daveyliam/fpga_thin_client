#!/bin/bash

[[ ! -e /tmp/out.avi ]] && mknod /tmp/out.avi p
mencoder "$1" -ovc raw -nosound -of rawvideo -vf format=bgr32,scale=1280:720 -o /tmp/out.avi &
pid=$!
sudo ./raw eth0 1280 720 32 < /tmp/out.avi
kill -9 ${pid}
