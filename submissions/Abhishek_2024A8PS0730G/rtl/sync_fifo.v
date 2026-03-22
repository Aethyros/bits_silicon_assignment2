module sync_fifo#(
parameter integer DATA_WIDTH = 8,
parameter integer DEPTH = 16,
parameter ADDR_WIDTH = $clog2(DEPTH)
)(
input wire 			clk,
input wire 			rst_n, 	//active-low synchronus reset

input wire 			wr_en,
input wire [DATA_WIDTH-1:0]	wr_data,
output wire			wr_full,

input wire			rd_en,
output reg [DATA_WIDTH-1:0]	rd_data,
output wire			rd_empty,

output wire [ADDR_WIDTH:0]	count
);

	
	// 1. Internal Hardware Structure
    	reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    	reg [ADDR_WIDTH-1:0] wr_ptr;
    	reg [ADDR_WIDTH-1:0] rd_ptr;
	reg [ADDR_WIDTH:0] count_reg;


    	// 2. Full and empty flags derived from the occupancy counter
    	assign rd_empty = (count_reg == 0);
    	assign wr_full  = (count_reg == DEPTH);
	assign count = count_reg;

	// 3.Synchronus Logic
	always @(posedge clk) begin
		// 1. Reset behaviour
		if(!rst_n) begin
			wr_ptr  <= 0;
            		rd_ptr  <= 0;
            		count_reg   <= 0;
		end else begin

			// 2.Write Operation Only
			if(wr_en && !wr_full) begin 
				mem[wr_ptr] <= wr_data;
				wr_ptr <= (wr_ptr == DEPTH-1)? 0 : wr_ptr + 1;
			end

			// 3.Read Operation Only
			 if(rd_en && !rd_empty) begin
				rd_data <= mem[rd_ptr];
				rd_ptr <= (rd_ptr == DEPTH-1)? 0 : rd_ptr + 1;
			end
			
			// 4. Updating Count_Reg
			case({wr_en && !wr_full, rd_en && !rd_empty})
				2'b10: count_reg <= count_reg + 1; // write only
				2'b01: count_reg <= count_reg - 1; // read only
				default: count_reg <= count_reg;
			endcase
			
		end
	end

endmodule
