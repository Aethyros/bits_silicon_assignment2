# Synchronous FIFO & Verification Testbench



## Project Overview
This project implements a parameterizable Synchronous First-In-First-Out (FIFO) memory buffer in Verilog, designed to safely preserve data ordering across digital hardware pipelines. 

Alongside the RTL hardware implementation, this project features a robust, self-checking verification environment. The testbench utilizes a cycle-accurate Golden Reference Model and an automated Scoreboard to detect bugs without relying on manual waveform inspection.

---

## Directory Structure
| Directory | File | Description |
| :--- | :--- | :--- |
| `rtl/` | `sync_fifo_top.v` | Top-level wrapper module |
| `rtl/` | `sync_fifo.v` | Core FIFO hardware logic |
| `tb/` | `tb_sync_fifo.v` | Self-checking testbench |
| `docs/` | `README.md` | Project documentation |

---

## RTL Implementation Details (DUT)
The Device Under Test (DUT) is a synchronous FIFO where both read and write operations share the same clock (`clk`).

* **Parameters:** Fully parameterizable data width (`DATA_WIDTH`, default: 8) and depth (`DEPTH`, default: 16).
* **Memory Array:** Uses a register array to store incoming data words.
* **Pointers:** Read and write pointers automatically wrap back to `0` when reaching `DEPTH - 1`.
* **Occupancy Counter:** Tracks the exact number of elements currently stored in the FIFO.
* **Status Flags:** The `wr_full` and `rd_empty` flags are strictly derived from the internal occupancy counter.
* **Simultaneous Operations:** Safely handles concurrent read and write operations on the same clock cycle without corrupting the occupancy counter.

---

## Verification Strategy



The testbench (`tb_sync_fifo.v`) is designed for maximum automation and coverage tracking.

### 1. Golden Reference Model
Instead of hardcoding expected values, the testbench includes an independent, behavioral implementation of the FIFO. It maintains its own state variables (`model_mem`, `model_count`, `model_wr_ptr`, etc.) and computes the expected correct output for every clock cycle based purely on the applied inputs.

### 2. Automated Scoreboard
An automated scoreboard checks the DUT outputs against the Golden Model outputs. To eliminate delta-cycle race conditions, the stimulus is driven on the negative clock edge (`negedge clk`), and the scoreboard verifies the stabilized signals post-operation. It strictly compares:
* **Read Data** (`rd_data`)
* **Occupancy Count** (`count`)
* **Empty Flag** (`rd_empty`)
* **Full Flag** (`wr_full`)

If any mismatch is detected, the simulation prints a detailed diagnostic error message and terminates immediately.

### 3. Directed Tests
The sequence block executes the following deterministic tests to exercise all critical edge cases:
* **Reset Test:** Verifies pointers and count zero-out.
* **Single Read/Write Test:** Verifies basic data integrity.
* **Fill Test:** Writes continuously until capacity is reached.
* **Overflow Attempt Test:** Asserts write enable while full to verify state protection.
* **Drain Test:** Reads continuously until empty.
* **Underflow Attempt Test:** Asserts read enable while empty to verify state protection.
* **Simultaneous Read/Write Test:** Asserts both enables concurrently.
* **Pointer Wrap-Around Test:** Forces pointers to roll over the `DEPTH - 1` boundary.

### 4. Coverage Counters
Integer variables track how many times specific edge cases are hit during the simulation. The simulation concludes with a coverage summary, ensuring the following events were successfully exercised:
* `cov_full`: FIFO reached full capacity.
* `cov_empty`: FIFO became empty.
* `cov_wrap`: Pointers wrapped around.
* `cov_simul`: Concurrent read/write.
* `cov_overflow`: Attempted write while full.
* `cov_underflow`: Attempted read while empty.

---

## How to Run
1. Load the three `.v` files (`sync_fifo.v`, `sync_fifo_top.v`, and `tb_sync_fifo.v`) into your Verilog simulator of choice.
2. Set `tb_sync_fifo` as the top-level simulation module.
3. Run the simulation.
4. Check the console output. If the design is correct, the simulation will print `PASS` for all 8 directed tests, output the final Coverage Summary, and display `ALL COVERAGE METRICS SATISFIED! [PASS]`.
