// 4-entry synchronous FIFO with embedded formal properties (SymbiYosys)
// Properties are only compiled when FORMAL is defined (read -formal).
// Depth 4, 8-bit data. Count-based full/empty.
module fifo #(
  parameter DW = 8,              // data width
  parameter AW = 2               // address width -> depth = 2^AW = 4
) (
  input  wire          clk,
  input  wire          rst,      // synchronous, active high
  input  wire          wr_en,
  input  wire [DW-1:0] wr_data,
  input  wire          rd_en,
  output wire [DW-1:0] rd_data,
  output wire          full,
  output wire          empty
);
  localparam DEPTH = 1 << AW;

  reg [DW-1:0] mem [0:DEPTH-1];  // storage
  reg [AW-1:0] wr_ptr, rd_ptr;   // where to write / read next
  reg [AW:0]   count;            // 0..DEPTH, one extra bit

  // A write/read only really happens if there is room/data
  wire do_write = wr_en && !full;
  wire do_read  = rd_en && !empty;

  assign full    = (count == DEPTH);
  assign empty   = (count == 0);
  assign rd_data = mem[rd_ptr];

  always @(posedge clk) begin
    if (rst) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else begin
      if (do_write) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr      <= wr_ptr + 1;
      end
      if (do_read)
        rd_ptr <= rd_ptr + 1;

      case ({do_write, do_read})
        2'b10:   count <= count + 1;  // write only
        2'b01:   count <= count - 1;  // read only
        default: ;                    // both or neither: unchanged
      endcase
    end
  end

`ifdef FORMAL
  // ---------- setup ----------
  // f_past_valid is 0 in the first cycle, 1 afterwards
  reg f_past_valid = 0;
  always @(posedge clk) f_past_valid <= 1;

  // ASSUME: the design starts in reset
  always @(*) if (!f_past_valid) assume(rst);

  // ---------- properties ----------
  always @(*) if (f_past_valid) begin
    // P1: never overflow
    assert(count <= DEPTH);
    // P2: pointers and count agree
    assert(wr_ptr - rd_ptr == count[AW-1:0]);
  end

  always @(posedge clk) if (f_past_valid && !$past(rst)) begin
    // P3: a write into a full FIFO is ignored
    if ($past(full) && $past(wr_en) && !$past(rd_en))
      assert(count == $past(count));
    // P4: a read from an empty FIFO is ignored
    if ($past(empty) && $past(rd_en) && !$past(wr_en))
      assert(count == $past(count));
    // P5: after a real read, rd_ptr moves forward by one
    //     (2'd1 keeps the sum 2 bits wide, so 3 + 1 wraps to 0 like the hardware)
    if ($past(do_read))
      assert(rd_ptr == $past(rd_ptr) + 2'd1);
  end
`endif
endmodule
