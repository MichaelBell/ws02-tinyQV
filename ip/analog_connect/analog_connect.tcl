box 0 0 44.32u 1u
paint metal2
box 0 0 44.32u 0.28u
label asig center metal2
port make
port class inout
port use signal
box 0 0.28u 44.32u 1u
paint via2
paint metal3
label pad center metal3
port make
port class inout
port use signal
box 0 0 44.32u 1u
property FIXED_BBOX 0 0 44.32u 1u
save analog_connect.mag
gds write analog_connect.gds
lef write analog_connect.lef -pinonly -hide
quit -noprompt
