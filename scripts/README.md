<table>
  <tr>
    <td align="center"><h1>Understading package_kernel.tcl</h1>
    </td>
  </tr>
  <tr>
    <td align="center"><h3>Author: Leandro Dorta Duque</h3></td>
  </tr>
  
</table>

> **IMPORTANT**
>* This tutorial is a supporting document for the tutorial [Getting started with RTL Kernels on Alveo Card](https://github.com/LeandroDorta/alveo_tutorial).
>* The file analyzed in the tutorial is provided by XILINX and can be modified at your own risk

# 1. Introduction
As it was analyzed in the "Getting started with RTL Kernels on Alveo Card" tutorial, a Tcl script called `package_kernel.tcl` 
is used for the setup of the RTL kernel. The purpose of this tutorial is to understand the content of this Tcl script. The following displays the commands used in the script: 


```
set path_to_hdl "./src/IP"
set path_to_packaged "./packaged_kernel_${suffix}"
set path_to_tmp_project "./tmp_kernel_pack_${suffix}"

create_project -force kernel_pack $path_to_tmp_project
add_files -norecurse [glob $path_to_hdl/*.v $path_to_hdl/*.sv ]
set_property top gcd_kernel [current_fileset]
set_property top_file {$path_to_hdl/gcd_kernel.v} [current_fileset]
set_property source_mgmt_mode DisplayOnly [current_project]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
ipx::package_project -root_dir $path_to_packaged -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core $path_to_packaged/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml
set_property core_revision 2 [ipx::current_core]
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] [ipx::current_core]
}
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::associate_bus_interfaces -busif m00_axi -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif m01_axi -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]

set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
set_property supported_families { } [ipx::current_core]
set_property auto_family_support_level level_2 [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project -delete

```

# 2. Analysis of commands

```
set path_to_hdl "./src/IP"
set path_to_packaged "./packaged_kernel_${suffix}"
set path_to_tmp_project "./tmp_kernel_pack_${suffix}"
```

These three commands are basically setting the values of the constants `path_to_hdl`, `path_to_packaged` and `path_to_tmp_project`. It is important to notice the utilization of `$(suffix)` which is a parameter that was set in `gen_xo.tcl` which is composed by `{kernel_name}.{target}.{device}`. 

```
create_project -force kernel_pack $path_to_tmp_project
```
The `create_project` command can be analyzed in the following way:

Description: 
Create a new project

Syntax:
create_project [-part arg] [-force] [-in_memory] [-ip] [-quiet] [-verbose] [name] [dir]

Returns:
New project object

| Name | Description |
| --- | --- |
| [-part] | Target part |
| [-force] | Overwrite existing project directory |
| [-in_memory] | Create an in-memory project |
| [-ip] | Default GUI behavior is for a managed IP project |
| [-quiet] | Ignore command errors |
| [-verbose] | Suspend message limits during command execution |
| [name] | Project name |
| [dir] | Directory where the project file is saved Default . |

```
add_files -norecurse [glob $path_to_hdl/*.v $path_to_hdl/*.sv ]
```
Description
Add sources to the active fileset

Syntax 
add_files [-fileset arg] [-norecurse] [-scan_for_includes] [-quiet] [-verbose] [files...] 

Returns 
List of file objects that were added

| Name | Description |
| --- | --- |
| [-fileset] | Fileset name |
| [-norecurse] | Do not recursively search in specified directories |
| [-scan_for_includes] | Scan and add any included files found in the fileset's RTL sources |
| [-quiet] | Ignore command errors |
| [-verbose] | Suspend message limits during command execution |
| [-verbose] | Suspend message limits during command execution |
| [files] | Name of the files and/or directories to add. Must be specified if -scan_for_includes is not used. |

```
set_property top gcd_kernel [current_fileset]
set_property top_file {$path_to_hdl/gcd_kernel.v} [current_fileset]
```

These two Tcl commands are utilized to set the top module kernel and the top file of the project.

```
set_property source_mgmt_mode DisplayOnly [current_project]
```

This command is used to force the compilation of all IP files.

```
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
```
Description
Updates a fileset compile order and possibly top based on a design graph

Syntax:
update_compile_order [-force_gui] [-fileset arg] [-quiet] [-verbose]

Returns:
Nothing

| Name | Description | 
| --- | --- | 
| [-force_gui] | Execute this command, even when run interactively in the GUI. |
| [-fileset] | Fileset to update based on a design graph. |
| [-verbose] | Suspend message limits during command execution. |
| [-quiet] | Ignore command errors. |

```
ipx::package_project -root_dir $path_to_packaged -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
```
Description: 
Package the current project

Syntax: 
ipx::package_project  [-root_dir <arg>] [-vendor <arg>] [-library <arg>]
                      -taxonomy <args> [-generated_files] [-import_files]
                      [-set_current <arg>] [-force]
                      [-force_update_compile_order]
                      [-archive_source_project <arg>] [-quiet] [-verbose]
                      [<component>]
Usage:
| Name | Description | 
| --- | --- | 
| [-root_dir] | User specified root directory for component.xml. |
| [-vendor] | User specified vendor of the IP VLNV. |
| [-library] | User specified library of the IP VLNV. |
| [-taxonomy] | User specified taxonomy for the IP. |
| [-generated_files] | If true, package XCI generated files. |
| [-import_files] | If true, import remote IP files into the IP structure. |
| [-set_current] | Set the core as the current core. |
| [-force] | Override existing packaged component.xml. |
| [-force_update_compile_order] | <p>Force the packager to invoke the old behaviour of reordering and disabling files as necessary (This will override a manually set compile order). </p> |
| [-quiet] | Ignore command errors. |
| [-verbose] | Suspend message limits during command execution. |
| [<component>] | Core object. |
  
```
ipx::unload_core $path_to_packaged/component.xml
```
Description: 
Unload/remove a component.

Syntax: 
ipx::unload_core  [-quiet] [-verbose] [<name>]

| Name | Description | 
| --- | --- | 
| [-quiet] | Ignore command errors. | 
| [-verbose] | Suspend message limits during command execution. | 
| [<name>] | Component XML filename or colon separated VLNV. |

```
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml
```
Description: 
Edit IP in new project.

Syntax: 
ipx::edit_ip_in_project  [-name <arg>] [-directory <arg>] [-force <arg>]
                         [-use_archived_source_project <arg>] [-upgrade <arg>]
                         [-quiet] [-verbose] [<xml_file>]
Usage:
| Name | Description | 
| --- | --- |
| [-name] | Project name | 
| [-directory] | Location of the project to be created. Default: component XML location.|
| [-force] | Option to override an existing project. |
| [-use_archived_source_project] | <p>If the IP was packaged with a project archive, use this instead of creating a new project for editing.</p>|
| [-upgrade] | Upgrade core to latest version of meta-data (equivalent to ipx::upgrade_core).|
| [-quiet] | Ignore command errors | 
| [-verbose] | Suspend message limits during command execution |
| [<xml_file>] | Component XML file to load and unpackage. Default: component.xml |
  
```
set_property core_revision 2 [ipx::current_core]
```

```
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] [ipx::current_core]
}
```

The for loop is utilized to loop over the user parameters in order to remove them.

```
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
```
These two commands are used to set the sdx kernel and specifying the kind of kernel (rtl).

```
ipx::create_xgui_files [ipx::current_core]
```

```
ipx::associate_bus_interfaces -busif m00_axi -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif m01_axi -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]
```

These three commands are the ones that set the interfaces used in the kernel. In this case,
it is setting the AXI4 interfaces passing the signal `ap_clk` as the clock.

```
set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
```

This TCL command is used to include elements from the xpm libraries such as the XPM_FIFO
which is used in `axi_read_master` and `axi_write_master`.

```
set_property supported_families { } [ipx::current_core]
```

```
set_property auto_family_support_level level_2 [ipx::current_core]
```

```
ipx::update_checksums [ipx::current_core]
```

```
ipx::save_core [ipx::current_core]
```

```
close_project -delete
```
