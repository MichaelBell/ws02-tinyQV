from machine import Pin
import machine

BASE_ADDRESS=0x800_0420

def reg_write(address, data):
	machine.mem8[BASE_ADDRESS + (address&63)] = data

def reg_read(address):
	return machine.mem8[BASE_ADDRESS + (address&63)]

# Select the PWM peripheral (18) on out2
Pin(2, Pin.OUT, func_sel=18)

# Write a non-zero duty cycle to PWM1, which is connected to out2
# you should see a square wave on out2
reg_write(1, 100)
