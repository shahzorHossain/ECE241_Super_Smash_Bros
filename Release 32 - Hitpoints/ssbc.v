
module ssbc
	(
		CLOCK_50,						//	On Board 50 MHz
		SW,
		KEY,
		PS2_CLK,
		PS2_DAT,
		LEDR,
		HEX0,
		HEX2,
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,					//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input [9:0] SW;
	input [3:0] KEY;
	inout		PS2_CLK;
	inout		PS2_DAT;
	output [7:0] LEDR;
	output [6:0] HEX0;
	output [6:0] HEX2;
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	wire			[7:0]	ps2_key_data;
	wire					ps2_key_pressed;
	reg				[7:0]	last_data_received;
	reg space, enter;
	reg [29:0] count;
	reg [29:0] count2;
 
always @(posedge CLOCK_50) begin
	if (ps2_key_pressed == 1'b1) last_data_received <= ps2_key_data;
	else last_data_received <= 8'h00;
end

always @(posedge CLOCK_50) begin
	if (last_data_received== 8'h29) space <= 1'b1;
	else space <= 1'b0;
end

always @(posedge CLOCK_50) begin
	if (last_data_received== 8'h5A) enter <= 1'b1;
	else enter <= 1'b0;
end

always @(posedge CLOCK_50) begin
	if (((space)||(count > 30'd0))&&(count < 30'd23333322)) begin
	count <= count + 1'b1;
	
	end
	else begin
	count <= 30'd0;
	end
end

always @(posedge CLOCK_50) begin
	if (((enter)||(count2 > 30'd0))&&(count2 < 30'd23333322)) begin
	count2 <= count2 + 1'b1;
	
	end
	else begin
	count2 <= 30'd0;
	end
end




PS2_Controller PS2 (
	// Inputs
	.CLOCK_50				(CLOCK_50),
	.reset				(1'b0),

	// Bidirectionals
	.PS2_CLK			(PS2_CLK),
 	.PS2_DAT			(PS2_DAT),

	// Outputs
	.received_data		(ps2_key_data),
	.received_data_en	(ps2_key_pressed)
);

	hex_decoder H2(hit_points_1, HEX2);
	hex_decoder H0(hit_points_0, HEX0);

	wire resetn, resetInverse;
	assign resetn = SW[9];

	assign gamepad_0 = ~KEY[1:0];
	assign gamepad_1 = ~KEY[3:2];

	wire [4:0] hit_points_0, hit_points_1;

	wire plot, clear, frameclk, move_0, move_1, direction_0, direction_1;
	
	wire [1:0] gamepad_0, gamepad_1;
	wire [1:0] action_0, action_counter_0, action_1, action_counter_1, hurt_0, hurt_1;

	wire [9:0] stage_colour;
	wire [16:0] stage_address;
	wire [9:0] sprite_colour_0, sprite_colour_1;
	wire [15:0] sprite_address_0, sprite_address_1;
	
	wire [5:0] colour, colour_out;
	wire [8:0] x, x_out;
	wire [7:0] y, y_out;
	wire writeEn;

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour_out),
			.x(x_out),
			.y(y_out),
			.plot(flush),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
		defparam VGA.BACKGROUND_IMAGE = "map.mif";
	
	frame Refresh (CLOCK_50, frameclk, resetn);
	datapath Data_Path (resetn, plot_0, plot_1, clear, CLOCK_50, frameclk, move_0, move_1, direction_0, direction_1, action_0, action_counter_0, action_1, action_counter_1, stage_colour, sprite_colour_0, sprite_colour_1, stage_address, sprite_address_0, sprite_address_1, hurt_0, hurt_1, colour, x, y, writeEn, hit_points_0, hit_points_1);
	control  Control_Path (resetn, CLOCK_50, frameclk, attack_0, attack_1, hurt_0, hurt_1, gamepad_0, gamepad_1, plot_0, plot_1, clear, flush, move_0, move_1, direction_0, direction_1, action_0, action_1, action_counter_0, action_counter_1);
	stage Battlefield (x, y, CLOCK_50, stage_colour);
	sprite0 Captain_Falcon (sprite_address_0, CLOCK_50, sprite_colour_0);
	sprite1 Ganondorf(sprite_address_1, CLOCK_50, sprite_colour_1);
	buffer Mem_Buffer(x, y, CLOCK_50, colour, writeEn, flush, x_out, y_out, colour_out);
	
endmodule

module datapath(resetn, plot_0, plot_1, clear, clk, frameclk, move_0, move_1, direction_0, direction_1, action_0, action_counter_0, action_1, action_counter_1, stage_colour, sprite_colour_0, sprite_colour_1, clear_counter, draw_counter_0, draw_counter_1, hurt_0, hurt_1, colour, x, y, writeEn, hit_points_0, hit_points_1);
	input resetn, plot_0, plot_1, clear, clk, frameclk, move_0, move_1, direction_0, direction_1;
	input [1:0] action_0, action_counter_0, action_1, action_counter_1;
	input [5:0] stage_colour;
	input [5:0] sprite_colour_0, sprite_colour_1;

	output [16:0] clear_counter;
	output [15:0] draw_counter_0, draw_counter_1;
	output reg [1:0] hurt_0, hurt_1;
	output reg [5:0] colour;
	output reg [8:0] x;
	output reg [7:0] y;
	output reg writeEn;
	
	output reg [5:0] hit_points_0, hit_points_1;
	reg hurt_count_enable;
	reg [4:0] hurt_count;
	reg [8:0] xo_0, xo_1;
	reg [7:0] yo_0, yo_1;
	reg [8:0] clear_counter_x;
	reg [7:0] clear_counter_y;
	reg [7:0] draw_counter_x_0, draw_counter_x_1;
	reg [7:0] draw_counter_y_0, draw_counter_y_1;

	//Draw sprite_0 counter
	always@(posedge clk) begin
		if(plot_0 == 1'b1) begin
			if(draw_counter_x_0 < 8'd63) draw_counter_x_0 <= draw_counter_x_0 + 8'd1;
			else if (draw_counter_y_0 < 8'd63) begin
			draw_counter_x_0 <= 8'd0;
			draw_counter_y_0 <= draw_counter_y_0 + 8'd1;
			end
		end
		else begin
		draw_counter_x_0 <= 8'd0;
		draw_counter_y_0 <= 8'd0;
		end
	end
	
	//Draw sprite_1 counter
	always@(posedge clk) begin
		if(plot_1 == 1'b1) begin
			if(draw_counter_x_1 < 8'd63) draw_counter_x_1 <= draw_counter_x_1 + 8'd1;
			else if (draw_counter_y_1 < 8'd63) begin
			draw_counter_x_1 <= 8'd0;
			draw_counter_y_1 <= draw_counter_y_1 + 8'd1;
			end
		end
		else begin
		draw_counter_x_1 <= 8'd0;
		draw_counter_y_1 <= 8'd0;
		end
	end
	
	//Clear screen counter
	always@(posedge clk) begin
		if(clear == 1'b1) begin
			if(clear_counter_x < 9'd320) clear_counter_x <= clear_counter_x + 9'd1;
			else if (clear_counter_y < 8'd240) begin
			clear_counter_x <= 9'd0;
			clear_counter_y <= clear_counter_y + 8'd1;
			end
		end
		else begin
		clear_counter_x <= 9'd0;
		clear_counter_y <= 9'd0;
		end
	end
	
	//Send position pixel and draw counter to buffer
	always@(posedge clk) begin
	  if(clear == 1'b1) begin
			x <= clear_counter_x[8:0]; 
			y <= clear_counter_y[7:0];
	  end

	  //if plot enabled, draw x row and y column for sprite_0 depending on its direction
	  else if(plot_0 == 1'b1) begin 
		if(direction_0 == 1'b0)
			begin
			x <= xo_0 + draw_counter_x_0[7:0]; 
			y <= yo_0 + draw_counter_y_0[7:0];
			end
		else if(direction_0 == 1'b1)
			begin
			x <= xo_0 + 6'd63 - draw_counter_x_0[7:0]; 
			y <= yo_0 + draw_counter_y_0[7:0];
			end
	  end

	  //if plot enabled, draw x row and y column for sprite_1 depending on its direction
	  else if(plot_1 == 1'b1) begin //if plot enabled, draw x row and y column
		if(direction_1 == 1'b0)
			begin
			x <= xo_1 + draw_counter_x_1[7:0]; 
			y <= yo_1 + draw_counter_y_1[7:0];
			end
		else if(direction_1 == 1'b1)
			begin
			x <= xo_1 + 6'd63 - draw_counter_x_1[7:0]; 
			y <= yo_1 + draw_counter_y_1[7:0];
			end
	  end
	  else begin
			x <= xo_0;
			y <= yo_0;
	  end
	end
	
	//Pass colour to buffer, if green screened, disable write
	always@(posedge clk) begin
	  if (plot_0 == 1'b1) begin
			if (sprite_colour_0 == 6'b001100)begin
			colour <= stage_colour; //if green, pass colour from background
			writeEn <= 1'b0;
			end
			else begin
			colour <= sprite_colour_0;  //else pass through colour from sprite
			writeEn <= 1'b1;
			end
	  end
	  else if (plot_1 == 1'b1) begin
			if (sprite_colour_1 == 6'b001100) begin
			colour <= stage_colour; //if green, pass colour from background
			writeEn <= 1'b0;
			end
			else begin
			colour <= sprite_colour_1;  //else pass through colour from sprite
			writeEn <= 1'b1;
			end
	  end
	  else if (clear == 1'b1) begin
	  colour <= stage_colour;  //if black key is pressed or clear state, use colour black
	  writeEn <= 1'b1;
	  end
	end

	//Hurt counter
	always@(posedge frameclk) begin
	 	if((hurt_count > 5'd0)||hurt_count_enable) hurt_count <= hurt_count + 5'd1;
	 	else hurt_count <= 5'd0;
	 end
	
	//Position pixel addition/ subtraction
	always@(posedge clk) begin
		if (!resetn) begin //if reset, xo and yo is (0,0)
			xo_0 <= 9'd1;
			yo_0 <= 8'd60;
			xo_1 <= 9'd255;
			yo_1 <= 8'd60;
			hit_points_0 <= 6'd0;
			hit_points_1 <= 6'd0;
		end

		//Knockback sprite_0 left                              
		if ((hurt_0 == 2'd2) && (move_0 == 1'b1) && (xo_0 > 9'd0) && (hurt_count == 5'd2)) begin
			xo_0 <= xo_0 - 2'd2;
			hit_points_1 <= hit_points_1 + 2'b10;
		end                                      
		//Knockback sprite_0 right                                     
		else if ((hurt_0 == 2'd1) && (move_0 == 1'b1) && ((xo_0 + 9'd64) < 9'd320) && (hurt_count == 5'd2)) begin
			xo_0 <= xo_0 + 2'd2;
			hit_points_1 <= hit_points_1 + 2'b10;
		end 
		//Move sprite_0 left                              
		else if ((direction_0 == 1'b1) && (move_0 == 1'b1) && (xo_0 > 9'd0) && ((xo_0 - 1) > 9'd0) && (hurt_count_enable == 1'd0)) xo_0 <= xo_0 - 5'd2;                                      
		//Move sprite_0 right                                     
		else if ((direction_0 == 1'b0) && (move_0 == 1'b1) && ((xo_0 + 9'd64) < 9'd320) && (hurt_count_enable == 1'd0)) xo_0 <= xo_0 + 5'd2;

		//Knockback sprite_1 left                              
		if ((hurt_1 == 2'd2) && (move_1 == 1'b1) && (xo_1 > 9'd0) && (hurt_count == 5'd2)) begin
			xo_1 <= xo_1 - 2'd2;
			hit_points_0 <= hit_points_0 + 1'b1;
		end                                       
		//Knockback sprite_1 right                                     
		else if ((hurt_1 == 2'd1) && (move_1 == 1'b1) && ((xo_1 + 9'd64) < 9'd320) && (hurt_count == 5'd2)) begin
			xo_1 <= xo_1 + 2'd2;
			hit_points_0 <= hit_points_0 + 1'b1;
		end
		//Move sprite_1 left
		else if ((direction_1 == 1'b1) && (move_1 == 1'b1) && (xo_1 > 9'd0) && (hurt_count_enable == 1'd0)) xo_1 <= xo_1 - 5'd1;                                      
		//Move sprite_1 right                                   
		else if ((direction_1 == 1'b0) && (move_1 == 1'b1) && ((xo_1 + 9'd64) < 9'd320) && (hurt_count_enable == 1'd0)) xo_1 <= xo_1 + 5'd1;
	end

	//Check hitbox
	always@(posedge clk) begin
		//Sprite1 knockback right
		if((action_0 == 2'd3) && (action_counter_0 == 2'd1) && (direction_0 == 1'b0) && (xo_0 + 9'd64 >= xo_1 + 9'd20) && (xo_0 + 9'd64 <= xo_1 + 9'd44) && (hurt_count_enable == 5'd0)) begin
			hurt_1 <= 2'd1;
			hurt_count_enable <= 1'b1;
		end
		//Sprite1 knockback left
		else if((action_0 == 2'd3) && (action_counter_0 == 2'd1) && (direction_0 == 1'b1) && (xo_0 >= xo_1 + 9'd20) && (xo_0 <= xo_1 + 9'd44) && (hurt_count_enable == 5'd0)) begin
			hurt_1 <= 2'd2;
			hurt_count_enable <= 1'b1;
		end
		//Sprite0 knockback right
		else if((action_1 == 2'd3) && (action_counter_1 == 2'd1) && (direction_1 == 1'b0) && (xo_1 + 9'd64 >= xo_0 + 9'd20) && (xo_1 + 9'd64 <= xo_0 + 9'd44) && (hurt_count_enable == 5'd0)) begin
			hurt_0 <= 2'd1;
			hurt_count_enable <= 1'b1;
		end
		//Sprite0 knockback left
		else if((action_1 == 2'd3) && (action_counter_1 == 2'd1) && (direction_1 == 1'b1) && (xo_1 >= xo_0 + 9'd20) && (xo_1 <= xo_0 + 9'd44) && (hurt_count_enable == 5'd0)) begin
			hurt_0 <= 2'd2;
			hurt_count_enable <= 1'b1;
		end
		else if(hurt_count == 5'd3) begin
			hurt_0 <= 2'd0;
			hurt_1 <= 2'd0;
			hurt_count_enable <= 1'b0;
		end
	end
	
	assign draw_counter_0 [7:0] =  action_counter_0*7'd64 + draw_counter_x_0 [7:0];
	assign draw_counter_0 [15:8] = action_0*7'd64 + draw_counter_y_0 [7:0];
	
	assign draw_counter_1 [7:0] =  action_counter_1*7'd64 + draw_counter_x_1 [7:0];
	assign draw_counter_1 [15:8] = action_1*7'd64 + draw_counter_y_1 [7:0];

endmodule

module control(resetn, clk, frameclk, attack_0, attack_1, hurt_0, hurt_1, gamepad_0, gamepad_1, plot_0, plot_1, clear, flush, move_0, move_1, direction_0, direction_1, action_0, action_1, action_counter_0, action_counter_1);
	input resetn, clk, frameclk, attack_0, attack_1;
	input [1:0] hurt_0, hurt_1; 
	input [1:0] gamepad_0, gamepad_1;
	output reg plot_0, plot_1, clear, flush;
	output reg move_0, move_1, direction_0, direction_1;
	output reg [1:0] action_0, action_1, action_counter_0, action_counter_1;
	
	reg [17:0] count;
	reg [2:0] animate_count;
	reg counter;
	
	reg [3:0] current_state, next_state; 
    
   localparam  		IDLE    = 4'd0,
					MOVE     = 4'd1,
					WAIT0     = 4'd2,
					DRAW0    = 4'd3,
					WAIT1    = 4'd4,
					DRAW1	= 4'd5,
					WAIT2  = 4'd6,
					FLUSH	= 4'd7,
					WAIT3 = 4'd8,
					CLEAR = 4'd9;
					
	 always@(posedge clk) begin  //clear counter
		if(counter) count <= count+ 18'd1; 
		else count <= 18'd0;
	 end
	 
	 always@(posedge frameclk) begin  //clear counter
		animate_count <= animate_count + 1'b1;
		if (animate_count == 3'b111) begin
		action_counter_0 <= action_counter_0 + 1'b1;
		action_counter_1 <= action_counter_1 + 1'b1;
		end
	 end
	
	 always@(*)
    begin: state_table 
            case (current_state)
					IDLE: next_state = WAIT0;
					
					MOVE: next_state = WAIT0;
					
					WAIT0: next_state = DRAW1;
					
					DRAW0: begin
						if(count <= 18'd4096) next_state = DRAW0;
						else next_state = WAIT1;
						end
						
					WAIT1: next_state = FLUSH;
						
					DRAW1: begin
						if(count <= 18'd4096) next_state = DRAW1;
						else next_state = WAIT2;
						end
				
					WAIT2: begin
						if(!frameclk) next_state = WAIT2;
						else next_state = DRAW0;
						end
						
					FLUSH: 
						if(count <= 18'd76800) next_state = FLUSH;
						else 
						next_state = WAIT3;

					WAIT3: next_state = CLEAR;

					CLEAR: 
						if(count <= 18'd76800) next_state = CLEAR;
						else 
						next_state = MOVE;
					
            default:     next_state = IDLE;
        endcase
    end // state_table
	 
	 always @(*)
    begin: enable_signals
		  plot_0 = 1'b0;
		  plot_1 = 1'b0;
		  clear = 1'b0;
		  flush = 1'b0;
		  counter = 1'b0;
		  move_0 = 3'b0;
		  move_1 = 3'b0;
		  
        case (current_state)
				MOVE: begin	//Move position

					//sprite_0 knockback right/left
					if ((hurt_0 == 2'd1) || (hurt_0 == 2'd2)) move_0 = 1'd1;

					//sprite_0 move right/left
					else if (gamepad_0[0]) begin
					direction_0 = 1'd0;
					move_0 = 1'd1;
					end
					else if (gamepad_0[1])
					begin
					direction_0 = 1'd1;
					move_0 = 1'd1;
					end

					//sprite_1 knockback right/left
					if ((hurt_1 == 2'd1) || (hurt_1 == 2'd2)) move_1 = 1'd1;

					//sprite_1 move right/left
					else if (gamepad_1[0]) begin
					direction_1 = 1'd0;
					move_1 = 1'd1;
					end
					else if (gamepad_1[1])
					begin
					direction_1 = 1'd1;
					move_1 = 1'd1;
					end
					end
				DRAW0: begin	//Draw box around position pixel
					 plot_0 = 1'b1;
					 counter = 1'b1;
					 end
				WAIT1: begin
					if ((hurt_0 == 2'd1)||(hurt_0 == 2'd2)) action_0 <= 2'd2;
					else if (gamepad_0) action_0 <= 2'd1;
					else if(attack_0 == 1'b1) action_0 <= 2'd3;
					else action_0 <= 2'd0;
					end
				DRAW1: begin	//Draw box around position pixel
					plot_1 = 1'b1;
					counter = 1'b1;
					end
				WAIT2: begin
					if ((hurt_1 == 2'd1)||(hurt_1 == 2'd2)) action_1 <= 2'd2;
					else if (gamepad_1) action_1 <= 2'd1;
					else if(attack_1 == 1'b1) action_1 <= 2'd3;
					else action_1 <= 2'd0;
					end
				FLUSH: begin //Flush to screen
					 flush = 1'b1;
					 counter = 1'b1;
					 end
				CLEAR: begin //Refresh entire screen with background
					 clear = 1'b1;
					 counter = 1'b1;
					 end
        endcase
    end // enable_signals
	 
	 always@(posedge clk)
    begin: state_FFs
        if(!resetn) current_state <= IDLE;
        else current_state <= next_state;
    end // state_FFS
					 
endmodule

module frame(clk, frameclk, resetn); //Refresh Rate
	input clk, resetn;
	output frameclk;
	
	reg [25:0] counter;
	
	always @(posedge clk) begin
		if (!resetn) counter <= 26'd0;
		else if (counter == 26'd833333) counter <= 26'd0; //60 times a second counter
		else counter <= counter + 1'b1;
	end
	
	assign frameclk = (counter == 26'd833333) ? 1'b1 : 1'b0;

endmodule

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule
