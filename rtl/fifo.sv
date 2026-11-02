// 4-entry synchronous FIFO with embedded formal properties (SymbiYosys)
// Properties are only compiled when FORMAL is defined (read -formal).
module fifo #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,      // synchronous, active high
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             full,
    output logic             empty
);
    logic [WIDTH-1:0] mem [0:3];
    logic [1:0]       wr_ptr, rd_ptr;   // wrap around after slot 3
    logic [2:0]       count;            // 0..4

    assign full    = (count == 3'd4);
    assign empty   = (count == 3'd0);
    assign rd_data = mem[rd_ptr];

    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 2'd1;
            end
            if (do_read)
                rd_ptr <= rd_ptr + 2'd1;
            if (do_write && !do_read)
                count <= count + 3'd1;
            else if (do_read && !do_write)
                count <= count - 3'd1;
        end
    end

`ifdef FORMAL
    // ---- Setup: start in reset ----
    logic f_past_valid = 1'b0;
    always_ff @(posedge clk) f_past_valid <= 1'b1;
    always_comb if (!f_past_valid) assume (rst);

    always_ff @(posedge clk) begin
        if (f_past_valid && !$past(rst)) begin
            // P3: write while full is ignored (no overflow)
            if ($past(full) && $past(wr_en))
                assert (wr_ptr == $past(wr_ptr));
            // P4: read while empty is ignored (no underflow)
            if ($past(empty) && $past(rd_en))
                assert (rd_ptr == $past(rd_ptr));
            // P6: count follows the write/read rules exactly
            if ($past(do_write) && !$past(do_read))
                assert (count == $past(count) + 3'd1);
            else if ($past(do_read) && !$past(do_write))
                assert (count == $past(count) - 3'd1);
            else
                assert (count == $past(count));
            // P7: a successful write stores wr_data in the slot wr_ptr pointed to
            if ($past(do_write))
                assert (mem[$past(wr_ptr)] == $past(wr_data));
        end
        // P8: one cycle after reset the FIFO is empty
        if (f_past_valid && $past(rst))
            assert (empty && wr_ptr == 2'd0 && rd_ptr == 2'd0);
    end

    // P1, P2, P5: invariants that must hold in every state
    always_comb if (f_past_valid) begin
        assert (count <= 3'd4);                          // P1: count never exceeds depth
        assert (wr_ptr == rd_ptr + count[1:0]);          // P2: pointers and count agree
        assert (!(full && empty));                       // P5: never full and empty together
    end

    // ---- Cover: show the interesting states are reachable ----
    logic f_was_full = 1'b0;
    always_ff @(posedge clk)
        if (rst) f_was_full <= 1'b0; else if (full) f_was_full <= 1'b1;
    always_comb if (f_past_valid && !rst) begin
        cover (full);                                    // C1: FIFO can fill up
        cover (f_was_full && empty);                     // C2: fill completely, then drain to empty
    end
`endif
endmodule
