; Final full-bed measurement with the user-accepted offset -0.68.
; Clear the bed. Mechanical Z endstop must stay connected. Observe probing.
; This file heats and moves the printer, but DOES NOT save EEPROM.
; After a successful complete 3x3 grid, review M420 V and then send M500 manually.
; On the old firmware, do not issue M501 with leveling enabled; verify by restarting instead.
G21
G90
M82
M211 S1
M84 S0
M851 X-44.1 Y-3.3 Z-0.68
M221 S100
M140 S50
M104 S150
M190 S50
G4 S300 ; Allow five minutes for the bed to stabilize
M104 S200
M109 S200
G92 E0
G1 E-3 F1800 ; Reduce oozing during probing
M402
G28
M420 S0
G1 Z5 F120
G29 S1200 ; Full reachable bed, using compiled boundaries; no local L/R/F/B
G90
G1 Z10 F120
M420 S0 ; Finish with leveling disabled before any later settings load
M420 V
M851
M503
M104 S0
M140 S0
G92 E0
M84 S120
