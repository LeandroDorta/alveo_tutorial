.PHONY: help

help::
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw> DEVICE=<FPGA platform> KERNEL=<kernel name>"
	$(ECHO) "      Command to generate the design for specified Target and Device."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""
	$(ECHO) "  make check TARGET=<sw_emu/hw_emu/hw> DEVICE=<FPGA platform> KERNEL=<kernel name>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""

TARGET  := hw
TARGETS := $(TARGET)
DEVICE  := xilinx_u250_xdma_201830_2
DEVICES := $(DEVICE)
KERNEL  := vadd
KERNELS := $(KERNEL)
HOST_EXE:= host
HOST_FILE:= ./src/host/host.cpp

XO      := ./xclbin/$(KERNELS).$(TARGETS).$(DEVICES).xo
XCLBIN  := ./xclbin/$(KERNELS).$(TARGETS).$(DEVICES).xclbin
XCLBIN_FILE := $(KERNELS).$(TARGETS).$(DEVICES).xclbin
SRC_DIRS:= ./src
BINARY_DIR := ./xclbin

#compiler tools
XILINX_VITIS := /opt/xilinx/Xilinx_Vivado_vitis_2019.2/Vitis/2019.2
XILINX_VIVADO:= /opt/xilinx/Xilinx_Vivado_vitis_2019.2/Vivado/2019.2
XILINX_XRT   := /opt/xilinx/xrt

VIVADO  := $(XILINX_VIVADO)/bin/vivado
CXX     := g++
VPP     := $(XILINX_VITIS)/bin/v++
EMCONFIGUTIL := $(XILINX_VITIS)/bin/emconfigutil --od .
EMCONFIG_FILE = emconfig.json
EMCONFIG_DIR = ./xclbin/

RM = rm -f
RMDIR = rm -rf
ECHO = @echo

###################################################################
# XCPP COMPILER FLAGS
######################################################################
opencl_CXXFLAGS += -g -I./ -I$(XILINX_XRT)/include -I$(XILINX_VIVADO)/include -Wall -O0 -g -std=c++11
# The below are linking flags for C++ Comnpiler
opencl_LDFLAGS += -L$(XILINX_XRT)/lib -lOpenCL -lpthread

CXXFLAGS += $(opencl_CXXFLAGS)
LDFLAGS += $(opencl_LDFLAGS)

ifneq ($(TARGETS),sw_emu)
	CXXFLAGS += -fmessage-length=0
endif

BINARY_CONTAINERS += $(XCLBIN)
BINARY_CONTAINER_1_OBJS += $(XO)

# Kernel compiler and linker global settings
KRNL_COMPILE_OPTS := -t $(TARGETS) --config ../run/design.cfg
KRNL_LINK_OPTS    := -t $(TARGETS) --config design.cfg

#
# host files
#
#HOST_SRCS := $(shell find $(SRC_DIRS) -name *.cpp -or -name *.c -or -name *.s)
#HOST_OBJS := $(addsuffix .o,$(basename $(HOST_SRCS)))
#HOST_DEPS := $(HOST_OBJS:.o=.d)

.PHONY: all clean cleanall
all: $(HOST_EXE) $(BINARY_CONTAINERS) $(EMCONFIG_FILE)

.NOTPARALLEL: clean

clean-host:
	-$(RM) $(HOST_EXE) $(HOST_OBJS) $(HOST_DEPS)

clean-accelerators:
	-$(RM) $(BINARY_CONTAINERS) $(ALL_KERNEL_OBJS) $(ALL_MESSAGE_FILES)  $(EMCONFIG_FILE)
	-$(RM) *.xclbin.sh *.xclbin.info *.xclbin.link_summary*
	-$(RM) *.log *.ini
	-$(RMDIR) .Xil ./xclbin _x

clean-temp:
	$(RMDIR) ./

clean: clean-host clean-accelerators

cleanall: clean
	-$(RMDIR) tmp_* packaged_* vivado.* $(XCLBIN)/{*sw_emu*,*hw_emu*}

$(HOST_EXE): ./src/host/host.cpp
	$(CXX) $(CXXFLAGS) -o '$@' '$<' $(LDFLAGS)

$(XO): ./src/xml/kernel.xml ./scripts/package_kernel.tcl ./scripts/gen_xo.tcl
	mkdir -p ./xclbin
	$(VIVADO) -mode batch -source scripts/gen_xo.tcl -tclargs $(XO) $(KERNEL) $(TARGETS) $(DEVICES)

$(BINARY_CONTAINERS): $(BINARY_CONTAINER_1_OBJS)
	mkdir -p $(BINARY_DIR)/logs
	mkdir -p $(BINARY_DIR)/reports
	$(VPP) -t $(TARGETS) --platform $(DEVICES) --save-temps --temp_dir=$(BINARY_DIR) --report_dir=$(BINARY_DIR)/reports --log_dir=$(BINARY_DIR)/logs -lo $(XCLBIN) $(XO)

$(EMCONFIG_FILE):
	emconfigutil --platform $(DEVICES)

$(XCL):
	unset XCL_EMULATION_MODE

check: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	XCL_EMULATION_MODE=$(TARGET) ./$(HOST_EXE) $(XCLBIN) $(DEVICES)
else
	$(XCL) ./$(HOST_EXE) $(XCLBIN) $(DEVICES)
endif
