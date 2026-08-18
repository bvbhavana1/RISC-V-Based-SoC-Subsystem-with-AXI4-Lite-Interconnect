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
Configuration: 1 AXI4-Lite Master → 3 AXI4-Lite Slaves

Memory Map:

Component	Function	Base Address
PicoRV32	RISC-V processing core	—
ROM	Program / instruction memory	0x0000_0000
SRAM	Read/write data memory	0x0001_0000
UART	Serial communication peripheral	0x1000_0000
