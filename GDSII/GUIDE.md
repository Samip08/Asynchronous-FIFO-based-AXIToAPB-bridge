## To check GDS layout:
sudo apt install klayout
cd ~/Asynchronous-FIFO-based-AXIToAPB-bridge/GDSII/results/final/gds
klayout -e Top_module.gds

prevalant errors/warnings:
* sized down model from 16 slaves to 4 to prevent linux emergency termination(ram running out during synthesis)
* drivers giving max error WARNING,fanout pins giving warning 2/981 driven pins
* harmless noise warnings removing tapvpwrvgnd(substrate to VDD/GND to prevent latch-up), fill_1, fill_2 (physical continuity blocks used to fill empty gaps), decap12(ecoupling capacitors placed near your logic to act as local batteries)

## main warning(future fix):
* VSRC_LOC_FILES is not defined.This is an electrical power integrity warning. IR Drop happens across your chip's internal power lines due to the metal wires having a tiny bit of inherent resistance.
* OpenLane's OpenROAD power analysis tool needs to know exactly where the physical power pads are located on the outside edge of the chip , these have not been dedicated, worst case scenario with very fast switching might lead to brownout of the core
