`timescale 1ns / 1ps

module tb_sync_fifo;

    // 1. Parameters & Signals
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 16;
    parameter ADDR_WIDTH = 4; // Hardcoded to 4 to avoid system function synthesis issues in TB

    reg                   clk;
    reg                   rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire                  wr_full;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  rd_empty;
    wire [ADDR_WIDTH:0]   count;

    // 2. DUT Instantiation
    sync_fifo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_full(wr_full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_empty(rd_empty),
        .count(count)
    );

    // 3. Golden Reference Model Variables
    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    integer model_wr_ptr;
    integer model_rd_ptr;
    integer model_count;
    reg [DATA_WIDTH-1:0] model_rd_data;
    reg check_rd_data; // Flag to delay read validation by one cycle

    // 4. Manual Coverage Counters
    integer cov_full      = 0;
    integer cov_empty     = 0;
    integer cov_wrap      = 0;
    integer cov_simul     = 0;
    integer cov_overflow  = 0;
    integer cov_underflow = 0;

    integer cycle_counter = 0;

    // 5. Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period (100MHz)
    end

    // Cycle Tracker
    always @(posedge clk) begin
        cycle_counter <= cycle_counter + 1;
    end

    // 6. Golden Reference Model Logic
    always @(posedge clk) begin
        if(!rst_n) begin 
            model_wr_ptr  <= 0; 
            model_rd_ptr  <= 0;
            model_count   <= 0;
            model_rd_data <= 0;
            check_rd_data <= 0;
        end else begin
            // Flag to tell scoreboard to check data on the NEXT negedge
            check_rd_data <= (rd_en && (model_count > 0));

            // Track Coverage
            if (model_count == DEPTH) cov_full <= cov_full + 1;
            if (model_count == 0) cov_empty <= cov_empty + 1;
            if (wr_en && (model_count == DEPTH)) cov_overflow <= cov_overflow + 1;
            if (rd_en && (model_count == 0)) cov_underflow <= cov_underflow + 1;
            
            // Write 
            if (wr_en && (model_count < DEPTH))begin
                model_mem[model_wr_ptr] <= wr_data;
                if (model_wr_ptr == DEPTH - 1) begin model_wr_ptr <= 0; cov_wrap <= cov_wrap + 1; end
                else model_wr_ptr <= model_wr_ptr + 1;
            end
            
            // Read
            if (rd_en && (model_count > 0))begin
                model_rd_data <= model_mem[model_rd_ptr]; 
                if (model_rd_ptr == DEPTH - 1) begin model_rd_ptr <= 0; cov_wrap <= cov_wrap + 1; end
                else model_rd_ptr <= model_rd_ptr + 1;
            end
            
            // Update Count
            case({wr_en && (model_count < DEPTH), rd_en && (model_count > 0)})
                2'b10: model_count <= model_count + 1;
                2'b01: model_count <= model_count - 1;
                2'b11: cov_simul <= cov_simul + 1; // Implicit model_count remains unchanged
                default: model_count <= model_count;
            endcase
        end
    end

    // 7. Scoreboard
    // Using negedge to allow DUT signals to settle before comparing
    always @(negedge clk) begin
        if (rst_n) begin
            
            // Compare data (Only after a valid read occurred on the previous posedge)
            if (check_rd_data && (rd_data !== model_rd_data)) begin 
                $display("ERROR at cycle %0d", cycle_counter);
                $display("Time: %0t | Expected rd_data = %h, Got = %h", $time, model_rd_data, rd_data);
                $finish;
            end
            
            // Compare count
            if (model_count !== count)begin
                $display("ERROR at cycle %0d", cycle_counter);
                $display("Time: %0t | Expected count = %0d | Got = %0d", $time, model_count, count); 
                $finish;
            end

            // Compare Empty Flag
            if (rd_empty !== (model_count == 0)) begin
                $display("ERROR at cycle %0d | Empty flag mismatch", cycle_counter);
                $display("Time: %0t | Expected rd_empty = %b | Got = %b", $time, (model_count == 0), rd_empty);
                $finish;
            end
            
            // Compare Full Flag
            if (wr_full !== (model_count == DEPTH))begin
                $display("ERROR at cycle %0d | Full flag mismatch", cycle_counter);
                $display("Time: %0t | Expected wr_full = %b | Got = %b", $time, (model_count == DEPTH), wr_full);
                $finish;
            end
        end
    end

    // 8. Directed Test Sequences
    // Applying stimulus on the negedge ensures zero race conditions with the posedge logic
    integer i;

    initial begin
        // Initialize Inputs
        rst_n   = 0;
        wr_en   = 0;
        wr_data = 0;
        rd_en   = 0;

        // 1. Reset Test
        $display("Reset Test...");
        #15 rst_n = 1;
        #10;
        $display("PASS: Reset Test");

        // 2. Single Write/Read Test
        $display("Single Write/Read Test...");
        @(negedge clk); wr_en = 1; wr_data = 8'hAA;
        @(negedge clk); wr_en = 0;
        @(negedge clk); rd_en = 1;
        @(negedge clk); rd_en = 0;
        $display("PASS: Single Write/Read Test");

        // 3. Fill Test
        $display("Fill Test...");
        @(negedge clk); wr_en = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            wr_data = i;
            @(negedge clk);
        end
        wr_en = 0;
        $display("PASS: Fill Test");

        // 4. Overflow Test
        $display("Overflow Test...");
        @(negedge clk); wr_en = 1; wr_data = 8'hFF;
        @(negedge clk); wr_en = 0;
        $display("PASS: Overflow Test");

        // 5. Drain Test
        $display("Drain Test...");
        @(negedge clk); rd_en = 1; 
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
        end
        rd_en = 0;
        $display("PASS: Drain Test");

        // 6. Underflow Attempt Test
        $display("Underflow Attempt Test...");
        @(negedge clk); rd_en = 1; 
        @(negedge clk); rd_en = 0;
        $display("PASS: Underflow Attempt Test");

        // 7. Simultaneous Read and Write Test
        $display("Starting Simultaneous Read/Write Test...");
        // Write one value first so it's not empty
        @(negedge clk); wr_en = 1; wr_data = 8'h11;
        @(negedge clk);
        // Now read and write at the same time
        wr_data = 8'h22; rd_en = 1; 
        @(negedge clk); wr_en = 0; rd_en = 0;
        $display("PASS: Simultaneous Read/Write Test");

        // 8. Pointer Wrap-Around Test
        $display("Starting Pointer Wrap-Around Test...");
        // Fill completely
        @(negedge clk); wr_en = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            wr_data = i * 2;
            @(negedge clk);
        end
        wr_en = 0;
        // Drain completely
        @(negedge clk); rd_en = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
        end
        rd_en = 0;
        $display("PASS: Pointer Wrap-Around Test");

        // 9. Coverage Summary
        #20; 
        $display("\n==================================");
        $display("       SIMULATION COMPLETE        ");
        $display("==================================");
        $display("Coverage Summary:");
        $display("Full States Hit:      %0d", cov_full);
        $display("Empty States Hit:     %0d", cov_empty);
        $display("Pointer Wraps:        %0d", cov_wrap);
        $display("Simultaneous R/W:     %0d", cov_simul);
        $display("Overflow Attempts:    %0d", cov_overflow);
        $display("Underflow Attempts:   %0d", cov_underflow);

        if (cov_full && cov_empty && cov_wrap && cov_simul && cov_overflow && cov_underflow)
            $display("\nALL COVERAGE METRICS SATISFIED! [PASS]");
        else
            $display("\nWARNING: Some coverage metrics are zero! [FAIL]");

        $finish;

    end
endmodule
