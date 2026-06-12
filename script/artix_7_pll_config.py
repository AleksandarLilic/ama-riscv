#!/usr/bin/env python3

import sys

clkin1_mhz = 100 # mhz, default

if len(sys.argv) == 2:
    clkin1_mhz = int(sys.argv[1])
print(f"Using {clkin1_mhz}MHz oscillator input for config checks")

clkin1 = (clkin1_mhz * 1_000_000) # hz
clkin1_period = (1/clkin1) * 1_000_000_000 # to ns
# freq_out = clkin1 * (clkfbout_mult / (divclk_divide * clkout0_divide))

pll_vco_range = range(800, 1600) # MHz
mmcm_vco_range = range(600, 1200) # MHz

vco_range = pll_vco_range

# ranges: https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/PLLE2_ADV
clkfbout_mult_range = range(2, 64)
clk_dout0_divide_range = range(1, 128)
divclk_divide_range = range(1, 56)
divclk_divide_range = range(1, 2) # fixed: 1

BEST = True
RANGE = 1 # hz above/below SEARCH
t_mhz_list = (50, 55, 60, 65, 70, 75, 80, 90, 100)

gp = lambda freq_mhz: 1_000_000_000/freq_mhz
for t_mhz in t_mhz_list:
    T_HZ = t_mhz * 1_000_000 # hz
    PERIOD = 1_000_000_000 / T_HZ # ns
    print(f"\nSearching for frequencies around {T_HZ/1_000_000} MHz, "
        f"period={PERIOD:.3f} ns, half period={PERIOD/2:.3f} ns")

    str_list = []
    str_best = ""
    vco_best = 0
    diff_best = 1_000_000
    for divclk_divide in divclk_divide_range:
        for clkfbout_mult in clkfbout_mult_range:
            for clkout0_divide in clk_dout0_divide_range:
                str_app = ""
                freq = clkin1 * (clkfbout_mult/(divclk_divide*clkout0_divide))
                freq_in_range = (T_HZ-RANGE <= freq <= T_HZ+RANGE)
                vco = int(clkin1_mhz * clkfbout_mult / divclk_divide)
                vco_in_range = (vco in vco_range)
                if freq_in_range and vco_in_range:
                    if RANGE:
                        str_app = \
                            f"(f={freq/1_000_000:.3f} MHz, p={gp(freq):.3f} ns)"
                    str_list.append("    "
                        f"CLKFBOUT_MULT = {clkfbout_mult}, "
                        f"CLKOUT0_DIVIDE = {clkout0_divide}, "
                        f"DIVCLK_DIVIDE = {divclk_divide}, "
                        f"VCO: {vco}MHz; " +
                        str_app
                    )
                    diff = abs(T_HZ - freq)
                    if vco > vco_best and diff <= diff_best:
                        vco_best = vco
                        diff_best = diff
                        str_best = str_list[-1]

    if BEST:
        print(str_best)
    else:
        for s in str_list:
            print(s)
