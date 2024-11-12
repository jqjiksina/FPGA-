@echo off
set bin_path=Y:/SoftWare/Modelsim/win64
cd E:/DELL/Desktop/FPGA/FPGA_DevelopKnit/MES50HP_v3/2_Demo/11_ethernet_test/sim/behav
call "%bin_path%/modelsim"   -do "do {run_behav_compile.tcl};do {run_behav_simulate.tcl}" -l run_behav_simulate.log
if "%errorlevel%"=="1" goto END
if "%errorlevel%"=="0" goto SUCCESS
:END
exit 1
:SUCCESS
exit 0
