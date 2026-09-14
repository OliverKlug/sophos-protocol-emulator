# Icarus self-check (cocotb optional later)
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v protoemu_core.v sm.v fifo4.v clkdiv.v sram_flop.v

.PHONY: uart
uart:
	iverilog -g2012 -o tb_uart.vvp $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES)) tb_uart.v
	vvp tb_uart.vvp
