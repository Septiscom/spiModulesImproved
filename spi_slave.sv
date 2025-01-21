module spi_slave #(
    parameter int DATA_WIDTH = 8  // Default data width
)(
    input  logic                   clk_i,      // System clock
    input  logic                   reset_n_i,  // Active-low reset
    input  logic                   MOSI_i,     // Master Out Slave In
    input  logic                   SCK_i,      // SPI clock from master
    input  logic                   start_i,    // Start signal for reception
    output logic [DATA_WIDTH-1:0]  data_out_o, // Received data
    output logic                   done_o      // Reception complete indicator
);
    // Internal signals
    logic [DATA_WIDTH-1:0]         shift_reg;        // Shift register for assembling data
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt;          // Bit counter
    logic [1:0]                    sck_sync_ff;      // Double flop for SCK synchronization
    logic                          sck_rising_edge;  // Rising edge detection

    // Synchronize SCK to local clock domain
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i)
            sck_sync_ff <= 2'b00;
        else
            sck_sync_ff <= {sck_sync_ff[0], SCK_i};
    end
    assign sck_rising_edge = ~sck_sync_ff[0] & sck_sync_ff[1];

    // FSM states
    typedef enum logic [1:0] {IDLE, RECEIVING, DONE} state_t;
    state_t current_state_ff, next_state;

    // FSM: State transitions
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i)
            current_state_ff <= IDLE;
        else
            current_state_ff <= next_state;
    end

    // FSM: Next state logic
    always_comb begin
        next_state = current_state_ff;
        case (current_state_ff)
            IDLE: if (start_i) next_state = RECEIVING;
            RECEIVING: if (bit_cnt == 0 && sck_rising_edge) next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE; // Handles unexpected states
        endcase
    end

    // FSM: Output logic
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            done_o <= 1'b0;
        end else begin
            case (current_state_ff)
                IDLE: done_o <= 1'b0;
                RECEIVING: done_o <= 1'b0;
                DONE: done_o <= 1'b1;
                default: done_o <= 1'b0; // Default safety logic
            endcase
        end
    end

    // Shift register and bit counter
    always_ff @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            data_out_o <= '0;
        end else if (current_state_ff == IDLE && start_i) begin
            // Initialize shift register and counter
            bit_cnt <= DATA_WIDTH[$clog2(DATA_WIDTH)-1:0] - 1; // Corrected bitwidth
        end else if (current_state_ff == RECEIVING && sck_rising_edge) begin
            // Shift data into register on SCK rising edge
            shift_reg[bit_cnt] <= MOSI_i;
            if (bit_cnt == 0)
                data_out_o <= shift_reg; // Update output data on last bit
            else
                bit_cnt <= bit_cnt - 1;  // Decrement bit counter
        end
    end
endmodule
