set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { CLK_BOARD }]; #IO_L12P_T1_MRCC_14 Sch=gclk
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { CLK_BOARD }];

## LEDs
set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports { LEDS[0] }]; #IO_L12N_T1_MRCC_16 Sch=led[1]
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { LEDS[1] }]; #IO_L13P_T2_MRCC_16 Sch=led[2]

## RGB LED0
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { LEDS[2] }]; #IO_L14P_T2_SRCC_16 Sch=led0_r
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { LEDS[3] }]; #IO_L13N_T2_MRCC_16 Sch=led0_g

## Buttons
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { RST_BOARD }]; #IO_L19N_T3_VREF_16 Sch=btn[0]

## USB-UART Interface
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_TX }]; #IO_L7N_T1_D10_14 Sch=uart_rxd_out
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_RX }]; #IO_L7P_T1_D09_14 Sch=uart_txd_in

## Async I/O false paths
set_false_path -from [get_ports { RST_BOARD }]
set_false_path -to   [get_ports { LEDS[*] }]
set_false_path -to   [get_ports { FPGA_SERIAL_TX }]
set_false_path -from [get_ports { FPGA_SERIAL_RX }]
