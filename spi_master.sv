module spi_master #(
    parameter int DATA_WIDTH = 8  // Default data width
)(
    input  logic                   clk_i,       // System clock
    input  logic                   reset_n_i,   // Active-low reset
    input  logic [DATA_WIDTH-1:0]  data_in_i,   // Data to transmit
    input  logic                   start_i,     // Start signal
    output logic                   MOSI_o,      // Master Out Slave In
    output logic                   SCK_o,       // SPI Clock
    output logic                   done_o       // Transmission complete
);

    // Internal signals
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        TRANSMIT = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state_ff, next_state;
    logic [DATA_WIDTH-1:0] shift_reg_ff;       // Shift register
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt_ff; // Bit counter
    logic clk_div_ff;                          // Clock divider

    // Clock Divider: Divide the system clock for SPI clock generation
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i)
            clk_div_ff <= 1'b0;
        else
            clk_div_ff <= ~clk_div_ff;
    end

    assign SCK_o = clk_div_ff;

    // Next-State Logic
    always_comb begin
        next_state = current_state_ff; // Default hold state
        case (current_state_ff)
            IDLE: if (start_i) next_state = TRANSMIT;
            TRANSMIT: if (bit_cnt_ff == 0) next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE; // Handles unexpected cases
        endcase
    end

    // Sequential State Updates
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            current_state_ff <= IDLE;
        end else begin
            current_state_ff <= next_state;
        end
    end

    // Output Logic
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            shift_reg_ff <= '0;
            bit_cnt_ff <= '0;
            done_o <= 1'b0;
        end else begin
            case (current_state_ff)
                IDLE: begin
                    done_o <= 1'b0;
                    if (start_i) begin
                        shift_reg_ff <= data_in_i;             // Load data into shift register
                        bit_cnt_ff <= DATA_WIDTH[$clog2(DATA_WIDTH)-1:0] - 1; // Correct assignment
                    end
                end
                TRANSMIT: begin
                    if (clk_div_ff) begin
                        MOSI_o <= shift_reg_ff[DATA_WIDTH-1]; // Transmit MSB first
                        shift_reg_ff <= {shift_reg_ff[DATA_WIDTH-2:0], 1'b0}; // Shift register
                        bit_cnt_ff <= bit_cnt_ff - 1;         // Decrement bit counter
                    end
                end
                DONE: begin
                    done_o <= 1'b1;                          // Indicate completion
                end
                default: begin
                    done_o <= 1'b0;
                end
            endcase
        end
    end

endmodule
