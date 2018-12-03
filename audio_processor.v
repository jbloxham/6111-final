`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:29:44 11/28/2018 
// Design Name: 
// Module Name:    audio_processor 
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
module audio_processor(
    input 	  clock,
    input 	  reset,
    input 	  ready,
    input [7:0]   x,
    output [7:0]  y,
    output 	  beat,
    output [31:0] d
    );

   wire [7:0] 	 filter_in;
   wire [23:0] 	 filter_out;
   wire [31:0] 	 enf_out;
   wire 	 peaks_out;
      
   fir31 filter(.clock(clock), .reset(reset), .ready(ready), .x(filter_in), .y(filter_out));
   enf enf(.clock(clock), .reset(reset), .ready(ready), .x(filter_out[23:16]), .y(enf_out));
   peaks peaks(.clock(clock), .reset(reset), .ready(ready), .x(enf_out), .y(peaks_out));

   assign d = {enf_out[31:1], peaks_out};
   assign beat = peaks_out;
      
   // todo: get energy over a moving window!
   // try N ~ 5000, H ~ 2500
   // then: get enf by subtracting adjacent signals
   // then: plot and ponder next move
   
   assign filter_in = x;
   assign y = filter_out[23:16];

endmodule // audio_processor

module enf(input wire clock,reset,ready,
	   input wire signed [7:0]   x,
	   output wire signed [31:0] y);
   
   reg signed [31:0] pos_acc;
   reg signed [31:0] neg_acc;
   reg signed [15:0] pos_sample [2047:0];
   reg signed [15:0] neg_sample [2047:0];
   reg signed [41:0] diff_acc;
   reg signed [31:0] diff_sample [2047:0];
   reg [10:0] 	     index;
   
   always @(posedge clock) begin
      if (reset) begin
	 pos_acc <= 0;
	 neg_acc <= 0;
	 diff_acc <= 0;
	 index <= 0;
      end else if (ready) begin
	 neg_acc <= neg_acc - neg_sample[index] + pos_sample[index];
	 pos_acc <= pos_acc - pos_sample[index] + x * x;
	 pos_sample[index] <= x * x;
	 neg_sample[index] <= pos_sample[index];
	 diff_acc <= diff_acc + pos_acc - neg_acc - diff_sample[index];
	 diff_sample[index] <= pos_acc - neg_acc;
	 index <= index + 11'b1;
      end
   end // always @ (posedge clock)

   wire signed [31:0] clipped;
   assign clipped = diff_acc[41:10];
   assign y = clipped < 0 ? 32'b0 : clipped;
endmodule // enf

module peaks(input wire clock,reset,ready,
	     input wire [31:0] x,
	     output reg        y);

   reg [31:0] maxval;
   reg [31:0] prev [1:0];
   reg [12:0] lastpeak;
   wire       ispeak;
   assign ispeak = (prev[1] < prev[0]) && (prev[0] >= x) && (prev[0] > (maxval >> 3)) && lastpeak == 13'b0;
   always @(posedge clock) begin
      if (reset) begin
	 maxval <= 32'b0;
	 lastpeak <= 13'b0;
      end else if (ready) begin
	 y <= ispeak;
	 if (ispeak) lastpeak <= 13'h1FFF;
	 if (lastpeak > 0) lastpeak <= lastpeak - 1;
	 prev[1] <= prev[0];
	 prev[0] <= x;
	 if (x > maxval) maxval <= x;
      end
   end
endmodule // peaks

// filter code shamelessly copied and modified from lab 5 :)

///////////////////////////////////////////////////////////////////////////////
//
// 31-tap FIR filter, 8-bit signed data, 10-bit signed coefficients.
// ready is asserted whenever there is a new sample on the X input,
// the Y output should also be sampled at the same time.  Assumes at
// least 32 clocks between ready assertions.  Note that since the
// coefficients have been scaled by 2**10, so has the output (it's
// expanded from 8 bits to 18 bits).  To get an 8-bit result from the
// filter just divide by 2**10, ie, use Y[17:10].
//
///////////////////////////////////////////////////////////////////////////////
module fir31(
  input wire clock,reset,ready,
  input wire signed [7:0] x,
  output reg signed [23:0] y
);

   reg signed [7:0] 	   sample [511:0];
   reg [8:0] 		   offset;
   reg [8:0] 		   index;
   reg signed [23:0] 	   acc;
   wire signed [15:0] 	   coeff;
   integer 		   i;
	
   coeffs31 c(.index(index), .coeff(coeff));

   // for now just pass data through
   always @(posedge clock) begin
      if (reset) begin
	 offset <= 0;
	 /*for (i=0; i<512; i=i+1) begin
	    sample[i] <= 0; // init samples to 0
	 end*/
      end else if (ready) begin
	 // put x into offset+1 slot, because we
	 // are about to increment offset
	 sample[offset + 9'd1] <= x;
	 offset <= offset + 1;
	 index <= 0;
	 acc <= 0;
      end else begin 
	 if (index < 9'd511) begin
	    // do the calculation
	    acc <= acc + coeff * sample[offset - index];
	    index <= index + 1;
	 end else
	   y <= acc;
      end
   end
endmodule

///////////////////////////////////////////////////////////////////////////////
//
// Coefficients for a 31-tap low-pass FIR filter with Wn=.125 (eg, 3kHz for a
// 48kHz sample rate).  Since we're doing integer arithmetic, we've scaled
// the coefficients by 2**10
// Matlab command: round(fir1(30,.125)*1024)
//
///////////////////////////////////////////////////////////////////////////////

module coeffs31(
  input wire [8:0] index,
  output reg signed [15:0] coeff
);
  // tools will turn this into a 31x10 ROM
  always @(index)
    case (index)
      // coeffs = np.round(firwin(511, 500, nyq=24000) * 2**16)
      // 500 Hz low pass filter
      9'd0: coeff = -16'sd5;
      9'd1: coeff = -16'sd5;
      9'd2: coeff = -16'sd5;
      9'd3: coeff = -16'sd5;
      9'd4: coeff = -16'sd4;
      9'd5: coeff = -16'sd4;
      9'd6: coeff = -16'sd4;
      9'd7: coeff = -16'sd3;
      9'd8: coeff = -16'sd3;
      9'd9: coeff = -16'sd3;
      9'd10: coeff = -16'sd2;
      9'd11: coeff = -16'sd2;
      9'd12: coeff = -16'sd1;
      9'd13: coeff = -16'sd1;
      9'd14: coeff = 16'sd0;
      9'd15: coeff = 16'sd0;
      9'd16: coeff = 16'sd1;
      9'd17: coeff = 16'sd1;
      9'd18: coeff = 16'sd2;
      9'd19: coeff = 16'sd2;
      9'd20: coeff = 16'sd3;
      9'd21: coeff = 16'sd3;
      9'd22: coeff = 16'sd4;
      9'd23: coeff = 16'sd4;
      9'd24: coeff = 16'sd5;
      9'd25: coeff = 16'sd6;
      9'd26: coeff = 16'sd6;
      9'd27: coeff = 16'sd7;
      9'd28: coeff = 16'sd7;
      9'd29: coeff = 16'sd8;
      9'd30: coeff = 16'sd9;
      9'd31: coeff = 16'sd9;
      9'd32: coeff = 16'sd10;
      9'd33: coeff = 16'sd10;
      9'd34: coeff = 16'sd11;
      9'd35: coeff = 16'sd11;
      9'd36: coeff = 16'sd12;
      9'd37: coeff = 16'sd12;
      9'd38: coeff = 16'sd12;
      9'd39: coeff = 16'sd13;
      9'd40: coeff = 16'sd13;
      9'd41: coeff = 16'sd13;
      9'd42: coeff = 16'sd13;
      9'd43: coeff = 16'sd14;
      9'd44: coeff = 16'sd14;
      9'd45: coeff = 16'sd14;
      9'd46: coeff = 16'sd14;
      9'd47: coeff = 16'sd13;
      9'd48: coeff = 16'sd13;
      9'd49: coeff = 16'sd13;
      9'd50: coeff = 16'sd13;
      9'd51: coeff = 16'sd12;
      9'd52: coeff = 16'sd12;
      9'd53: coeff = 16'sd11;
      9'd54: coeff = 16'sd10;
      9'd55: coeff = 16'sd9;
      9'd56: coeff = 16'sd9;
      9'd57: coeff = 16'sd8;
      9'd58: coeff = 16'sd7;
      9'd59: coeff = 16'sd5;
      9'd60: coeff = 16'sd4;
      9'd61: coeff = 16'sd3;
      9'd62: coeff = 16'sd1;
      9'd63: coeff = 16'sd0;
      9'd64: coeff = -16'sd2;
      9'd65: coeff = -16'sd3;
      9'd66: coeff = -16'sd5;
      9'd67: coeff = -16'sd7;
      9'd68: coeff = -16'sd8;
      9'd69: coeff = -16'sd10;
      9'd70: coeff = -16'sd12;
      9'd71: coeff = -16'sd14;
      9'd72: coeff = -16'sd16;
      9'd73: coeff = -16'sd18;
      9'd74: coeff = -16'sd20;
      9'd75: coeff = -16'sd22;
      9'd76: coeff = -16'sd23;
      9'd77: coeff = -16'sd25;
      9'd78: coeff = -16'sd27;
      9'd79: coeff = -16'sd29;
      9'd80: coeff = -16'sd31;
      9'd81: coeff = -16'sd32;
      9'd82: coeff = -16'sd34;
      9'd83: coeff = -16'sd35;
      9'd84: coeff = -16'sd36;
      9'd85: coeff = -16'sd38;
      9'd86: coeff = -16'sd39;
      9'd87: coeff = -16'sd40;
      9'd88: coeff = -16'sd40;
      9'd89: coeff = -16'sd41;
      9'd90: coeff = -16'sd41;
      9'd91: coeff = -16'sd42;
      9'd92: coeff = -16'sd42;
      9'd93: coeff = -16'sd42;
      9'd94: coeff = -16'sd41;
      9'd95: coeff = -16'sd41;
      9'd96: coeff = -16'sd40;
      9'd97: coeff = -16'sd39;
      9'd98: coeff = -16'sd38;
      9'd99: coeff = -16'sd36;
      9'd100: coeff = -16'sd34;
      9'd101: coeff = -16'sd32;
      9'd102: coeff = -16'sd30;
      9'd103: coeff = -16'sd28;
      9'd104: coeff = -16'sd25;
      9'd105: coeff = -16'sd22;
      9'd106: coeff = -16'sd19;
      9'd107: coeff = -16'sd15;
      9'd108: coeff = -16'sd12;
      9'd109: coeff = -16'sd8;
      9'd110: coeff = -16'sd4;
      9'd111: coeff = 16'sd0;
      9'd112: coeff = 16'sd4;
      9'd113: coeff = 16'sd9;
      9'd114: coeff = 16'sd13;
      9'd115: coeff = 16'sd18;
      9'd116: coeff = 16'sd23;
      9'd117: coeff = 16'sd28;
      9'd118: coeff = 16'sd33;
      9'd119: coeff = 16'sd38;
      9'd120: coeff = 16'sd43;
      9'd121: coeff = 16'sd48;
      9'd122: coeff = 16'sd53;
      9'd123: coeff = 16'sd57;
      9'd124: coeff = 16'sd62;
      9'd125: coeff = 16'sd67;
      9'd126: coeff = 16'sd71;
      9'd127: coeff = 16'sd76;
      9'd128: coeff = 16'sd80;
      9'd129: coeff = 16'sd84;
      9'd130: coeff = 16'sd87;
      9'd131: coeff = 16'sd91;
      9'd132: coeff = 16'sd94;
      9'd133: coeff = 16'sd97;
      9'd134: coeff = 16'sd99;
      9'd135: coeff = 16'sd101;
      9'd136: coeff = 16'sd103;
      9'd137: coeff = 16'sd104;
      9'd138: coeff = 16'sd105;
      9'd139: coeff = 16'sd105;
      9'd140: coeff = 16'sd105;
      9'd141: coeff = 16'sd104;
      9'd142: coeff = 16'sd103;
      9'd143: coeff = 16'sd101;
      9'd144: coeff = 16'sd99;
      9'd145: coeff = 16'sd96;
      9'd146: coeff = 16'sd93;
      9'd147: coeff = 16'sd89;
      9'd148: coeff = 16'sd84;
      9'd149: coeff = 16'sd79;
      9'd150: coeff = 16'sd73;
      9'd151: coeff = 16'sd67;
      9'd152: coeff = 16'sd61;
      9'd153: coeff = 16'sd53;
      9'd154: coeff = 16'sd46;
      9'd155: coeff = 16'sd37;
      9'd156: coeff = 16'sd29;
      9'd157: coeff = 16'sd20;
      9'd158: coeff = 16'sd10;
      9'd159: coeff = 16'sd0;
      9'd160: coeff = -16'sd10;
      9'd161: coeff = -16'sd21;
      9'd162: coeff = -16'sd32;
      9'd163: coeff = -16'sd43;
      9'd164: coeff = -16'sd54;
      9'd165: coeff = -16'sd66;
      9'd166: coeff = -16'sd78;
      9'd167: coeff = -16'sd89;
      9'd168: coeff = -16'sd101;
      9'd169: coeff = -16'sd113;
      9'd170: coeff = -16'sd124;
      9'd171: coeff = -16'sd136;
      9'd172: coeff = -16'sd147;
      9'd173: coeff = -16'sd158;
      9'd174: coeff = -16'sd169;
      9'd175: coeff = -16'sd179;
      9'd176: coeff = -16'sd189;
      9'd177: coeff = -16'sd198;
      9'd178: coeff = -16'sd207;
      9'd179: coeff = -16'sd215;
      9'd180: coeff = -16'sd223;
      9'd181: coeff = -16'sd229;
      9'd182: coeff = -16'sd235;
      9'd183: coeff = -16'sd240;
      9'd184: coeff = -16'sd244;
      9'd185: coeff = -16'sd248;
      9'd186: coeff = -16'sd250;
      9'd187: coeff = -16'sd251;
      9'd188: coeff = -16'sd251;
      9'd189: coeff = -16'sd250;
      9'd190: coeff = -16'sd247;
      9'd191: coeff = -16'sd244;
      9'd192: coeff = -16'sd239;
      9'd193: coeff = -16'sd233;
      9'd194: coeff = -16'sd225;
      9'd195: coeff = -16'sd216;
      9'd196: coeff = -16'sd206;
      9'd197: coeff = -16'sd194;
      9'd198: coeff = -16'sd181;
      9'd199: coeff = -16'sd166;
      9'd200: coeff = -16'sd151;
      9'd201: coeff = -16'sd133;
      9'd202: coeff = -16'sd114;
      9'd203: coeff = -16'sd94;
      9'd204: coeff = -16'sd73;
      9'd205: coeff = -16'sd50;
      9'd206: coeff = -16'sd26;
      9'd207: coeff = 16'sd0;
      9'd208: coeff = 16'sd27;
      9'd209: coeff = 16'sd55;
      9'd210: coeff = 16'sd84;
      9'd211: coeff = 16'sd114;
      9'd212: coeff = 16'sd146;
      9'd213: coeff = 16'sd178;
      9'd214: coeff = 16'sd212;
      9'd215: coeff = 16'sd246;
      9'd216: coeff = 16'sd281;
      9'd217: coeff = 16'sd317;
      9'd218: coeff = 16'sd354;
      9'd219: coeff = 16'sd391;
      9'd220: coeff = 16'sd429;
      9'd221: coeff = 16'sd467;
      9'd222: coeff = 16'sd505;
      9'd223: coeff = 16'sd544;
      9'd224: coeff = 16'sd583;
      9'd225: coeff = 16'sd622;
      9'd226: coeff = 16'sd661;
      9'd227: coeff = 16'sd699;
      9'd228: coeff = 16'sd738;
      9'd229: coeff = 16'sd776;
      9'd230: coeff = 16'sd814;
      9'd231: coeff = 16'sd851;
      9'd232: coeff = 16'sd887;
      9'd233: coeff = 16'sd923;
      9'd234: coeff = 16'sd958;
      9'd235: coeff = 16'sd992;
      9'd236: coeff = 16'sd1025;
      9'd237: coeff = 16'sd1057;
      9'd238: coeff = 16'sd1088;
      9'd239: coeff = 16'sd1118;
      9'd240: coeff = 16'sd1146;
      9'd241: coeff = 16'sd1173;
      9'd242: coeff = 16'sd1198;
      9'd243: coeff = 16'sd1221;
      9'd244: coeff = 16'sd1243;
      9'd245: coeff = 16'sd1264;
      9'd246: coeff = 16'sd1282;
      9'd247: coeff = 16'sd1299;
      9'd248: coeff = 16'sd1314;
      9'd249: coeff = 16'sd1327;
      9'd250: coeff = 16'sd1338;
      9'd251: coeff = 16'sd1347;
      9'd252: coeff = 16'sd1354;
      9'd253: coeff = 16'sd1359;
      9'd254: coeff = 16'sd1363;
      9'd255: coeff = 16'sd1364;
      9'd256: coeff = 16'sd1363;
      9'd257: coeff = 16'sd1359;
      9'd258: coeff = 16'sd1354;
      9'd259: coeff = 16'sd1347;
      9'd260: coeff = 16'sd1338;
      9'd261: coeff = 16'sd1327;
      9'd262: coeff = 16'sd1314;
      9'd263: coeff = 16'sd1299;
      9'd264: coeff = 16'sd1282;
      9'd265: coeff = 16'sd1264;
      9'd266: coeff = 16'sd1243;
      9'd267: coeff = 16'sd1221;
      9'd268: coeff = 16'sd1198;
      9'd269: coeff = 16'sd1173;
      9'd270: coeff = 16'sd1146;
      9'd271: coeff = 16'sd1118;
      9'd272: coeff = 16'sd1088;
      9'd273: coeff = 16'sd1057;
      9'd274: coeff = 16'sd1025;
      9'd275: coeff = 16'sd992;
      9'd276: coeff = 16'sd958;
      9'd277: coeff = 16'sd923;
      9'd278: coeff = 16'sd887;
      9'd279: coeff = 16'sd851;
      9'd280: coeff = 16'sd814;
      9'd281: coeff = 16'sd776;
      9'd282: coeff = 16'sd738;
      9'd283: coeff = 16'sd699;
      9'd284: coeff = 16'sd661;
      9'd285: coeff = 16'sd622;
      9'd286: coeff = 16'sd583;
      9'd287: coeff = 16'sd544;
      9'd288: coeff = 16'sd505;
      9'd289: coeff = 16'sd467;
      9'd290: coeff = 16'sd429;
      9'd291: coeff = 16'sd391;
      9'd292: coeff = 16'sd354;
      9'd293: coeff = 16'sd317;
      9'd294: coeff = 16'sd281;
      9'd295: coeff = 16'sd246;
      9'd296: coeff = 16'sd212;
      9'd297: coeff = 16'sd178;
      9'd298: coeff = 16'sd146;
      9'd299: coeff = 16'sd114;
      9'd300: coeff = 16'sd84;
      9'd301: coeff = 16'sd55;
      9'd302: coeff = 16'sd27;
      9'd303: coeff = 16'sd0;
      9'd304: coeff = -16'sd26;
      9'd305: coeff = -16'sd50;
      9'd306: coeff = -16'sd73;
      9'd307: coeff = -16'sd94;
      9'd308: coeff = -16'sd114;
      9'd309: coeff = -16'sd133;
      9'd310: coeff = -16'sd151;
      9'd311: coeff = -16'sd166;
      9'd312: coeff = -16'sd181;
      9'd313: coeff = -16'sd194;
      9'd314: coeff = -16'sd206;
      9'd315: coeff = -16'sd216;
      9'd316: coeff = -16'sd225;
      9'd317: coeff = -16'sd233;
      9'd318: coeff = -16'sd239;
      9'd319: coeff = -16'sd244;
      9'd320: coeff = -16'sd247;
      9'd321: coeff = -16'sd250;
      9'd322: coeff = -16'sd251;
      9'd323: coeff = -16'sd251;
      9'd324: coeff = -16'sd250;
      9'd325: coeff = -16'sd248;
      9'd326: coeff = -16'sd244;
      9'd327: coeff = -16'sd240;
      9'd328: coeff = -16'sd235;
      9'd329: coeff = -16'sd229;
      9'd330: coeff = -16'sd223;
      9'd331: coeff = -16'sd215;
      9'd332: coeff = -16'sd207;
      9'd333: coeff = -16'sd198;
      9'd334: coeff = -16'sd189;
      9'd335: coeff = -16'sd179;
      9'd336: coeff = -16'sd169;
      9'd337: coeff = -16'sd158;
      9'd338: coeff = -16'sd147;
      9'd339: coeff = -16'sd136;
      9'd340: coeff = -16'sd124;
      9'd341: coeff = -16'sd113;
      9'd342: coeff = -16'sd101;
      9'd343: coeff = -16'sd89;
      9'd344: coeff = -16'sd78;
      9'd345: coeff = -16'sd66;
      9'd346: coeff = -16'sd54;
      9'd347: coeff = -16'sd43;
      9'd348: coeff = -16'sd32;
      9'd349: coeff = -16'sd21;
      9'd350: coeff = -16'sd10;
      9'd351: coeff = 16'sd0;
      9'd352: coeff = 16'sd10;
      9'd353: coeff = 16'sd20;
      9'd354: coeff = 16'sd29;
      9'd355: coeff = 16'sd37;
      9'd356: coeff = 16'sd46;
      9'd357: coeff = 16'sd53;
      9'd358: coeff = 16'sd61;
      9'd359: coeff = 16'sd67;
      9'd360: coeff = 16'sd73;
      9'd361: coeff = 16'sd79;
      9'd362: coeff = 16'sd84;
      9'd363: coeff = 16'sd89;
      9'd364: coeff = 16'sd93;
      9'd365: coeff = 16'sd96;
      9'd366: coeff = 16'sd99;
      9'd367: coeff = 16'sd101;
      9'd368: coeff = 16'sd103;
      9'd369: coeff = 16'sd104;
      9'd370: coeff = 16'sd105;
      9'd371: coeff = 16'sd105;
      9'd372: coeff = 16'sd105;
      9'd373: coeff = 16'sd104;
      9'd374: coeff = 16'sd103;
      9'd375: coeff = 16'sd101;
      9'd376: coeff = 16'sd99;
      9'd377: coeff = 16'sd97;
      9'd378: coeff = 16'sd94;
      9'd379: coeff = 16'sd91;
      9'd380: coeff = 16'sd87;
      9'd381: coeff = 16'sd84;
      9'd382: coeff = 16'sd80;
      9'd383: coeff = 16'sd76;
      9'd384: coeff = 16'sd71;
      9'd385: coeff = 16'sd67;
      9'd386: coeff = 16'sd62;
      9'd387: coeff = 16'sd57;
      9'd388: coeff = 16'sd53;
      9'd389: coeff = 16'sd48;
      9'd390: coeff = 16'sd43;
      9'd391: coeff = 16'sd38;
      9'd392: coeff = 16'sd33;
      9'd393: coeff = 16'sd28;
      9'd394: coeff = 16'sd23;
      9'd395: coeff = 16'sd18;
      9'd396: coeff = 16'sd13;
      9'd397: coeff = 16'sd9;
      9'd398: coeff = 16'sd4;
      9'd399: coeff = 16'sd0;
      9'd400: coeff = -16'sd4;
      9'd401: coeff = -16'sd8;
      9'd402: coeff = -16'sd12;
      9'd403: coeff = -16'sd15;
      9'd404: coeff = -16'sd19;
      9'd405: coeff = -16'sd22;
      9'd406: coeff = -16'sd25;
      9'd407: coeff = -16'sd28;
      9'd408: coeff = -16'sd30;
      9'd409: coeff = -16'sd32;
      9'd410: coeff = -16'sd34;
      9'd411: coeff = -16'sd36;
      9'd412: coeff = -16'sd38;
      9'd413: coeff = -16'sd39;
      9'd414: coeff = -16'sd40;
      9'd415: coeff = -16'sd41;
      9'd416: coeff = -16'sd41;
      9'd417: coeff = -16'sd42;
      9'd418: coeff = -16'sd42;
      9'd419: coeff = -16'sd42;
      9'd420: coeff = -16'sd41;
      9'd421: coeff = -16'sd41;
      9'd422: coeff = -16'sd40;
      9'd423: coeff = -16'sd40;
      9'd424: coeff = -16'sd39;
      9'd425: coeff = -16'sd38;
      9'd426: coeff = -16'sd36;
      9'd427: coeff = -16'sd35;
      9'd428: coeff = -16'sd34;
      9'd429: coeff = -16'sd32;
      9'd430: coeff = -16'sd31;
      9'd431: coeff = -16'sd29;
      9'd432: coeff = -16'sd27;
      9'd433: coeff = -16'sd25;
      9'd434: coeff = -16'sd23;
      9'd435: coeff = -16'sd22;
      9'd436: coeff = -16'sd20;
      9'd437: coeff = -16'sd18;
      9'd438: coeff = -16'sd16;
      9'd439: coeff = -16'sd14;
      9'd440: coeff = -16'sd12;
      9'd441: coeff = -16'sd10;
      9'd442: coeff = -16'sd8;
      9'd443: coeff = -16'sd7;
      9'd444: coeff = -16'sd5;
      9'd445: coeff = -16'sd3;
      9'd446: coeff = -16'sd2;
      9'd447: coeff = 16'sd0;
      9'd448: coeff = 16'sd1;
      9'd449: coeff = 16'sd3;
      9'd450: coeff = 16'sd4;
      9'd451: coeff = 16'sd5;
      9'd452: coeff = 16'sd7;
      9'd453: coeff = 16'sd8;
      9'd454: coeff = 16'sd9;
      9'd455: coeff = 16'sd9;
      9'd456: coeff = 16'sd10;
      9'd457: coeff = 16'sd11;
      9'd458: coeff = 16'sd12;
      9'd459: coeff = 16'sd12;
      9'd460: coeff = 16'sd13;
      9'd461: coeff = 16'sd13;
      9'd462: coeff = 16'sd13;
      9'd463: coeff = 16'sd13;
      9'd464: coeff = 16'sd14;
      9'd465: coeff = 16'sd14;
      9'd466: coeff = 16'sd14;
      9'd467: coeff = 16'sd14;
      9'd468: coeff = 16'sd13;
      9'd469: coeff = 16'sd13;
      9'd470: coeff = 16'sd13;
      9'd471: coeff = 16'sd13;
      9'd472: coeff = 16'sd12;
      9'd473: coeff = 16'sd12;
      9'd474: coeff = 16'sd12;
      9'd475: coeff = 16'sd11;
      9'd476: coeff = 16'sd11;
      9'd477: coeff = 16'sd10;
      9'd478: coeff = 16'sd10;
      9'd479: coeff = 16'sd9;
      9'd480: coeff = 16'sd9;
      9'd481: coeff = 16'sd8;
      9'd482: coeff = 16'sd7;
      9'd483: coeff = 16'sd7;
      9'd484: coeff = 16'sd6;
      9'd485: coeff = 16'sd6;
      9'd486: coeff = 16'sd5;
      9'd487: coeff = 16'sd4;
      9'd488: coeff = 16'sd4;
      9'd489: coeff = 16'sd3;
      9'd490: coeff = 16'sd3;
      9'd491: coeff = 16'sd2;
      9'd492: coeff = 16'sd2;
      9'd493: coeff = 16'sd1;
      9'd494: coeff = 16'sd1;
      9'd495: coeff = 16'sd0;
      9'd496: coeff = 16'sd0;
      9'd497: coeff = -16'sd1;
      9'd498: coeff = -16'sd1;
      9'd499: coeff = -16'sd2;
      9'd500: coeff = -16'sd2;
      9'd501: coeff = -16'sd3;
      9'd502: coeff = -16'sd3;
      9'd503: coeff = -16'sd3;
      9'd504: coeff = -16'sd4;
      9'd505: coeff = -16'sd4;
      9'd506: coeff = -16'sd4;
      9'd507: coeff = -16'sd5;
      9'd508: coeff = -16'sd5;
      9'd509: coeff = -16'sd5;
      9'd510: coeff = -16'sd5;

      default: coeff = 16'hXXX;
    endcase
endmodule
