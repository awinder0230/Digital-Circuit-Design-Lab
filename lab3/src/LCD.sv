// CLOCK: 12MHz => 83.33 ns ~= 84 ns
module LCD(
  input        i_clk,
  input        i_rst,
  // LCD module connection
  inout  [7:0] LCD_DATA,
  output       LCD_EN,
  output       LCD_RW,
  output       LCD_RS,
  output       LCD_ON,
  output       LCD_BLON,
  // self designed inout
  input  [2:0] INPUT_STATE,
  output       READY
);

//=======================================================
//-----------------Default Assumption--------------------
//=======================================================

// Turn LCD ON
assign LCD_ON   = 1'b1;
// LCD modules used on DE2-115 boards do not have backlight.
assign LCD_BLON = 1'b0;

//=======================================================
//------------Define Basic Instruction Set---------------
//=======================================================

parameter [7:0] ZERO        = 8'b00000000; // zeros
parameter [7:0] CLEAR       = 8'b00000001; // Execution time = 1.53ms, Clear Display
parameter [7:0] ENTRY_N     = 8'b00000110; // Execution time = 39us,   Normal Entry, Cursor increments, Display is not shifted
parameter [7:0] DISPLAY_ON  = 8'b00001100; // Execution time = 39us,   Turn ON Display
parameter [7:0] FUNCT_SET   = 8'b00111000; // Execution time = 39us,   sets to 8-bit interface, 2-line display, 5x8 dots

//=======================================================
//---------------------LCD Index-------------------------
//=======================================================

logic [5:0] lcd_index_w, lcd_index_r; // 16 x 2 LCD

//=======================================================
//--------------Define Timing Parameters-----------------
//=======================================================

parameter [19:0] t_39us     = 465;      //39us      ~= 465    clks
parameter [19:0] t_43us     = 512;      //43us      ~= 512    clks
parameter [19:0] t_100us    = 1191;     //100us     ~= 1191   clks
parameter [19:0] t_1530us   = 18215;    //1.53ms    ~= 18215  clks
parameter [19:0] t_4100us   = 48810;    //4.1ms     ~= 48810  clks
parameter [19:0] t_15000us  = 178572;   //15ms      ~= 178572 clks

// time counter and flags
logic [19:0] timer_w, timer_r;
logic flag_timer_rst_w, flag_timer_rst_r;
logic flag_39us;
logic flag_43us;
logic flag_100us;
logic flag_1530us;
logic flag_4100us;
logic flag_15000us;

assign flag_39us = (timer_r >= t_39us);
assign flag_43us = (timer_r >= t_43us);
assign flag_100us = (timer_r >= t_100us);
assign flag_1530us = (timer_r >= t_1530us);
assign flag_4100us = (timer_r >= t_4100us);
assign flag_15000us = (timer_r >= t_15000us);

//=======================================================
//-------------------Define States-----------------------
//=======================================================

// LCD Module States
enum {INIT, IDLE, RECORD, STOP, PLAY, PAUSE, S_CLEAR} state_w, state_r;
enum {SUB_1, SUB_2, SUB_3, SUB_4, SUB_5, SUB_6, SUB_7, SUB_8} substate_w, substate_r;

// INPUT_STATE ( input from Top module in Top.sv )
parameter [2:0] INPUT_INIT   = 3'b000;
parameter [2:0] INPUT_IDLE   = 3'b001;
parameter [2:0] INPUT_RECORD = 3'b010;
parameter [2:0] INPUT_STOP   = 3'b011;
parameter [2:0] INPUT_PLAY   = 3'b100;
parameter [2:0] INPUT_PAUSE  = 3'b101;


//=======================================================
//--------------------Time Counter-----------------------
//=======================================================

always_comb begin

end

//=======================================================
//--------------------State Machine----------------------
//=======================================================

always_comb begin
  state_w = state_r;
  substate_w = substate_r;
  flag_timer_rst_w = flag_timer_rst_r;
  lcd_index_w = lcd_index_r;

  if (flag_timer_rst_r) begin
    timer_w = 20'b0;
  end else begin
    timer_w = timer_r + 1;
  end
  
  case(state_r)
//------------------------INIT---------------------------
    INIT: begin
      case(substate_r)
        SUB_1: begin // wait 15ms after Vcc rises to 4.5V
          LCD_DATA = 8'b0;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_15000us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_2;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_2: begin // wait for more than 4.1ms
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_4100us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_3;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_3: begin // wait for more than 100us
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_100us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_4;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_4: begin // Function Set, wait for 39us
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_5;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_5: begin // Display On, wait for 39us
          LCD_DATA = DISPLAY_ON;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_6;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_6: begin // Display Clear, wait for 1.53ms
          LCD_DATA = CLEAR;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_1530us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_7;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_7: begin // Entry Mode Set, wait for 39us
          LCD_DATA = ENTRY_N;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_8;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_8: begin // goto state IDLE
          LCD_DATA = ZERO;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          if (INPUT_STATE != INPUT_INIT) begin
            state_w = RECORD;
            substate_w = SUB_1;
            READY    = 1'b0;
          end else begin
            state_w  = state_r;
            substate_w = substate_r;
            READY = 1'b1;
          end
          flag_timer_rst_w = 1'b1;
			 lcd_index_w = 0;
        end
      endcase
    end
    // init lcd index


//------------------------IDLE---------------------------
    IDLE: begin
      READY    = 1'b1;
      LCD_DATA = ZERO;
      LCD_EN   = 1'b0;
      LCD_RW   = 1'b0;
      LCD_RS   = 1'b0;
      lcd_index_w = 6'b0;

      case(INPUT_STATE)
        INPUT_INIT: begin
          state_w          = INIT;
          substate_w       = SUB_1;
          flag_timer_rst_w = 1'b1;
        end

        INPUT_IDLE: begin
          state_w          = state_r;
          substate_w       = substate_r;
          flag_timer_rst_w = flag_timer_rst_r;
        end

        INPUT_RECORD: begin
          state_w          = RECORD;
          substate_w       = SUB_1;
          flag_timer_rst_w = 1'b1;
        end

        INPUT_STOP: begin
          state_w          = STOP;
          substate_w       = SUB_1;
          flag_timer_rst_w = 1'b1;
        end

        INPUT_PLAY: begin
          state_w          = PLAY;
          substate_w       = SUB_1;
          flag_timer_rst_w = 1'b1;
        end

        INPUT_PAUSE: begin
          state_w          = PAUSE;
          substate_w       = SUB_1;
          flag_timer_rst_w = 1'b1;
        end
      endcase
    end

//-----------------------RECORD--------------------------
    RECORD: begin
      READY  = 1'b0;
      LCD_RS = 1'b1;
      LCD_RW = 1'b0;
      if (INPUT_STATE == INPUT_RECORD) begin
        // delay for each input
        if (!flag_43us) begin
          flag_timer_rst_w = 1'b0;
          lcd_index_w = lcd_index_r;
          if (lcd_index_r >= 6) begin // finish
            LCD_EN = 1'b0;
          end else begin
            LCD_EN = 1'b1;
          end
        end else begin
          flag_timer_rst_w = 1'b1;
          if (lcd_index_r >= 6) begin // finish
            lcd_index_w = lcd_index_r;
          end else begin
            lcd_index_w = lcd_index_r + 1;
          end
          LCD_EN = 1'b0;
        end
        // input characters
        case(lcd_index_r)
          0: LCD_DATA = 8'b01010010; // R
          1: LCD_DATA = 8'b01000010; // E
          2: LCD_DATA = 8'b01000011; // C
          3: LCD_DATA = 8'b01001111; // O
          4: LCD_DATA = 8'b01010010; // R
          5: LCD_DATA = 8'b01000100; // D
          default:  LCD_DATA = ZERO;
        endcase
      end else begin
        LCD_EN = 1'b0;
        LCD_DATA = 8'b0;
        state_w = S_CLEAR;
        substate_w = SUB_1;
        flag_timer_rst_w = 1'b1;
      end
    end
//------------------------STOP--------------------------- 
    STOP: begin
      READY  = 1'b0;
      LCD_RS = 1'b1;
      LCD_RW = 1'b0;
      if (INPUT_STATE == INPUT_STOP) begin
        // delay for each input
        if (!flag_43us) begin
          flag_timer_rst_w = 1'b0;
          lcd_index_w = lcd_index_r;
          if (lcd_index_r >= 4) begin // finish
            LCD_EN = 1'b0;
          end else begin
            LCD_EN = 1'b1;
          end
        end else begin
          flag_timer_rst_w = 1'b1;
          if (lcd_index_r >= 4) begin // finish
            lcd_index_w = lcd_index_r;
          end else begin
            lcd_index_w = lcd_index_r + 1;
          end
          LCD_EN = 1'b0;
        end
        // input characters
        case(lcd_index_r)
          0: LCD_DATA = 8'b01010011; // S
          1: LCD_DATA = 8'b01010100; // T
          2: LCD_DATA = 8'b01001111; // O
          3: LCD_DATA = 8'b01010000; // P
          default:  LCD_DATA = ZERO;
        endcase
      end else begin
        LCD_EN = 1'b0;
        LCD_DATA = 8'b0;
        state_w = S_CLEAR;
        substate_w = SUB_1;
        flag_timer_rst_w = 1'b1;
      end
    end
//------------------------PLAY---------------------------
    PLAY: begin
      READY  = 1'b0;
      LCD_RS = 1'b1;
      LCD_RW = 1'b0;
      if (INPUT_STATE == INPUT_PLAY) begin
        // delay for each input
        if (!flag_43us) begin
          flag_timer_rst_w = 1'b0;
          lcd_index_w = lcd_index_r;
          if (lcd_index_r >= 4) begin // finish
            LCD_EN = 1'b0;
          end else begin
            LCD_EN = 1'b1;
          end
        end else begin
          flag_timer_rst_w = 1'b1;
          if (lcd_index_r >= 4) begin // finish
            lcd_index_w = lcd_index_r;
          end else begin
            lcd_index_w = lcd_index_r + 1;
          end
          LCD_EN = 1'b0;
        end
        // input characters
        case(lcd_index_r)
          0: LCD_DATA = 8'b01010000; // P
          1: LCD_DATA = 8'b01001100; // L
          2: LCD_DATA = 8'b01000001; // A
          3: LCD_DATA = 8'b01011001; // Y
          default:  LCD_DATA = ZERO;
        endcase
      end else begin
        LCD_EN = 1'b0;
        LCD_DATA = 8'b0;
        state_w = S_CLEAR;
        substate_w = SUB_1;
        flag_timer_rst_w = 1'b1;
      end
    end
//-----------------------PAUSE---------------------------
    PAUSE: begin
      READY  = 1'b0;
      LCD_RS = 1'b1;
      LCD_RW = 1'b0;
      if (INPUT_STATE == INPUT_PAUSE) begin
        // delay for each input
        if (!flag_43us) begin
          flag_timer_rst_w = 1'b0;
          lcd_index_w = lcd_index_r;
          if (lcd_index_r >= 5) begin // finish
            LCD_EN = 1'b0;
          end else begin
            LCD_EN = 1'b1;
          end
        end else begin
          flag_timer_rst_w = 1'b1;
          if (lcd_index_r >= 5) begin // finish
            lcd_index_w = lcd_index_r;
          end else begin
            lcd_index_w = lcd_index_r + 1;
          end
          LCD_EN = 1'b0;
        end
        // input characters
        case(lcd_index_r)
          0: LCD_DATA = 8'b01010000; // P
          1: LCD_DATA = 8'b01000001; // A
          2: LCD_DATA = 8'b01000011; // C
          3: LCD_DATA = 8'b01010101; // U
          4: LCD_DATA = 8'b01000010; // E
          default:  LCD_DATA = ZERO;
        endcase
      end else begin
        LCD_EN = 1'b0;
        LCD_DATA = 8'b0;
        state_w = S_CLEAR;
        substate_w = SUB_1;
        flag_timer_rst_w = 1'b1;
      end
    end

    S_CLEAR: begin
      // state
      if (substate_r==SUB_1) begin
        state_w = state_r;
      end else begin
        state_w = IDLE;
      end
      // clear LCD display
      LCD_DATA = CLEAR;
      LCD_EN   = 1'b0;
      LCD_RW   = 1'b0;
      LCD_RS   = 1'b0;
      READY    = 1'b0;
      lcd_index_w = 6'b0;
      // delay for 1.53ms
      if (!flag_1530us) begin
        substate_w = substate_r;
        flag_timer_rst_w = 1'b0;
      end else begin
        substate_w = SUB_2;
        flag_timer_rst_w = 1'b1;
      end
	end
  endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
  if (i_rst) begin
    timer_r          <= 10'b0;
    state_r          <= INIT;
    substate_r       <= SUB_1;
    flag_timer_rst_r <= 1'b1;
    lcd_index_r      <= 6'b0;
  end else begin
    timer_r          <= timer_w;
    state_r          <= state_w;
    substate_r       <= substate_w;
    flag_timer_rst_r <= flag_timer_rst_w;
    lcd_index_r      <= lcd_index_w;
  end
end
endmodule