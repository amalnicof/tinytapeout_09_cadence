module fir #(
    parameter integer BITS = 8,
    parameter integer TAPS = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire lock,  // lock signal to stop coefficient shifting
    output logic done,  // Done pulse when output data is valid
    input wire coeff_load_in,
    input wire coeff_in,
    input wire [BITS-1:0] x,
    output logic [BITS-1:0] y
);

  localparam integer TAPS_HALF = TAPS >> 1;
  localparam integer SAMPLE_CNT_BITS = $clog2(TAPS_HALF);
  localparam integer BITS_CNT_BITS = $clog2(BITS);

  // control signals
  logic sft, sample_cnt_en, bit_cnt_en, mac_en, sample_cnt_rst;

  integer i;
  integer j;
  // samples LSFR
  reg [TAPS-1:0][BITS-1:0] samples;
  always_ff @(posedge clk) begin
    // reset
    if (!rst_n) begin
      for (i = 0; i < TAPS; i = i + 1) begin
        samples[i] <= 'd0;
      end
      // shifting
    end else begin
      if (start) begin
        for (i = TAPS - 1; i > 0; i = i - 1) begin
          samples[i] <= samples[i-1];
        end
        samples[0] <= x;
      end else if (sft) begin
        samples[0] <= samples[TAPS_HALF-1];
        samples[TAPS_HALF] <= samples[TAPS-1];
        for (i = TAPS_HALF - 1; i > 0; i = i - 1) begin
          samples[i] <= samples[i-1];
        end
        for (j = TAPS - 1; j > TAPS_HALF; j = j - 1) begin
          samples[j] <= samples[j-1];
        end
      end
    end
  end

  integer k;
  integer f;
  // coefficients LSFR
  reg [BITS-1:0] coeffs[TAPS_HALF];
  always_ff @(posedge clk) begin
    // reset
    if (!rst_n) begin
      for (k = 0; k < TAPS_HALF; k = k + 1) begin
        coeffs[k] <= 'd0;
      end
      // shifting
    end else begin
      if (coeff_load_in) begin
        coeffs[0][0] <= coeff_in;
        for (k = 0; k < TAPS_HALF - 1; k++) begin
          // connection between coeffs
          coeffs[k+1][0] <= coeffs[k][BITS-1];

          // Connection within coeffs
          for (f = 0; f < BITS - 1; f++) begin
            coeffs[k][f+1] <= coeffs[k][f];
          end
        end

        // Connection within last coeff
        for (f = 0; f < BITS - 1; f++) begin
          coeffs[TAPS_HALF-1][f+1] <= coeffs[TAPS_HALF-1][f];
        end
      end else if (sft && !lock) begin
        coeffs[0] <= coeffs[TAPS_HALF-1];
        for (k = TAPS_HALF - 1; k > 0; k = k - 1) begin
          coeffs[k] <= coeffs[k-1];
        end
      end
    end
  end

  // sample counter
  reg [SAMPLE_CNT_BITS-1:0] sample_cnt;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      sample_cnt <= 'd0;
    end else begin
      if (sample_cnt_en) begin
        sample_cnt <= sample_cnt + 1'b1;
      end else if (sample_cnt_rst) begin
        sample_cnt <= 'd0;
      end
    end
  end

  // bit counter
  reg [BITS_CNT_BITS-1:0] bit_cnt;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      bit_cnt <= 'd0;
    end else begin
      if ((bit_cnt_en == 1'b1) && (bit_cnt < BITS - 1)) begin
        bit_cnt <= bit_cnt + 1'b1;
      end else begin
        bit_cnt <= 'd0;
      end
    end
  end

  // MAC: Multiply and Accumulate
  logic [1:0] sel;
  logic [BITS-1:0] currCoeff;
  logic [BITS-1:0] currCoeff2;
  logic [BITS-1:0] mux_out;
  logic [BITS-1:0] acc_in;
  always_comb begin
    // create select signal through filter symmetry
    sel = samples[0][bit_cnt] + samples[TAPS-1][bit_cnt];
    currCoeff = coeffs[0] << bit_cnt;
    currCoeff2 = currCoeff << 1;
    // MUX
    case (sel)
      2'b00:   mux_out = 'd0;
      2'b01:   mux_out = currCoeff;
      2'b10:   mux_out = currCoeff2;
      default: mux_out = 'd0;
    endcase
    acc_in = y + mux_out;
  end

  // accumulator register
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      y <= 'd0;
    end else begin
      if (start) begin
        y <= 'd0;
      end else if (mac_en) begin
        y <= acc_in;
      end
    end
  end

  // STATE MACHINE
  typedef enum logic [1:0] {
    IDLE,
    COEFF_LD,
    OP,
    SHIFT
  } state_e;

  state_e n_state, state;
  // transition states
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= n_state;
    end
  end

  // next state
  always_comb begin
    case (state)
      IDLE: begin
        if (start) n_state = OP;
        else if (coeff_load_in) n_state = COEFF_LD;
        else n_state = IDLE;
      end

      COEFF_LD: begin
        if (coeff_load_in) n_state = COEFF_LD;
        else n_state = IDLE;
      end

      OP: begin
        if (bit_cnt < BITS - 2) n_state = OP;
        else n_state = SHIFT;
      end

      SHIFT: begin
        if (sample_cnt < TAPS_HALF - 1) n_state = OP;
        else n_state = IDLE;
      end

      default: begin
      end
    endcase
  end

  // control signals
  always_comb begin
    sft = 1'b0;
    sample_cnt_en = 1'b0;
    bit_cnt_en = 1'b0;
    mac_en = 1'b0;
    sample_cnt_rst = 1'b0;
    done = 1'b0;
    case (state)
      IDLE: begin
        sample_cnt_rst = 1'b1;
      end

      COEFF_LD: begin
      end

      OP: begin
        mac_en = 1'b1;
        bit_cnt_en = 1'b1;
      end

      SHIFT: begin
        sft = 1'b1;
        mac_en = 1'b1;
        bit_cnt_en = 1'b1;
        sample_cnt_en = 1'b1;

        if (n_state == IDLE) begin
          done = 1'b1;
        end
      end

      default: begin
      end
    endcase
  end
endmodule
