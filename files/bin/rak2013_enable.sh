#!/bin/sh -e
gpioset gpiochip0 5=0
gpioset gpiochip0 6=0
gpioset gpiochip0 18=1
sleep 1
gpioset gpiochip0 18=0
sleep 30
