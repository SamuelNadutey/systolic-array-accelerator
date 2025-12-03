# Weight-Stationary Systolic Array for Edge AI 

![Status](https://img.shields.io/badge/Status-Verified-green) ![Language](https://img.shields.io/badge/Language-SystemVerilog-blue) ![Target](https://img.shields.io/badge/Target-Zynq--7000-orange)

This repository contains the RTL implementation of a **Parameterizable 2D Systolic Array Accelerator** designed to offload matrix multiplication tasks from general-purpose CPUs in resource-constrained environments. 

It is the hardware backend for the **[CropGuard Android App](https://github.com/SamuelNadutey/CropGuard-Android)**.

## ⚡ Architecture Highlights
* **Weight-Stationary Dataflow:** Minimizes off-chip memory access by maximizing weight reuse (Google TPU style architecture).
* **INT8 Quantization Support:** Optimized for quantized Convolutional Neural Networks (EfficientNet-B0).
* **DSP-Slice Inference:** MAC units designed to map directly to FPGA DSP48E1 slices.
* **Hardware Skewing:** Dedicated `skew_buffer` modules handle wavefront alignment, simplifying the software control layer.

## 📂 File Structure
* **`mac_pe.sv`**: Multiply-Accumulate Processing Element (The "Brain").
* **`systolic_array.sv`**: Parameterizable 2D Grid Interconnect.
* **`skew_buffer.sv`**: Data alignment and delay lines.
* **`accelerator_top.sv`**: Top-level wrapper with skewing logic.
* **`tb_accelerator.sv`**: Self-checking testbench with Golden Model verification.

## 📊 Performance Analysis

### Architectural Target (ASIC)
* **Process Node:** 28nm Commercial Flow
* **Target Frequency:** 850 MHz (Synthesis Target)
* **Throughput:** 1 MAC/cycle per PE
* **Logic Depth:** Optimized to < 10 gate delays per cycle.

### FPGA Prototype (Zynq-7000)
* **Status:** Functional Verification Complete (Behavioral Simulation).
* **Clock:** 100 MHz (Verified in Testbench).
* **Role:** Validates the systolic dataflow and control logic before ASIC synthesis.

## 👨‍💻 Author
**Partey Samuel Nadutey**
*Researching Hardware Acceleration for Edge AI*
