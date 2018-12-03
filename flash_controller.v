`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:55:26 11/26/2018 
// Design Name: 
// Module Name:    flash_controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module flash_controller(input wire clock, reset, ready,
			input wire [7:0]    din,
			output reg [7:0]    dout,
			input wire 	    start_read,
			input wire 	    start_write,
			inout wire [15:0]   flash_data,
			output wire [23:0]  flash_address,
			output wire 	    flash_ce_b,
			output wire 	    flash_oe_b,
			output wire 	    flash_we_b,
			output wire 	    flash_reset_b,
			output wire 	    flash_byte_b,
			input wire          flash_sts, 	    
			output wire [7:0]   d_led);

   // flash instatiations
   reg [15:0]  wdata;
   reg 	       writemode;
   reg 	       dowrite;
   reg [22:0]  raddr;
   wire [15:0] frdata;
   reg 	       doread;
   wire        busy;
   wire [11:0] fsmstate;
   wire        dots;
   reg         writing;
   reg         reading;
   wire        d_fsm_busy;
   //reg [4:0]   flash_counter=0;

   assign d_led = ~{1'b0, d_fsm_busy, doread, dowrite, writemode, busy, writing, reading};

   /*
   // fifo instantiations
   wire [7:0]  datausbout;
   wire        newout;
   reg 	       hold;
   reg 	       firstone=1;
   reg [7:0]   firstbyte;
   reg [15:0]  din_fifo;
   reg 	       wr_en_fifo=0;
   reg 	       rd_en_fifo=0;
   wire [15:0] dout_fifo;
   wire        full;

   // flash fifo
   fifo #(.LOGSIZE(16),.WIDTH(8))
   fifo(.clk(clock), .reset(reset), .rd(rd_en_fifo), .wr(wr_en_fifo), .din(din_fifo),
	.full(full), .empty(empty), .overflow(overflow), .dout(dout_fifo));
   */
   
   // flash module :o
   flash_manager flash(.clock(clock), .reset(reset), .dots(dots), .writemode(writemode),
		       .wdata(wdata), .dowrite(dowrite), .raddr(raddr), .frdata(frdata),
		       .doread(doread), .busy(busy), .flash_data(flash_data),
		       .flash_address(flash_address), .flash_ce_b(flash_ce_b),
		       .flash_oe_b(flash_oe_b), .flash_we_b(flash_we_b),
		       .flash_reset_b(flash_reset_b), .flash_sts(flash_sts),
		       .flash_byte_b(flash_byte_b), .fsmstate(fsmstate),
		       .d_fsm_busy(d_fsm_busy));

   // loop to transfer data from fifo into flash
   always @(posedge clock) begin
      if (start_read || start_write || reset) begin
	 writemode <= 1;
	 dowrite <= 0;
	 doread <= 0;
	 wdata <= 0;
	 raddr <= 0;
	 if (start_read) begin
	    reading <= 1;
	    writing <= 0;
	 end
	 if (start_write) begin
	    reading <= 0;
	    writing <= 1;
	 end
	 if (reset) begin
	    reading <= 0;
	    writing <= 0;
	 end
      end else begin
	 if (!busy && ready) begin
	    if (reading) begin
	       writemode <= 0;
	       doread <= 1;
	       dowrite <= 0;
	       dout <= frdata;
	       raddr <= raddr + 1;
	    end
	    if (writing) begin
	       writemode <= 1;
	       doread <= 0;
	       dowrite <= 1;
	       wdata <= din;
	    end
	 end else begin // busy
	    dowrite <= 0;
	    doread <= 0;
	 end
      end
   end

endmodule
