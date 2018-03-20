module part2
	(
		CLOCK_50,						//	On Board 50 MHz
		KEY,
		// Keyboard inputs below 
		// TODO
		
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input [3:0]		KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	wire keyboard_up;
	wire keyboard_down;
	wire keyboard_w;
	wire keyboard_s;
	wire keyboard_enter;
	wire control_move_pads;
	wire control_move_ball;
	wire control_set_up_clear_screen;
	wire control_clear_screen;
	wire control_draw_left_pad;
	wire control_draw_right_pad;
	wire control_draw_ball;
	wire control_reset_delta;
	
	
	keyboard_tracker #(.PULSE_OR_HOLD(0)) <keyboard>(.clock(CLOCK_50),
		.reset(resetn),
		.up(keyboard_up),
		.down(keyboard_down),
		.w(keyboard_w),
		.s(keyboard_s),
		.enter(keyboard_enter));
	
    // Instansiate datapath
	datapath d0(.clk(CLOCK_50), 
		.resetn(resetn), 
		.move_left_up(keyboard_up),
		.move_left_down(keyboard_down),
		.move_right_up(keyboard_w),
		.move_right_down(keyboard_s),
		.set_up_clear_screen(control_set_up_clear_screen),
		.clear_screen(control_clear_screen),
		.move_pads(control_move_pads),
		.move_ball(control_move_ball),
		.draw_left_pad(control_draw_left_pad),
		.draw_right_pad(control_draw_right_pad),
		.draw_ball(control_draw_ball),
		.reset_delta(control_reset_delta));

	
    // Instansiate FSM control
	control c0(.clk(CLOCK_50), 
		.resetn(resetn),
		.enter(keyboard_enter),
		.move_pads(control_move_pads),
		.move_ball(control_move_ball),
		.set_up_clear_screen(control_set_up_clear_screen),
		.clear_screen(control_clear_screen),
		.draw_left_pad(control_draw_left_pad),
		.draw_right_pad(control_draw_right_pad),
		.draw_ball(control_draw_ball),
		.reset_delta(control_reset_delta));
   
    
endmodule

module control(
	input clk,
	input resetn,
	input enter, // From keyboard
	
	// Output based on state
	output reg move_pads,
	output reg move_ball,
	output reg set_up_clear_screen,
	output reg clear_screen,
	output reg draw_left_pad,
	output reg draw_right_pad,
	output reg draw_ball,
	output reg reset_delta,
	output reg plot
	);
	
	localparam 	PAD_COUNTER_LENGTH 			= 4'b1111,// TODO
				BALL_COUNTER_LENGTH 		= 7'b1000000,
				FRAME_COUNTER_LENGTH		= 20'b11001011011100110101,
				CLEAR_SCREEN_COUNTER_LENGTH	= 15'b100101100000000;
				
	// current_state registers and counters
	reg [4:0] draw_left_pad_counter;
	reg [4:0] draw_right_pad_counter;
	reg [4:0] draw_ball_counter;
	reg [19:0] frame_counter;
	reg [14:0] clear_screen_counter;
	reg [2:0] current_state, next_state; 
    
    localparam  S_MENU        			= 4'd0,
                S_MOVE_PADS   			= 4'd1,
                S_MOVE_BALL 			= 4'd2,
				S_SET_UP_CLEAR_SCREEN	= 4'd3,
				S_CLEAR_SCREEN			= 4'd4,
                S_DRAW_LEFT_PAD  		= 4'd5,
				S_RESET1				= 4'd6,
				S_DRAW_RIGHT_PAD		= 4'd7,
				S_RESET2				= 4'd8,
				S_DRAW_BALL				= 4'd9,
				S_RESET3				= 4'd10,
				S_WAIT					= 4'd11;
	
	always @(*)
	begin: state_table 
            case (current_state)
                S_MENU: next_state = enter ? S_MOVE_PADS : S_MENU;
                S_MOVE_PADS: next_state = S_MOVE_BALL;
                S_MOVE_BALL: next_state = S_SET_UP_CLEAR_SCREEN; 
				S_SET_UP_CLEAR_SCREEN: next_state = S_CLEAR_SCREEN;
				S_CLEAR_SCREEN: next_state = (clear_screen_counter == 0) ? S_DRAW_LEFT_PAD : S_CLEAR_SCREEN;
                S_DRAW_LEFT_PAD: next_state = (draw_left_pad_counter == 0) ? S_RESET1: S_DRAW_LEFT_PAD;
				S_RESET1: next_state = S_DRAW_RIGHT_PAD;
				S_DRAW_RIGHT_PAD: next_state = (draw_right_pad_counter == 0) ? S_RESET2 : S_DRAW_RIGHT_PAD;
				S_RESET2: next_state = S_DRAW_BALL;
				S_DRAW_BALL: next_state = (draw_ball_counter == 0) ? S_RESET3 : S_DRAW_BALL;
				S_RESET3: next_state = S_WAIT;
				S_WAIT: next_state = (frame_counter == 0) ? S_MOVE_PADS : S_WAIT;
			default:     next_state = S_MENU;
        endcase
    end // state_table
	
	always @(*)
    begin: enable_signals
        // By default make all our signals 0
        move_pads = 0;
		move_ball = 0;
		draw_left_pad = 0;
		draw_right_pad = 0;
		draw_ball = 0;
		reset_delta = 0;
		plot = 1'b0;

        case (current_state)
            S_MOVE_PADS: begin
				move_pads = 1'b1;
				end
			S_MOVE_BALL: begin
				move_ball = 1'b1;
				end 
			S_SET_UP_CLEAR_SCREEN: begin
				set_up_clear_screen = 1'b1;
				end
			S_CLEAR_SCREEN: begin
				clear_screen = 1'b1;
				plot = 1'b1;
				end
			S_DRAW_LEFT_PAD: begin
				draw_left_pad = 1'b1;
				plot = 1'b1;
				end
			S_DRAW_RIGHT_PAD: begin
				draw_right_pad = 1'b1;
				plot = 1'b1;
				end
			S_DRAW_BALL: begin
				draw_ball = 1'b1;
				plot = 1'b1;
				end
			
        endcase
    end // enable_signals
	
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= S_MENU;
        else begin
            current_state <= next_state;
			if(current_state == S_DRAW_LEFT_PAD)
				draw_left_pad_counter <= draw_left_pad_counter - 1;
			else draw_left_pad_counter <= PAD_COUNTER_LENGTH;
			
			if(current_state == S_DRAW_RIGHT_PAD)
				draw_right_pad_counter <= draw_right_pad_counter - 1;
			else draw_right_pad_counter <= PAD_COUNTER_LENGTH;
				
			if(current_state == S_DRAW_BALL)
				draw_ball_counter <= draw_ball_counter - 1;
			else draw_ball_counter <= BALL_COUNTER_LENGTH;
				
			if(current_state == S_WAIT)
				frame_counter <= frame_counter - 1;
			else frame_counter <= FRAME_COUNTER_LENGTH;
			
			if(current_state == S_CLEAR_SCREEN)
				clear_screen_counter <= clear_screen_counter -1;
			else clear_screen_counter <= CLEAR_SCREEN_COUNTER_LENGTH;
		
		end
    end // state_FFS
endmodule

module datapath(
	input clk,
	input resetn,
	
	// From keybaord
	input move_left_up, 
	input move_right_up,
	input move_left_down,
	input move_right_down,
	
	// Actions based on current state
	input set_up_clear_screen,
	input clear_screen,
	input move_pads,
	input mode_ball,
	input draw_left_pad,
	input draw_right_pad,
	input draw_ball,
	input reset_delta,
	
	// Output to VGA
	output reg[7:0] x,
	output reg[6:0] y,
	output reg[2:0] colour
	);
	
	reg [6:0] left_pad_y;
	reg [6:0] right_pad_y;
	
	reg [6:0] left_pad_orig_y;
	reg [6:0] right_pad_orig_y;
	
	reg [6:0] left_pad_x;
	reg [6:0] right_pad_x;
	
	reg [7:0] ball_x;
	reg [6:0] ball_y;
	
	reg [7:0] x_delta;
	reg [6:0] y_delta;
	
	localparam LEFT_PAD_X = 0, 
		RIGHT_PAD_X = 7'b1110000,
		PAD_MOVE_DELTA = 6'b000011;
	
	always @(posedge clk) begin
		if(!resetn) begin
			left_pad_y <= 0;
			right_pad_y <= 0;
			ball_x <= 7'b0111111;
			ball_y <= 6'b011111;
			x_delta <= 0;
			y_delta <= 0;
		end
		else begin
			if(set_up_clear_screen) begin
				x <= 0;
				y <= 0;
			end
			if(clear_screen) begin
				if(x == 159) begin
					x <= 0;
					y <= y+1;
				end
				else
					x <= x + 1;
			end
			if(reset_delta) begin
				x_delta <= 0;
				y_delta <= 0;
			end
			if(move_pads) begin
				if(move_left_up)
					left_pad_y <= left_pad_y + PAD_MOVE_DELTA;
					left_pad_orig_y <= left_pad_orig_y + PAD_MOVE_DELTA;
					left_pad_x <= LEFT_PAD_X;
				if(move_right_up)
					right_pad_y <= right_pad_y + PAD_MOVE_DELTA;
					right_pad_orig_y <= right_pad_orig_y + PAD_MOVE_DELTA;
					right_pad_x <= RIGHT_PAD_X;
				if(move_left_down)
					left_pad_y <= left_pad_y - PAD_MOVE_DELTA;
					left_pad_orig_y <= left_pad_orig_y - PAD_MOVE_DELTA;
					left_pad_x <= LEFT_PAD_X;
				if(move_right_down)
					right_pad_y <= right_pad_y - PAD_MOVE_DELTA;
					right_pad_orig_y <= right_pad_orig_y - PAD_MOVE_DELTA;
					right_pad_x <= RIGHT_PAD_X;
			end
			//if(move_ball)
			if(draw_left_pad) begin			
				if (left_pad_y - left_pad_orig_y >= 7) begin
					left_pad_y <= left_pad_orig_y;
					left_pad_x <= left_pad_x + 1;
				end
				else begin
					left_pad_y <= left_pad_y + 1;
				end
				
				x <= left_pad_x;
				y <= left_pad_y;
			end
			if(draw_right_pad) begin
				if (right_pad_y - right_pad_orig_y >= 7) begin
					right_pad_y <= right_pad_orig_y;
					right_pad_x <= right_pad_x - 1;
				end
				else begin
					right_pad_y <= right_pad_y + 1;
				end
				
				x <= right_pad_x;
				y <= right_pad_y;
			end
			if(draw_ball) begin
				if(x_delta == 7'b0001000) begin
					x_delta <= 0;
					y_delta <= y_delta + 1;
				end
				else
					x_delta <= x_delta +1;
				
				x <= ball_x + x_delta;
				y <= ball_y + y_delta;
			end
		end
	end
	
	// Choose colour
	reg [7:0] x_dist;
	reg [7:0] y_dist;
	always @(*) begin
		if(draw_left_pad || draw_right_pad)
			colour <= 3'b111;
		else if(draw_ball) begin
			// Calculate distance to center
			x_dist <= (x_delta < 7'b0000100) ? 7'b0000100 - x_delta : x_delta - 7'b0000100;
			y_dist <= {1'b0, (y_delta < 6'b000100) ? 6'b000100 - y_delta : y_delta - 6'b000100};
			
			// Decide whether to draw a pixel or not
			if(x_dist * x_dist + y_dist * y_dist <= 7'b0000100 * 7'b0000100)
				colour <= 3'b111;
			else
				colour <= 0;
		end	
		else
			colour <= 0;
	end
endmodule