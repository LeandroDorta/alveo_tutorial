<table>
  <tr>
    <td align="center"><h1>Getting started with RTL Kernels on Alveo Card</h1>
    </td>
  </tr>
</table>

> **IMPORTANT**
>* The content of this tutorial has been extracted from XILINX documentation. 
>* This tutorial is meant to be a recompilation of XILINX documentation about how to build hardware 
>* accelerated applications running on Alveo Data Center accelerator card.

# 1. Introduction
An accelerated application consists of a software program running on an x86 server, and the accelerated kernels running on an Alveo Data Center accelerator card or Xilinx FPGA. The sources for both need to be built (compiled and linked) separately.

This tutorial describes how to build both the software and hardware portions of your design using the `g++` compiler and Vitis compiler. It describes various command line options, including how to specify a target platform, and building for hardware or hardware emulation.

# 2. Tutorial Overview
The contents of this tutorial are structured in the following way:

1. Build the software portion of the design (host program) which will be run on the x86 processor and where the hardware kernel will be called as a function.
2. Create a kernel description XML file.
3. Package the RTL kernel into a Xilinx Object (XO) file.
4. Hardware linking using `v++` command `-l` option to create output binary container (XCLBIN) file.
5. Program RTL kernel onto the FPGA and run in in Hardware or Hardware-Emulation.

# 3. Requirements for Using an RTL Design as an RTL Kernel
To use an RTL kernel within the Vitis IDE, it must meet both the Vitis core development kit execution model and the hardware interface requirements.

## Kernel Execution Model

RTL kernels use the same software interface and execution model as C/C++ kernels. They are seen by the host application as functions with a void return value, scalar arguments, and pointer arguments. For instance:

```C
void vadd_A_B(int *a, int *b, int scalar)
```

This implies that an RTL kernel has an execution model like a software function:

- It must start when called.
- It is responsible for processing the necessary results.
- It must send a notification when processing is complete.

The Vitis core development kit execution model specifically relies on the following mechanics and assumptions:

- Scalar arguments are passed to the kernel through an AXI4-Lite slave interface.
- Pointer arguments are transferred through global memory (DDR, HBM, or PLRAM).
- Base addresses of pointer arguments are passed to the kernel through its AXI4-Lite slave interface.
- Kernels access pointer arguments in global memory through one or more AXI4 master interfaces.
- Kernels are started by the host application through its AXI4-Lite interface.
- Kernels must notify the host application when they complete the operation through its AXI4-Lite interface or a special interrupt signal.

## Hardware Interface Requirements

To comply with this execution model, the Vitis core development kit requires that a kernel satisfies the following specific hardware interface requirements:

- One and only one AXI4-Lite slave interface used to access programmable registers (control registers, scalar arguments, and pointer base addresses).
  - Offset `0x00` - Control Register: Controls and provides kernel status
    - Bit `0`: **start signal**: Asserted by the host application when kernel can start processing data. Must be cleared when the **done** signal is asserted.
    - Bit `1`: **done signal**: Asserted by the kernel when it has completed operation. Cleared on read.
    - Bit `2`: **idle signal**: Asserted by this signal when it is not processing any data. The transition from Low to High should occur synchronously with the assertion of the **done** signal.
  - Offset `0x04`- Global Interrupt Enable Register: Used to enable interrupt to the host.
  - Offset `0x08`- IP Interrupt Enable Register: Used to control which IP generated signal is used to generate an interrupt.
  - Offset `0x0C`- IP Interrupt Status Register: Provides interrupt status
  - Offset `0x10` and above - Kernel Argument Register(s): Register for scalar parameters and base addresses for pointers.

- One or more of the following interfaces:
  - AXI4 master interface to communicate with global memory.
    - All AXI4 master interfaces must have 64-bit addresses.
    - The kernel developer is responsible for partitioning global memory spaces. Each partition in the global memory becomes a kernel argument. The base address (memory offset) for each partition must be set by a control register programmable through the AXI4-Lite slave interface.
    - AXI4 masters must not use Wrap or Fixed burst types, and they must not use narrow (sub-size) bursts. This means that AxSIZE should match the width of the AXI data bus.
    - Any user logic or RTL code that does not conform to the requirements above must be wrapped or bridged.
  - AXI4-Stream interface to communicate with other kernels.

If the original RTL design uses a different execution model or hardware interface, you must add logic to ensure that the design behaves in the expected manner and complies with interface requirements.

## Vector-Accumulate RTL IP

For this tutorial, the Vector-Accumulate RTL IP performing `B[i]=A[i]+B[i]` meets all the requirements described above and has the following characteristics:

- Two AXI4 memory mapped interfaces:
  - One interface is used to read A
  - One interface is used to read and write B
  - The AXI4 masters used in this design do not use wrap, fixed, or narrow burst types.
- An AXI4-Lite slave control interface:
  - Control register at offset `0x00`
  - Kernel argument register at offset `0x10` allowing the host to pass a scalar value to the kernel
  - Kernel argument register at offset `0x18` allowing the host to pass the base address of A in global memory to the kernel
  - Kernel argument register at offset `0x24` allowing the host to pass the base address of B in global memory to the kernel

## Accessing the Tutorial Reference Files
>**IMPORTANT:** Before running the example commands, ensure you have set up the Vitis core development kit by running the following commands:
>
>   ```bash
>    #setup Xilinx Vitis tools. XILINX_VITIS and XILINX_VIVADO will be set in this step.
>    module load vitis
>    #Setup Xilinx runtime. XILINX_XRT will be set in this step.
>    source /opt/xilinx/xrt/setup.sh
>   ```

To access the reference files for this tutoral, type the following into a terminal:

` % mkdir $HOME/tutorial`
` % cd $HOME/tutorial`
` % git clone https://github.com/LeandroDorta/alveo_tutorial`
` % cd alveo_tutorial`
` % TOPDIR=$PWD`

The alveo_tutorial directory is structured in the following way:
```
alveo_tutorial
|___ [Makefile]()
|___ [run_rtl_kernel.sh]()
|___ scripts
|    |___ [gen_xo.tcl]()
|    |___ [package_kernel.tcl]()
|___ src
     |___ host]
     |    |___ [host.cpp]()
     |___ IP
     |    |___ [A_axi_read_master.sv]()
     |    |___ [B_axi_read_master.sv]()
     |    |___ [Vadd_A_B_control_s_axi.v]()
     |    |___ [Vadd_A_B_example_adder.v]()
     |    |___ [Vadd_A_B_example_axi_write_master.sv]()
     |    |___ [Vadd_A_B_example_counter.sv]()
     |    |___ [Vadd_A_B_example.sv]()
     |    |___ [Vadd_A_B_example_vadd.sv]()
     |    |___ [Vadd_A_B.v]()
     |    |___ [Vadd_B.sv]()
     |___ xml
          |___ [kernel.xml]()
``` 


# 4. Host program (Building the Software)
The software program is written in C/C++ and uses OpenCL™ API calls to communicate and control the accelerated kernels. It is built using the standard GCC compiler or using the `g++` compiler, which is a wrapper around GCC.  Each source file is compiled to an object file (.o) and linked with the Xilinx runtime (XRT) shared library to create the executable. For details on GCC and associated command line options, refer to [Using the GNU Compiler Collection (GCC)](https://gcc.gnu.org/onlinedocs/gcc/). For more information about how the host program is structured and the use of OpenCL™ API calls, you can refer to [Developing Applications](https://www.xilinx.com/html_docs/xilinx2019_2/vitis_doc/lhv1569273988420.html).

1. **Compiling the Software Program**

   To compile the host application, use the `-c` option with a list of the host source files.  
Optionally, the output object file name can be specified with the `-o` option as shown below.

    ```bash
    g++ ... -c <source_file_name1> ... <source_file_nameN> -o <object_file_name> -g
    ```

2. **Linking the Software Program**

    To link the generated object files, use the `-l` option and object input files as follows.

     ```bash
     g++ ... -l <object_file1.o> ... <object_fileN.o> -o <output_file_name>
     ```

   >**TIP:** Host compilation and linking can be integrated into one step which does not require the `-c` and `-l` options. Only the source input files are required as shown below.
   >
   >`g++ ... <source_file_name1> ... <source_file_nameN> ... -o <output_file_name>`

3. **Required Flags**

   You will need to specify include paths and library paths for XRT and Vivado tools:  

   1. Use the `-I` option to specify the include directories: `-I$XILINX_XRT/include -I$XILINX_VIVADO/include`
   2. Use the `-L` option to specify directories searched for `-l` libraries: `-L$XILINX_XRT/lib`
   3. Use the `-l` option to specify libraries used during linking: `-lOpenCL -lpthread -lrt -lstdc++`

4. **Complete Command**

   The complete command to build, link, and compile the host program in one step, from the `./reference_files/run` folder, will look like the following.

    ```bash
    g++ -I$XILINX_XRT/include/ -I$XILINX_VIVADO/include/ -Wall -O0 -g -std=c++11 \
    /src/host/host.cpp  -o 'host'  -L$XILINX_XRT/lib/ -lOpenCL -lpthread -lrt -lstdc++
    ```

   >**Command Options and Descriptions**
   >
   >* `-I../libs`, `-I$XILINX_XRT/include/`, and `-I$XILINX_VIVADO/include/`: Include directory
   >* `-Wall`: Enable all warnings
   >* `-O0`: Optimization option (execute the least optimization)
   >* `-g`: Generate debug info
   >* `-std=c++11`: Language Standard (define the C++ standard, instead of the include directory)
   >* `../src/host.cpp`: Source files
   >* `-o 'host'`: Output name
   >* `-L$XILINX_XRT/lib/`: Look in XRT library
   >* `-lOpenCL`, `-lpthread`, `-lrt`, and `-lstdc++`: Search the named library during linking

# 5. RTL Kernel (Building the Hardware)
Next, you need to build the kernels that run on the hardware accelerator card.  Like building the host application, building kernels also requires compiling and linking. The hardware kernels can be coded in C/C++, OpenCL C, or RTL. The C/C++ and OpenCL C kernels are compiled using the Vitis compiler, while RTL-coded kernels are compiled using the Xilinx `package_xo` utility.

For details on both `v++` and `package_xo`, refer to the [Vitis Environment Reference Materials](https://www.xilinx.com/html_docs/xilinx2019_2/vitis_doc/yxl1556143111967.html). Regardless of how each kernel is compiled, both methods generate a Xilinx object file (XO) as an output.

The object files are subsequently linked with the shell (hardware platform) through the Vitis compiler to create the FPGA binary file, or xclbin file.

The following figure shows the compiling and linking flow for the various types of kernels.  

  ![compiling_and_linking_flow](images/compiling_and_linking_flow.png)

This tutorial is limited to `package_xo` compilation of RTL kernels.

RTL kernels are compiled and linked using the Xilinx package_xo utility. 

The package_xo command is a Tcl command within the Vivado Design Suite. It is used to generate a Xilinx object file (.xo) from an RTL kernel. 

**Syntax**
package_xo  -kernel_name <arg> [-force] [-kernel_xml <arg>] [-design_xml <arg>]
            [-ip_directory <arg>] [-parent_ip_directory <arg>]
            [-kernel_files <args>] [-kernel_xml_args <args>]
            [-kernel_xml_pipes <args>] [-kernel_xml_connections <args>]
            -xo_path <arg> [-quiet] [-verbose]

| Argument | Description |
| --- | --- |
| `-kernel_name <arg>` | Required. Specifies the name of the RTL kernel. |
| `-force` | (Optional) Overwrite an existing .xo file if one exists. |
| `-kernel_xml <arg>` | (Optional) Specify the path to an existing kernel XML file. |
| `-design_xml <arg>` | (Optional) Specify the path to an existing design XML file |
| `-ip_directory <arg>	` | (Optional) Specify the path to the kernel IP directory. |
| `-parent_ip_directory	` | (Optional) If the kernel IP directory specified contains multiple IPs, specify a directory path to the parent IP where its component.xml is located directly below. |
| `-kernel_files` | (Optional) Kernel file name(s). |
| `-kernel_xml_args <args>	` | (Optional) Generate the kernel.xml with the specified function arguments. |
| `-kernel_xml_pipes <args>	` | (Optional) Generate the kernel.xml with the specified pipe(s) |
| `-kernel_xml_connections <args>	` | (Optional) Generate the kernel.xml file with the specified connections. |
| `-xo_path <arg>	` | (Required) Specifies the path and file name of the compiled object (.xo) file |
| `-quiet` | (Optional) Execute the command quietly, returning no messages from the command. The command also returns TCL_OK regardless of any errors encountered during execution |
| `-verbose` | (Optional) Temporarily override any message limits and return all messages from this command. |

In our case, the command that we are using is the following:
`package_xo -xo_path {xoname} -kernel_name Vadd_A_B -ip_directory ./packaged_kernel_${suffix} -kernel_xml ./src/xml/kernel.xml`

where:
```
{xoname} is .xclbin/$(KERNEL).$(TARGET).$(DEVICE).xo 
{suffix} is "$(KERNEL)_$(TARGET)_$(DEVICE)"
  $(KERNEL): vadd
  $(TARGET): hw
  $(DEVICE): xilinx_u250_xdma_201830_2
```

## XML file
As it can be seen, a kernel description XML file is needed by the `package_xo` command to create an RTL kernel that can be used in the SDAccel environment (it is necessary one per kernel). The file must be called `kernel.xml`. The XML file specifies kernel attributes like the register map and ports which are needed by the runtime and SDAccel flows. The following is the structure of our `kernel.xml` file:
```
<?xml version="1.0" encoding="UTF-8"?>
<root versionMajor="1" versionMinor="6">
  <kernel name="Vadd_A_B" language="ip_c" vlnv="mycompany.com:kernel:Vadd_A_B:1.0" attributes="" preferredWorkGroupSizeMultiple="0" workGroupSize="1" interrupt="true" hwControlProtocol="ap_ctrl_hs">
    <ports>
      <port name="s_axi_control" mode="slave" range="0x1000" dataWidth="32" portType="addressable" base="0x0"/>
      <port name="m00_axi" mode="master" range="0xFFFFFFFFFFFFFFFF" dataWidth="512" portType="addressable" base="0x0"/>
      <port name="m01_axi" mode="master" range="0xFFFFFFFFFFFFFFFF" dataWidth="512" portType="addressable" base="0x0"/>
    </ports>
    <args>
      <arg name="scalar00" addressQualifier="0" id="0" port="s_axi_control" size="0x4" offset="0x010" type="uint" hostOffset="0x0" hostSize="0x4"/>
      <arg name="A" addressQualifier="1" id="1" port="m00_axi" size="0x8" offset="0x018" type="int*" hostOffset="0x0" hostSize="0x8"/>
      <arg name="B" addressQualifier="1" id="2" port="m01_axi" size="0x8" offset="0x024" type="int*" hostOffset="0x0" hostSize="0x8"/>
    </args>
  </kernel>
</root>

```

The following table describes the format of the kernel XML in detail:
| Tag | Attribute | Description |
| --- | --- | --- |
| `<root>` | versionMajor | Set to 1 for the current release of SDAccel |
|  | versionMinor | Set to 6 for the current release of SDAccel. |
| `<kernel>` | name | Kernel name |
|  | language | Always set it to `ip_c` for RTL kernels.
|  | vlnv | <p>Must match the vendor, library, name, and version attributes in the `component.xml` of an IP. For example, if `component.xml` has the following tags: <br>`<spirit:vendor>xilinx.com</spirit:vendor>` <br> `<spirit:library>hls</spirit:library>` <br> `<spirit:name>test_sincos</spirit:name>` <br> `<spirit:version>1.0</spirit:version>` <br> The vlnv attribute in kernel XML must be set to: <br> `xilinx.com:hls:test_sincos:1.0`</p> |
|  | attributes | Reserved. Set it to empty string. |
|  | preferredWorkGroupSizeMultiple | Reserved. Set it to 0. |
|  | workGroupSize | Reserved. Set it to 1. |
|  | interrupt | Set equal to "true" (that is,. interrupt="true") if interrupt present else omit. |
| `<port>` | name | Port name. At least an AXI4 master port and an AXI4-Lite slave port are required. The AXI4-Stream port can be optionally specified to stream data between kernels. The AXI4-Lite interface name must be `S_AXI_CONTROL`. |
|  | mode | <ul><li>For AXI4 master port, set it to "master."</li><li>For AXI4 slave port, set it to "slave."</li><li>For AXI4-Stream master port, set it to "write_only."</li><li>For AXI4-Stream slave port, set it "read_only."</li></ul> |
|  | range | The range of the address space for the port | 
|  | dataWidth | The width of the data that goes through the port, default is 32 bits |
|  | portType  | <p>Indicate whether or not the port is addressable or streaming. <ul><li>For AXI4 master and slave ports, set it to "addressable."</li><li>For AXI4-Stream ports, set it to "stream."</li></ul></p> |
|  | base | For AXI4 master and slave ports, set to `0x0`. This tag is not applicable to AXI4-Stream ports | 
| `<arg>` | name | Kernel argument name. | 
|  | addressQualifier | <p> Valid values: <br> 0:Scalar kernel input argument <br> 1:global memory <br> 2:local memory <br> 3:constant memory <br> 4:pipe </p> |





# 10. Software and Hardware Emulation

# 11. Execution in Hardware
