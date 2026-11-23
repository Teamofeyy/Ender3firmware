; Paste into Cura Machine Settings > Start G-code.
; Cura handles temperatures from the selected material profile.
; Requires a saved full-bed mesh measured with the accepted M851 offset.
G90
M82
M211 S1
G92 E0
M402
G28
M420 S1
G1 Z2.0 F3000
G1 X0.1 Y20 Z0.3 F5000.0
G1 X0.1 Y200.0 Z0.3 F1500.0 E15
G1 X0.4 Y200.0 Z0.3 F5000.0
G1 X0.4 Y20 Z0.3 F1500.0 E30
G92 E0
G1 Z2.0 F3000
G1 X5 Y20 Z0.3 F5000.0
