# Formal verification of a 4-entry synchronous FIFO (SVA + SymbiYosys)

A small synchronous FIFO in Verilog, formally verified with immediate assertions
using the open-source SymbiYosys (SBY) flow. All five properties pass a
**full proof by k-induction** (`mode prove`): they hold in every reachable state,
for every possible input sequence, with no testbench.

## Design
- Depth 4, data width 8 (parameters `AW = 2`, `DW = 8`)
- Ports: `clk`, `rst` (synchronous, active high), `wr_en`, `wr_data`, `rd_en`, `rd_data`, `full`, `empty`
- State: `mem[4]`, 2-bit `wr_ptr` / `rd_ptr` (wrap around after slot 3), 3-bit `count` (0 to 4)
- A write only happens when `wr_en && !full`, a read only when `rd_en && !empty`;
  read and write in the same cycle leave `count` unchanged
- `full = (count == 4)`, `empty = (count == 0)`, `rd_data = mem[rd_ptr]`

## Properties
| ID | Property in plain English | Kind |
|----|---------------------------|------|
| P1 | `count` never exceeds the depth (4) | invariant |
| P2 | Pointers and count agree: `wr_ptr - rd_ptr == count` (mod 4) | invariant |
| P3 | A write into a full FIFO is ignored: `count` does not change | assert |
| P4 | A read from an empty FIFO is ignored: `count` does not change | assert |
| P5 | After a real read, `rd_ptr` moves forward by exactly one (wrapping 3 → 0) | assert |

Setup: the proof starts in reset (`assume(rst)` in the first cycle), and
`f_past_valid` guards every `$past()` so no check looks before cycle 0.
The properties are in `rtl/fifo.sv` inside `` `ifdef FORMAL `` so they never reach synthesis.

## Results
```
engine_0 (smtbmc) returned pass for basecase
engine_0 (smtbmc) returned pass for induction
successful proof by k-induction.
DONE (PASS, rc=0)
```

### Do the properties catch bugs? (mutation checks)
| Planted bug | Result |
|-------------|--------|
| Removed the full check: `do_write = wr_en` | **FAIL at P1** after 6 cycles. The counterexample trace shows 5 writes after reset: `count` reaches 4, `full` goes high, one more write makes `count` 5 and `full` drops back to 0, so the FIFO would start overwriting unread data. |
| Removed the empty check: `do_read = rd_en` | **FAIL at P1**. A read from an empty FIFO makes the 3-bit `count` underflow from 0 to 7, so the FIFO reports 7 entries of stale data. |

## How to run
```bash
# needs OSS CAD Suite (yosys + sby + solvers)
cd formal
sby -f fifo.sby
# on FAIL, view the counterexample:
gtkwave fifo/engine_0/trace.vcd
```

## What I learned
- How a formal tool turns RTL into a SAT/SMT problem, and how basecase (bounded check from reset) and induction together give a proof for all time. This connects to the BDD and DPLL SAT solver work from my Verification of Digital Systems course.
- Reading counterexample traces in GTKWave to find the exact cycle where a property breaks.
- A FAIL can be a bug in the property, not the design: my first version of P5 used `$past(rd_ptr) + 1`. Verilog sizes that expression to 32 bits, so 3 + 1 = 4 never wraps to 0 and the assertion failed even though the hardware was correct. Using `2'd1` keeps the arithmetic 2 bits wide.

## Files
- `rtl/fifo.sv`: RTL + embedded formal properties
- `formal/fifo.sby`: SymbiYosys job
