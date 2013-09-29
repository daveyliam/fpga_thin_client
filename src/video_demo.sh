#!/bin/bash

sudo ifconfig eth0 0.0.0.0 up
./bandwidth &
pid=$?
sudo ./raw eth0 1280 720 16 < /mnt/laptop_hdd/matrix.rgb16
kill ${pid}
