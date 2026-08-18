# RISC-V-Based-SoC-Subsystem-with-AXI4-Lite-Interconnect for Embedded Applications
## 🚀 Complete RTL-to-GDSII ASIC Implementation | RISC-V | SoC | AXI4-Lite | SKY130

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

##⏱️ Multi-Corner Timing Results
The design was evaluated under three RC extraction conditions to analyze timing robustness.
| RC Corner  | Setup Slack |  Hold Slack |
| ---------- | ----------: | ----------: |
| **RC-Min** | **6.88 ns** | **0.34 ns** |
| **RC-Nom** | **6.75 ns** | **0.31 ns** |
| **RC-Max** | **6.61 ns** | **0.28 ns** |

## RTL-to-GDSII Flow
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

  
