# RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect for Embedded Applications
## 🚀 Complete RTL-to-GDSII ASIC Implementation | RISC-V | SoC | AXI4-Lite | SKY130
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue)]()
[![ASIC](https://img.shields.io/badge/Design-ASIC-orange)]()
[![PDK](https://img.shields.io/badge/PDK-SKY130-red)]()
[![Flow](https://img.shields.io/badge/Flow-OpenLane-purple)]()
[![Target](https://img.shields.io/badge/Target-100%20MHz-success)]()
[![DRC](https://img.shields.io/badge/DRC-0%20Violations-success)]()
[![LVS](https://img.shields.io/badge/LVS-0%20Errors-success)]()

A complete **RTL-to-GDSII implementation of a RISC-V based SoC subsystem**, developed as part of the **NIELIT - eChipHub Internship Programme 2026**.
The design integrates a **PicoRV32 RISC-V processor**, CPU-to-AXI bridge, AXI4-Lite interconnect, ROM, SRAM, and UART peripheral, followed by functional verification, RTL synthesis, physical implementation, timing analysis, multi-corner analysis, power analysis, and physical sign-off using the **SKY130 PDK**.

##  System at a Glance

```text
                         ┌─────────────────────┐
                         │   PicoRV32 RISC-V   │
                         │         CPU         │
                         └──────────┬──────────┘
                                    │
                         Native Memory Interface
                                    │
                         ┌──────────▼──────────┐
                         │   CPU-to-AXI Bridge │
                         └──────────┬──────────┘
                                    │
                              AXI4-Lite Master
                                    │
                    ┌───────────────▼───────────────┐
                    │     AXI4-Lite Interconnect    │
                    │       + Address Decoder       │
                    └───────┬────────┬────────┬─────┘
                            │        │        │
                         ┌──▼──┐  ┌──▼───┐  ┌─▼────┐
                         │ ROM │  │ SRAM │  │ UART │
                         │ S0  │  │  S1  │  │  S2  │
                         └─────┘  └──────┘  └──────┘
```
## Architecture : 1 AXI4-Lite Master → 3 AXI4-Lite Slaves
Memory Map
Component	                          Function	                      Base Address
PicoRV32	                      RISC-V processing core	                  —
ROM	                      Program / instruction memory	               0x0000_0000
SRAM	                        Read/write data memory	                 0x0001_0000
UART	                      Serial communication peripheral	           0x1000_0000

## ⭐ Final Implementation Results
The design was taken through the complete physical implementation flow and evaluated for area, timing, power, and physical verification. 
| Category                  | Metric              |     Final Result |
| ------------------------- | ------------------- | ---------------: |
| **Technology**            | PDK                 |       **SKY130** |
| **Area**                  | Die Area            |     **1.00 mm²** |
| **Area**                  | Core Area           |   **0.9653 mm²** |
| **Area**                  | Core Utilization    |          **35%** |
| **Design**                | Total Cells         |       **25,520** |
| **Timing**                | Clock Period        |        **20 ns** |
| **Timing**                | Clock Frequency     |       **50 MHz** |
| **Timing**                | Critical Path Delay |      **7.34 ns** |
| **Timing**                | Setup WNS           |     **13.41 ns** |
| **Timing**                | Hold Worst Slack    |      **0.64 ns** |
| **Timing**                | TNS                 |      **0.00 ns** |
| **Power**                 | Total Power         |      **36.6 mW** |
| **Physical Verification** | DRC                 | **0 violations** |
| **Physical Verification** | LVS                 |     **0 errors** |

## ⏱️ Multi-Corner Timing Results
The design was evaluated under three RC extraction conditions to analyze timing robustness.
| RC Corner  | Setup Slack |  Hold Slack |
| ---------- | ----------: | ----------: |
| **RC-Min** | **6.88 ns** | **0.34 ns** |
| **RC-Nom** | **6.75 ns** | **0.31 ns** |
| **RC-Max** | **6.61 ns** | **0.28 ns** |

## RTL-to-GDSII Flow
```text 
                    DESIGN & VERIFICATION
                            │
                            ▼
                    RISC-V + AXI RTL
                            │
                            ▼
                    Firmware Integration
                            │
                            ▼
                    RTL Simulation
                            │
                            ▼
                    Functional Verification
                            │
                            ▼
                    ───────────────────
                       ASIC FLOW
                    ───────────────────
                            │
                            ▼
                        Synthesis
                            │
                            ▼
                       Floorplanning
                            │
                            ▼
                     Power Planning
                            │
                            ▼
                        Placement
                            │
                            ▼
                 Clock Tree Synthesis
                            │
                            ▼
                         Routing
                            │
                            ▼
                 Parasitic Extraction
                            │
                            ▼
                           STA
                            │
                            ▼
                           MCA
                            │
                            ▼
                      Power Analysis
                            │
                            ▼
                        DRC / LVS
                            │
                            ▼
                     Final Sign-off
                            │
                            ▼
                         GDSII
```                    
## 📸 Final Layout
Final GDSII / KLayout View
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/aaff1535f34c61e5af1d9f5bcebc35f3a194676d/screenshots/gdsII/gds2.png)
The final GDSII represents the completed physical implementation of the RISC-V based SoC subsystem after synthesis, floorplanning, placement, CTS, routing, extraction, timing analysis, and physical verification.

## 🛠️ Technology & Tools
| Domain              | Tools / Technologies |
| ------------------- | -------------------- |
| **Processor**       | PicoRV32 RISC-V      |
| **HDL**             | Verilog              |
| **Firmware**        | C, RISC-V Assembly   |
| **Simulation**      | Verilator, GTKWave   |
| **Synthesis**       | Yosys                |
| **Physical Design** | OpenLane, OpenROAD   |
| **STA**             | OpenSTA              |
| **Layout / DRC**    | Magic, KLayout       |
| **LVS**             | Netgen               |
| **PDK**             | SKY130               |
| **Scripting**       | Python, Tcl, Bash    |

## 📂 Project Scope
This repository documents the complete implementation journey:
Firmware → RTL → Verification → Synthesis → Floorplan → Power Planning → Placement → CTS → Routing → Extraction → STA → MCA → Power → DRC/LVS → GDSII
Detailed implementation results, reports, and screenshots are provided throughout the repository.

## 📌 Project Highlights
* RISC-V based SoC subsystem
* PicoRV32 processor integration
* CPU-to-AXI4-Lite bridge
* 1 Master / 3 Slave AXI4-Lite architecture
* ROM + SRAM + UART integration
*Firmware-to-hardware execution flow
* RTL functional verification
* Technology-mapped synthesis
* Complete RTL-to-GDSII physical implementation
* Post-route timing analysis
* RC-Min / RC-Nom / RC-Max MCA
* Power analysis
* DRC and LVS verification
* Final GDSII generation
-----------------------------------------------------------------------------------------------------------------------------------------------
## 1. Objectives
* Design a RISC-V based SoC subsystem using Verilog HDL.
* Integrate the PicoRV32 RISC-V processor with an AXI4-Lite interconnect.
* Develop a CPU-to-AXI bridge for communication between the processor and AXI-based peripherals.
* Integrate ROM, SRAM, and UART peripherals.
* Verify RTL functionality using simulation and waveform analysis.
* Perform RTL synthesis using Yosys.
* Implement the synthesized design through a complete RTL-to-GDSII flow.
* Analyze timing across different RC corners.
* Perform power and physical verification analysis.
* Generate and verify the final GDSII layout.

# 2. System Architecture

## 2.1 Overall Architecture
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/1af1686bdbd139936160204bdb7ea3acf05ed1ad/screenshots/architecture/architecture.png.jpeg)
The SoC subsystem consists of a PicoRV32 RISC-V processor connected to three AXI4-Lite slave peripherals through a CPU-to-AXI bridge and AXI4-Lite interconnect.
             
### AXI Configuration

* 1 AXI4-Lite Master
* 3 AXI4-Lite Slaves
* 32-bit AXI4-Lite data interface
* Address-based slave selection
* Dedicated address decoder

## 2.2 PicoRV32 RISC-V CPU
PicoRV32 acts as the main processing element of the SoC subsystem.
The processor provides:
* Program Counter
* Register File
* Instruction Decoder
* ALU
* Load/Store Unit
* Memory Interface
* Interrupt handling

The CPU communicates with the subsystem through its native memory interface:
```text
mem_valid
mem_ready
mem_addr[31:0]
mem_wdata[31:0]
mem_rdata[31:0]
mem_wstrb[3:0]
```

## 2.3 CPU-to-AXI Bridge
The CPU-to-AXI bridge translates PicoRV32 native memory transactions into AXI4-Lite transactions.
The bridge handles:
* Read transactions
* Write transactions
* Address generation
* Write data transfer
* Read data reception
* Response handling
* Transaction sequencing
* FSM-based control
* 
## 2.4 AXI4-Lite Interconnect
The AXI4-Lite interconnect acts as the central communication fabric between the processor and peripheral slaves.
The interconnect performs address-based slave selection and routes AXI transactions to the appropriate peripheral.

## 2.5 ROM
The ROM provides read-only program/instruction storage.
| Parameter    | Value                        |
| ------------ | ---------------------------- |
| Function     | Program / Instruction Memory |
| Access       | Read Only                    |
| Base Address | `0x0000_0000`                |
| Interface    | AXI4-Lite                    |

## 2.6 SRAM
The SRAM provides read/write data storage.
| Parameter    | Value         |
| ------------ | ------------- |
| Function     | Data Memory   |
| Access       | Read / Write  |
| Base Address | `0x0001_0000` |
| Interface    | AXI4-Lite     |

## 2.7 UART
The UART is implemented as an AXI4-Lite peripheral and provides serial communication.
### UART Features
* AXI4-Lite interface
* UART TX
* UART RX
* FIFO/buffer-based data handling
* FSM-based control
* 8N1 serial communication

External interfaces:
```text
uart_tx
uart_rx
```
Base address:

```text
0x1000_0000
```
# 3. AXI4-Lite Architecture
## 3.1 AXI4-Lite Master
The CPU-to-AXI bridge acts as the AXI4-Lite master and generates read/write transactions based on PicoRV32 memory requests.
## 4.2 AXI4-Lite Slaves
The subsystem contains three AXI4-Lite slaves:

| Slave | Peripheral | Access       | Base Address  |
| ----- | ---------- | ------------ | ------------- |
| S0    | ROM        | Read         | `0x0000_0000` |
| S1    | SRAM       | Read / Write | `0x0001_0000` |
| S2    | UART       | Read / Write | `0x1000_0000` |

## 3.3 Address Mapping
The AXI address decoder determines the target slave based on the transaction address.
```text
0x0000_0000 → ROM
0x0001_0000 → SRAM
0x1000_0000 → UART
```
## 3.4 Read Transaction
A typical AXI4-Lite read transaction follows:
```text
Master
  ↓
ARVALID + Address
  ↓
Address Decoder
  ↓
Selected Slave
  ↓
ARREADY
  ↓
Read Data + RVALID
  ↓
Master
```
## 3.5 Write Transaction
A typical AXI4-Lite write transaction follows:
```text
Master
  ↓
AWVALID + Address
  +
WVALID + Write Data
  ↓
Address Decoder
  ↓
Selected Slave
  ↓
Write Response
  ↓
Master
```
## 3.6 Address Decoding
The address decoder identifies the appropriate AXI slave using the incoming address and generates the corresponding slave-select signals.

## 3.7 # PicoRV32 RISC-V SoC — CPU and AXI4-Lite Interface
### CPU Configuration
| Parameter        | Configuration |
| ---------------- | ------------- |
| ISA              | RV32I         |
| CPU Core         | PicoRV32      |
| PC Reset Address | `0x00000000`  |
| Data Width       | 32-bit        |
| Address Width    | 32-bit        |
| TWO_STAGE        | `0`           |
| ENABLE_MUL       | `0`           |
| ENABLE_DIV       | `0`           |
| COMPRESSED ISA   | `0`           |
| ENABLE_IRQ       | `0`           |
| COUNTERS         | `1`           |
| CATCH_ILL        | `1`           |

## 3.8 CPU Internal Blocks

```text
                    PicoRV32 CPU
                         │
        ┌────────────────┼────────────────┐
        │                │                │
     Fetch Unit       Decode          Execute / ALU
        │                │                │
      PC=0x0          RV32I          ALU + Shift
        │
        └───────────────┬────────────────┘
                        │
                 Register File
                   x0 – x31
                  32 × 32-bit
                        │
                        ▼
              Native Memory Interface
```
## 3.9 Native Memory Interface
The PicoRV32 core uses a native memory interface to communicate with memory and peripherals.
## Key Signals
| Signal      | Width | Description                                                   |
| ----------- | ----: | ------------------------------------------------------------- |
| `mem_valid` |     1 | Indicates that the CPU has a valid memory request             |
| `mem_instr` |     1 | Indicates an instruction fetch                                |
| `mem_ready` |     1 | Indicates that the memory request has been accepted/completed |
| `mem_addr`  |    32 | Target memory/peripheral address                              |
| `mem_wdata` |    32 | Data written by the CPU                                       |
| `mem_wstrb` |     4 | Byte-write enable strobes                                     |
| `mem_rdata` |    32 | Data returned to the CPU                                      |

### Important Signal Behavior
```text
mem_valid = 1
    │
    ├── CPU has a valid memory transaction
    │
    ├── mem_instr = 1
    │      └── Instruction fetch
    │
    └── mem_instr = 0
           └── Data access
```
For writes, `mem_wstrb` indicates which bytes are enabled.
```text
mem_wstrb = 4'b0000  → Read
mem_wstrb = 4'b1111  → 32-bit Write
```
# 3.10 PicoRV32 ↔ AXI4-Lite Bridge
The native PicoRV32 memory interface is converted into the **AXI4-Lite protocol** by the bridge.
```text
┌──────────────────┐
│    PicoRV32      │
│    RV32I CPU     │
└────────┬─────────┘
         │ Native Memory Interface
         │
         ▼
┌────────────────────────┐
│     AXI4-Lite Bridge   │
│                        │
│      Bridge FSM        │
└────────┬───────────────┘
         │ AXI4-Lite
         │
         ▼
┌────────────────────────┐
│    AXI Interconnect    │
└───────┬──────┬─────────┘     
        ▼      ▼
      ROM    SRAM/UART
```
The bridge performs the following conversion:
```text
PicoRV32 Native Memory Request
              │
              ▼
        AXI4-Lite Request
              │
              ▼
        AXI Interconnect
              │
       ┌──────┼──────┐
       ▼      ▼      ▼
      ROM    SRAM   UART
```
# 3.11. AXI4-Lite Channel Signals
AXI4-Lite contains five independent channels:
1. Write Address — AW
2. Write Data — W
3. Write Response — B
4. Read Address — AR
5. Read Data — R
6. 
## 3.12 AW — Write Address Channel
| Signal         | Direction      | Description                                  |
| -------------- | -------------- | -------------------------------------------- |
| `awvalid`      | Master → Slave | Indicates a valid write address              |
| `awready`      | Slave → Master | Indicates that the slave accepts the address |
| `awaddr[31:0]` | Master → Slave | 32-bit write target address                  | |

## 3.13 Handshake
```text
AW Transfer occurs when:

awvalid = 1
       AND
awready = 1
```
# 3.14 W — Write Data Channel
| Signal        | Direction      | Description                               |
| ------------- | -------------- | ----------------------------------------- |
| `wvalid`      | Master → Slave | Indicates valid write data                |
| `wready`      | Slave → Master | Indicates that the slave accepts the data |
| `wdata[31:0]` | Master → Slave | 32-bit write data                         |
| `wstrb[3:0]`  | Master → Slave | Byte-enable strobes                       |
```text ```
## 3.15 B — Write Response Channel
| Signal       | Direction      | Description                                    |
| ------------ | -------------- | ---------------------------------------------- |
| `bvalid`     | Slave → Master | Indicates a valid write response               |
| `bready`     | Master → Slave | Indicates that the master accepts the response |
| `bresp[1:0]` | Slave → Master | Write response status                          |
The normal successful response is:
```text
bresp = 2'b00
```
which represents **OKAY**.
##Handshake
```text
B Transfer occurs when:
bvalid = 1 AND bready = 1
```
# 3.16 AR — Read Address Channel
| Signal         | Direction      | Description                                  |
| -------------- | -------------- | -------------------------------------------- |
| `arvalid`      | Master → Slave | Indicates a valid read address               |
| `arready`      | Slave → Master | Indicates that the slave accepts the address |
| `araddr[31:0]` | Master → Slave | 32-bit read target address                   |
## Handshake
```text
AR Transfer occurs when:
arvalid = 1 AND arready = 1
```
# 3.17 R — Read Data Channel
| Signal        | Direction      | Description                                |
| ------------- | -------------- | ------------------------------------------ |
| `rvalid`      | Slave → Master | Indicates valid read data                  |
| `rready`      | Master → Slave | Indicates that the master accepts the data |
| `rdata[31:0]` | Slave → Master | 32-bit read data                           |
| `rresp[1:0]`  | Slave → Master | Read response status                       |
Successful read response:
```text
rresp = 2'b00
```
which represents **OKAY**.
## Handshake
```text
R Transfer occurs when:
rvalid = 1 AND rready = 1
```
## 3.18. AXI4-Lite Handshake Protocol

The fundamental AXI4-Lite rule is:
> A transfer occurs only when both VALID and READY are HIGH during the same clock cycle.

### General Handshake
```text
VALID = 1 and READY = 1 ---->TRANSFER
```
If `VALID = 1` but `READY = 0`, the master must keep `VALID` asserted until the slave accepts the transaction.
The slave may assert `READY` before or after `VALID`.

## 3.19 Write Transaction
An AXI4-Lite write consists of:
```text
Write Address
     │
     ▼
    AW
     │
     ▼
Write Data
     │
     ▼
     W
     │
     ▼
Write Response
     │
     ▼
     B
```
The AW and W channels are independent and may be transferred concurrently.

### 3.20 Write Sequence
```text
CPU
 │ mem_valid = 1
 │ mem_wstrb != 0
 ▼
AXI Bridge
 │ awvalid = 1
 ▼
AW Handshake
 │ wvalid = 1
 ▼
W Handshake
 │ bready = 1
 ▼
B Response
 │ mem_ready = 1
 ▼
CPU
```
# 3.21 Read Transaction
An AXI4-Lite read consists of:
```text
Read Address
     │
     ▼
    AR
     │
     ▼
Read Data
     │
     ▼
     R
```
### 3.22 Read Sequence
```text
CPU
 │ mem_valid = 1
 │ mem_wstrb = 0
 ▼
AXI Bridge
 │ arvalid = 1
 ▼
AR Handshake
 │ Wait for rvalid
 ▼
R Response
 │ Capture rdata
 ▼
mem_rdata
 │ mem_ready = 1
 ▼
CPU
```
## 3.23 AXI Bridge FSM
The AXI4-Lite bridge uses a **5-state finite-state machine** to control CPU memory transactions.
```text
                    ┌──────────────┐
                    │   ST_IDLE    │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              │                         │
       Write Request               Read Request
       mem_wstrb != 0              mem_wstrb == 0
              │                         │
              ▼                         ▼
       ┌──────────────┐          ┌──────────────┐
       │   ST_WR_AW   │          │   ST_RD_AR   │
       └──────┬───────┘          └──────┬───────┘
              │                         │
         awready=1                  arready=1
              │                         │
              ▼                         ▼
       ┌──────────────┐          ┌──────────────┐
       │   ST_WR_B    │          │   ST_RD_R    │
       └──────┬───────┘          └──────┬───────┘
              │                         │
         bvalid=1                  rvalid=1
              │                         │
              ▼                         ▼
             IDLE                      IDLE
```
## 3.24 FSM States
| State      | Function                                  |
| ---------- | ----------------------------------------- |
| `ST_IDLE`  | Wait for a CPU memory request             |
| `ST_WR_AW` | Issue AXI write address                   |
| `ST_WR_B`  | Issue AXI write data and collect response |
| `ST_RD_AR` | Issue AXI read address                    |
| `ST_RD_R`  | Wait for and capture AXI read data        |

# 3.25 CPU Request Routing
The bridge determines whether the CPU request is a read or write using `mem_wstrb`.
```text
                 mem_valid
                     │
                     ▼
                 ST_IDLE
                     │
              ┌──────┴──────┐
              │             │
        mem_wstrb != 0  mem_wstrb == 0
              │             │
              ▼             ▼
           WRITE           READ
              │             │
              ▼             ▼
          AXI AW/W        AXI AR
              │             │
              ▼             ▼
          AXI B           AXI R
              │             │
              └──────┬──────┘
                     ▼
                mem_ready
                     │
                     ▼
                    CPU
```
# 3.26 Overall SoC Communication
The complete communication path is:
```text
┌─────────────────────┐
│      PicoRV32       │
│      RV32I CPU      │
└──────────┬──────────┘
           │ Native Memory Interface
           │ mem_valid
           │ mem_ready
           │ mem_addr
           │ mem_wdata
           │ mem_wstrb
           │ mem_rdata
           ▼
┌─────────────────────┐
│    AXI4-Lite Bridge │
│       FSM           │
└──────────┬──────────┘
           │ AXI4-Lite
           ▼
┌─────────────────────┐
│   AXI Interconnect  │
└──────────┬──────────┘
     ┌─────┼─────┐
     │     │     │
     ▼     ▼     ▼
    ROM   SRAM  UART
```
This architecture allows the **PicoRV32 RISC-V processor** to access memory and memory-mapped peripherals using its native memory interface while the **AXI4-Lite bridge** handles protocol conversion and transaction control.

### 4. Design Specifications
## 5.1 Clock & Timing Constraints
| Constraint              |         Value |
| ----------------------- | ------------: |
| Clock Period            |     **20 ns** |
| Target Frequency        |    **50 MHz** |
| Maximum Fanout          |         **8** |
| Maximum Transition      |    **1.5 ns** |
| Maximum Capacitance     |    **0.5 pF** |
| Output Capacitance Load | **17.653 fF** |

### CTS Constraints
| Constraint              |       Value |
| ----------------------- | ----------: |
| Clock Buffer Fanout     |      **16** |
| CTS Target Skew         |  **150 ps** |
| CTS Maximum Capacitance | **0.35 pF** |

## 5.2 Physical Design Constraints
| Constraint               |               Value |
| ------------------------ | ------------------: |
| Die Size                 | **1000 × 1000 µm²** |
| Target Core Utilization  |             **35%** |
| Placement Target Density |            **0.65** |
| Maximum Routing Layer    |  **Metal 4 (met4)** |

## 5.3 Placement & Routing Constraints
| Constraint               |      Value |
| ------------------------ | ---------: |
| Maximum Wire Length      | **600 µm** |
| Placement Target Density |   **0.65** |
| Maximum Routing Layer    |   **met4** |

## 5.4 Power Distribution Network Constraints
| Constraint           |     Value |
| -------------------- | --------: |
| PDN Vertical Pitch   | **25 µm** |
| PDN Horizontal Pitch | **25 µm** |

## 5. RTL Design
## 5.1 RTL Modules
The RTL implementation contains:
* PicoRV32 CPU
* CPU-to-AXI bridge
* AXI4-Lite interconnect
* AXI address decoder
* ROM
* SRAM
* UART AXI interface
* UART TX
* UART RX
* Top-level SoC integration
## 5.2 Combinational Logic
Combinational logic is used for:
* Address decoding
* AXI routing
* Control signal generation
* Data selection
* Next-state logic
## 5.3 Sequential Logic
Sequential logic is used for:
* State registers
* AXI transaction sequencing
* UART transmit/receive logic
* Memory control
* Clocked control signals
## 5.4 FSMs
Finite State Machines are used in transaction-control logic, including the CPU-to-AXI bridge and UART control logic.
## 5.5 Clock & Reset
The design uses synchronous clocked logic with reset control for initialization and deterministic operation.
## 5.6 UART TX/RX
The UART subsystem implements:
* Transmit logic
* Receive logic
* Serial shifting
* Start-bit detection
* Stop-bit handling
* FSM-based control
* 8N1 communication
## 5.7 Memory Interfaces
ROM and SRAM are connected to the AXI4-Lite interconnect through their respective slave interfaces.

## 6. RTL Verification
# 6.1 Testbench
Dedicated testbenches were developed for functional verification of the SoC, AXI4-Lite subsystem, and UART.
# 6.2 Simulation
RTL simulations were performed to verify the behavior of the designed modules before synthesis.
# 6.3 Functional Verification
Verification focused on:
* CPU operation
* AXI read transactions
* AXI write transactions
* Address decoding
* ROM access
* SRAM access
* UART communication
* Reset behavior
* Inter-module communication
# 6.4 Waveform Analysis
Simulation waveforms were analyzed to verify signal-level behavior and transaction sequencing.
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/6e23043a80a8a25e03d4ec58540bf1e93dbffed1/waveforms/waveform6.png)
The section of  complete waveforms are stored in the section : ``` waveforms```
## 7. RTL Synthesis
## 7.1 Synthesis Flow
The RTL was synthesized using **Yosys** and mapped to the **SKY130 standard-cell library**.
```text
Verilog RTL
    ↓
RTL Elaboration
    ↓
Process Conversion
    ↓
Logic Optimization
    ↓
DFF Mapping
    ↓
Technology Mapping
    ↓
Gate-Level Netlist
```
# 7.2 RTL Elaboration
The RTL hierarchy was elaborated to construct the complete synthesized design representation.
# 7.3 Logic Optimization
Logic optimization was performed to simplify the design and improve implementation efficiency.
# 7.4 DFF Mapping
Sequential logic was mapped to technology-specific flip-flop cells.
# 7.5 Technology Mapping
The optimized RTL was mapped to standard cells from the SKY130 library.
# 7.6 Gate-Level Netlist
A technology-mapped gate-level netlist was generated for subsequent physical implementation.
# 7.7 Synthesis Reports
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/753a9bcf67276aa72ec3a123fe4b47b0a6b10d26/screenshots/synthesis/area%20report.png)
Synthesis reports and screenshots are available under:
```text
screenshots/synthesis/
```
## 8. RTL-to-GDSII Flow
The complete physical design flow was implemented using **OpenLane/OpenROAD** with the SKY130 PDK.
## 8.1 Flow Overview
```text
RTL
 ↓
Synthesis
 ↓
Floorplanning
 ↓
Power Planning
 ↓
Placement
 ↓
CTS
 ↓
Routing
 ↓
Parasitic Extraction
 ↓
STA
 ↓
MCA (Multi corner Analysis)
 ↓
DRC
 ↓
LVS
 ↓
GDSII
```
## 8.2 Floorplanning
The floorplanning stage established the die and core dimensions and defined the target core utilization.
Key parameters:
* Die: **1000 × 1000 µm²**
* Core utilization: **35%**
* Placement density: **0.65**
 ![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/2f749a962da8b3d14b350a02d0879da42f582d30/screenshots/floorplan/floorplan_1.png)
Screenshots are available under:
```text
screenshots/floorplan/
```
## 8.3 Power Planning
The Power Distribution Network was implemented using the defined PDN pitch constraints.
```text
Vertical Pitch   = 25 µm
Horizontal Pitch = 25 µm
```
## 8.4 Placement
Standard cells were placed within the defined core area while considering placement density, timing, and routing requirements.
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/f9fbbf5dc0d8c605c0e8a56d1e1ab74b4aee3d91/screenshots/placement/placement_4.png)
Screenshots are available under:

```text
screenshots/placement/
```
## 8.5 Clock Tree Synthesis
CTS was performed to build and optimize the clock distribution network.
Key CTS constraints:
```text
Clock Buffer Fanout       = 16
Target Clock Skew         = 150 ps
Maximum Clock Capacitance = 0.35 pF
```
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/0b9cee97b58e83eadfd0ac4799f4d3defc2e9f72/screenshots/Clock_tree_synthesis/cts_2.png)
Screenshots are available under:
```text
screenshots/cts/
```
## 8.6 Routing
Global and detailed routing were performed using the defined routing constraints.
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/cf7b5d0b0b338415478e792932ac3cda5f204772/screenshots/routing/routing_3.png)
Maximum routing layer:
```text
Metal 4 (met4)
```
Screenshots are available under:
```text
screenshots/routing/
```
# 8.7 Parasitic Extraction
Post-route parasitic information was extracted to account for interconnect effects during timing analysis.
## 9.8 GDSII Generation
The final physical design was streamed out as GDSII for final layout representation and verification.
The final layout screenshots are available under:
```text
screenshots/gdsII/
```
## 9. Static Timing Analysis
# 9.1 Pre-Route STA
Timing analysis was performed during the implementation flow to evaluate timing behavior at different stages.
# 9.2 Post-Route STA
Post-route timing analysis incorporated extracted parasitic effects for more realistic timing evaluation.
# 9.3 Setup Analysis
Setup timing was analyzed using the 20 ns clock constraint.
# 9.4 Hold Analysis
Hold timing was analyzed to identify minimum-delay violations after physical implementation.
# 9.5 WNS & TNS
The final reported timing results include:
* Setup WNS: **13.41 ns**
* Hold Worst Slack: **0.64 ns**
* TNS: **0.00 ns**
# 10.6 Critical Path
The reported critical path delay is: ```text 7.34 ns ```
The 20 ns clock period corresponds to a target frequency of: ```text 50 MHz ```
Timing screenshots are documented within the corresponding implementation-stage folders and final sign-off section.

## 10. Multi-Corner Analysis (MCA)
## 10.1 RC-Min
RC-Min analysis resulted in:
* Setup Slack: **6.88 ns**
* Hold Slack: **0.34 ns**
## 10.2 RC-Nom
RC-Nom analysis resulted in:
* Setup Slack: **6.75 ns**
* Hold Slack: **0.31 ns**
## 10.3 RC-Max
RC-Max analysis resulted in:
* Setup Slack: **6.61 ns**
* Hold Slack: **0.28 ns**
* 
## 10.4 MCA Results
| RC Corner | Setup Slack |  Hold Slack |
| --------- | ----------: | ----------: |
| RC-Min    | **6.88 ns** | **0.34 ns** |
| RC-Nom    | **6.75 ns** | **0.31 ns** |
| RC-Max    | **6.61 ns** | **0.28 ns** |
RC-Min :
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/69f0e35efb30390abc624680bb7fc5db172c7530/screenshots/multi_cornner_analysis/MCA_min.png)
RC-Nom :
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/dbd8bcac9a9cd0e19ba7138c12504c53aea0237c/screenshots/multi_cornner_analysis/MCA_nom.png)
RC-Max :
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/b39afc2996ac232ff0032d70aff91778dea5dc2f/screenshots/multi_cornner_analysis/MCA_max.png)

## 10.5 Timing Conclusion
The design maintained **positive setup and hold slack across all three analyzed RC corners**, with:
```text
TNS = 0.00 ns
```
MCA screenshots are available under:

```text
screenshots/multi_corner_analysis/
```
## 11. Power Analysis
## 11.1 Power Report
Post-route power analysis was performed as part of the final implementation evaluation.
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/53b9ec69a8421aea091857cef130965fda0a09c5/screenshots/signoff/signoff_power.png)
## 11.2 Total Power
The reported total power is: ```text 36.6 mW ```

## 11.3 Power Analysis Summary
| Parameter   |      Result |
| ----------- | ----------: |
| Total Power | **36.6 mW** |
Power analysis screenshots are available under:
```text
screenshots/signoff/
```
## 12. Physical Verification
## 12.1 DRC
Design Rule Checking was performed to verify compliance with the physical design rules.
**Result: 0 violations**
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/69c229fe74d738a4bbd0fa454e1ecc284b32ed4b/screenshots/signoff/signoff_drc.png)

## 12.2 LVS
Layout Versus Schematic verification was performed to compare the physical layout against the implemented design netlist.
**Result: 0 errors**
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/a031217dfc71db325e3d93102de974836b942788/screenshots/signoff/signoff_lvs.png)

## 12.3 Verification Results
| Verification |           Result |
| ------------ | ---------------: |
| DRC          | **0 violations** |
| LVS          |     **0 errors** |
The verification results indicate clean DRC and LVS for the reported implementation.

## 13. Final Sign-off Results
## 13.1 Area
| Parameter        |         Result |
| ---------------- | -------------: |
| Die Area         |   **1.00 mm²** |
| Core Area        | **0.9653 mm²** |
| Core Utilization |        **35%** |
| Total Cells      |     **25,520** |
## 13.2 Timing
| Parameter           |       Result |
| ------------------- | -----------: |
| Clock Period        |    **20 ns** |
| Clock Frequency     |   **50 MHz** |
| Critical Path Delay |  **7.34 ns** |
| Setup WNS           | **13.41 ns** |
| Hold Worst Slack    |  **0.64 ns** |
| TNS                 |  **0.00 ns** |
## 13.3 Power
| Parameter   |      Result |
| ----------- | ----------: |
| Total Power | **36.6 mW** |
## 13.4 DRC/LVS
| Check |           Result |
| ----- | ---------------: |
| DRC   | **0 violations** |
| LVS   |     **0 errors** |
## 13.5 MCA Summary
| RC Corner | Setup Slack |  Hold Slack |
| --------- | ----------: | ----------: |
| RC-Min    | **6.88 ns** | **0.34 ns** |
| RC-Nom    | **6.75 ns** | **0.31 ns** |
| RC-Max    | **6.61 ns** | **0.28 ns** |

## 14. Final Layout
## 14.1 GDSII
The final physical implementation was streamed out as a GDSII layout after completion of the RTL-to-GDSII flow.
![image alt](https://github.com/bvbhavana1/RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect/blob/d6cdb5a7abce6b5770d88a121ad5d95c90c7b3bf/screenshots/gdsII/gds1.png)
# 14.2 KLayout View
The generated layout was viewed and inspected using KLayout.
# 14.3 Final Physical Design
The final layout represents the completed physical implementation after:
```text
Floorplanning
→ Placement
→ CTS
→ Routing
→ Extraction
→ Timing Analysis
→ Physical Verification
→ GDSII Generation
```
Final layout screenshots are available under:
```text
screenshots/gdsII/
```
# 15. Tools & Technologies
### RTL & Verification
* Verilog HDL
* PicoRV32
* C/C++
* GTKWave
* Verilator
### Synthesis & Timing
* Yosys
* OpenSTA
### Physical Design
* OpenLane
* OpenROAD
* KLayout
* Magic
* Netgen
### Scripting
* Python
* Tcl
* Shell / Bash
## 16. Technology / PDK
The physical implementation was performed using: **SKY130 PDK**
The design was mapped to SKY130 standard-cell libraries during synthesis and physical implementation.

## 17.1 Yosys Synthesis
The synthesis scripts and generated reports are maintained under:
```text
screenshots/synthesis/
```
The design configuration is defined in:
```text
openlane/config.json
```
## 17.2 STA
Static Timing Analysis can be performed using OpenSTA with the generated netlist, timing libraries, constraints, and extracted parasitic information.
The main timing constraint is: ```text Clock Period = 20 ns ```

## 17.3 MCA
Multi-corner timing analysis evaluates the design under:
```text
RC-Min
RC-Nom
RC-Max
```
The resulting timing values are documented under:
```text
screenshots/multi_corner_analysis/
```
## 17.4 DRC/LVS
Physical verification is performed using the project's DRC and LVS flow.
Final reported results:
```text
DRC = 0 violations
LVS = 0 errors
```
# 18. Results & Conclusion
The project successfully demonstrates the implementation of a **RISC-V based SoC subsystem with AXI4-Lite connectivity**, progressing from RTL design and functional verification through synthesis and physical implementation to final GDSII generation.
### Final Results
```text
Die Area          = 1.00 mm²
Core Area         = 0.9653 mm²
Core Utilization  = 35%
Total Cells       = 25,520
Clock Period      = 20 ns
Clock Frequency   = 50 MHz
Critical Path     = 7.34 ns
Setup WNS         = 13.41 ns
Hold Slack        = 0.64 ns
TNS               = 0.00 ns
Total Power       = 36.6 mW
DRC               = 0 violations
LVS               = 0 errors
```
The design maintained positive setup and hold slack across the analyzed RC corners:
```text
RC-Min : Setup = 6.88 ns | Hold = 0.34 ns
RC-Nom : Setup = 6.75 ns | Hold = 0.31 ns
RC-Max : Setup = 6.61 ns | Hold = 0.28 ns
```
Overall, the project provided practical exposure to the complete **RTL-to-GDSII ASIC design flow**, including RISC-V architecture, AXI4-Lite integration, RTL verification, synthesis, physical design, timing analysis, power analysis, parasitic extraction, and physical verification.

## 21. Future Improvements
Potential future improvements include:
* Increasing the operating frequency.
* Optimizing area and power consumption.
* Improving AXI interconnect scalability.
* Adding additional AXI-based peripherals.
* Enhancing UART functionality.
* Adding interrupt-driven peripheral support.
* Exploring deeper RISC-V SoC integration.
* Performing more extensive functional and corner-case verification.
* Exploring further physical-design optimization for timing, area, and power.
# 22. References
* PicoRV32 RISC-V Processor
* AXI4-Lite specification and AMBA documentation
* OpenLane documentation
* OpenROAD documentation
* Yosys documentation
* OpenSTA documentation
* SKY130 PDK documentation
* KLayout documentation
* Verilator documentation

## 23. Acknowledgements
I sincerely thank **NIELIT, Ministry of Electronics & Information Technology (MeitY), eChipHub, and SoCTeamup Semiconductors** for providing the internship opportunity and hands-on exposure to the semiconductor design ecosystem.
I also thank my mentors and everyone who guided me throughout the internship and supported me during the implementation and debugging stages.
This internship provided valuable practical experience in **RTL Design, RISC-V, SoC Design, AXI4-Lite, ASIC Physical Design, Static Timing Analysis, and RTL-to-GDSII implementation**.

