# Formal verification of a 4-entry synchronous FIFO (SVA + SymbiYosys)

![formal](../../actions/workflows/formal.yml/badge.svg)

A small synchronous FIFO in SystemVerilog, formally verified with SystemVerilog
assertions using the open-source SymbiYosys (SBY) flow.
All 8 properties pass a **full proof by k-induction** (`mode prove`), and both cover goals are reached.

## Design
- Depth 4, `WIDTH` = 8 (parameter)
- Ports: `clk`, `rst` (sync, active high), `wr_en`, `wr_data`, `rd_en`, `rd_data`, `full`, `empty`
- State: `mem[4]`, 2-bit `wr_ptr` / `rd_ptr` (wrap around), 3-bit `count`
- Write when `wr_en && !full`, read when `rd_en && !empty`; read + write in the same cycle keeps `count`
- `full = (count == 4)`, `empty = (count == 0)`, `rd_data = mem[rd_ptr]`

## Properties
| ID | Property in plain English | Kind |
|----|---------------------------|------|
| P1 | `count` never exceeds the depth (4) | invariant |
| P2 | Pointers and count agree: `wr_ptr == rd_ptr + count` (mod 4) | invariant |
| P3 | A write while `full` is ignored: `wr_ptr` does not move (no overflow) | assert |
| P4 | A read while `empty` is ignored: `rd_ptr` does not move (no underflow) | assert |
| P5 | `full` and `empty` are never 1 together | invariant |
| P6 | `count` changes by exactly +1 / −1 / 0 according to the read/write rules | assert |
| P7 | A successful write stores `wr_data` in the slot `wr_ptr` pointed to | assert |
| P8 | One cycle after reset the FIFO is empty with both pointers at 0 | assert |
| C1 | The FIFO can become full | cover |
| C2 | The FIFO can fill completely and then drain back to empty | cover |

The properties are in `rtl/fifo.sv` inside `` `ifdef FORMAL `` so they never reach synthesis.

## Results
```
[fifo_prove] engine_0 (smtbmc z3) returned pass for basecase
[fifo_prove] engine_0 (smtbmc z3) returned pass for induction
[fifo_prove] successful proof by k-induction.
[fifo_cover] reached cover statement C1 at step 5, C2 at step 9
```

### Do the properties catch bugs? (mutation check)
I removed the `!full` guard from the write logic (`do_write = wr_en`).
The proof then **fails** at P1 (count exceeds 4) with a counterexample trace, so the
properties catch an overflow bug.

## How to run
```bash
# needs OSS CAD Suite (yosys + sby + z3)
cd formal
sby -f fifo.sby          # runs both tasks: prove and cover
```
GitHub Actions runs the same job on every push (`.github/workflows/formal.yml`).

## What I learned
- <1–3 lines in your own words>

## Files
- `rtl/fifo.sv`: RTL + embedded formal properties
- `formal/fifo.sby`: SymbiYosys job (tasks: prove, cover)
