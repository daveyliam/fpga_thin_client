#!/bin/bash

sudo ifconfig eth0 0.0.0.0 up
sudo ./qemu-kvm-0.14.1/x86_64-softmmu/qemu-system-x86_64 -m 2048 -vga vmware -localtime -cdrom /mnt/laptop_hdd/ubuntu-11.04-desktop-amd64.iso -boot d
