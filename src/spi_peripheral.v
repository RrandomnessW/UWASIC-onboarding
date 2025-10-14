module spi_peripheral #(
    // what constants do I use?
    parameter write = 1,
    parameter out_7_0 = 1'h0,       //0x0
    parameter out_15_8 = 1'h1,      //0x1
    parameter pwm_7_0 = 1'h2,       //0x2
    parameter pwm_15_8 = 1'h3,      //0x3
    parameter duty_cycle = 1'h4     //0x4
) (
    input wire clk,
    input wire rst_n,
    input wire sclk,
    input wire cs_n, // deasserted when transaction finishes
    input reg copi,
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);



reg [1:0] sync_chain_copi;  /*  sync_chain_copi: 2 bits, N = 3, N samples needed, Data valid on 3rd cample (3rd shift out)*/

reg [1:0] sync_chain_nCS;   /* sync_chain_nCS: 2 bits, N = 3, N samples needed, Data valid on 3rd cample (3rd shift out)*/

reg [2:0] sync_chain_sclk;  /* sync_chain_sclk: 3 bits, N = 3, N+1 samples stored, 3 bits for the start of the 
                            synchronizer chain. Data valid on the 4th sample (4th bit shift). */

reg cdc_copi_bit;   /*  cdc_copi_bit - copi bit value after CDC*/ 
reg cdc_nCS;        /*  cdc_nCS - cs_n value after CDC*/ 
reg cdc_sclk;       /*  cdc_sclk - sclk value after CDC*/

/* SPI mode 0: data is sampled on rising SCLK edge, data is ready on falling SCLK edge*/
/*  cdc_copi - register used to process SPI message after clock domain crossing (CDC)
    1 bit - Read/Write bit
    7 bits - Register address
    8 bits - Data to be written
    16 bits total
    
    [15] - read/write bit
    [14:8] - register address
    [7:0] - data to be written  */
reg [15:0] copi_data; 
reg copi_ready; /* To prevent duplicate bits being sampled when sclk is high*/
reg [4:0] sclk_cnt; /* To ensure exactly 16 bits are captured. 5 bits total incase count is > 16.*/




always @(posedge clk) begin
    if (!rst_n) begin
        //reset all outputs
        en_reg_out_7_0 <= 0;
        en_reg_out_15_8 <= 0;
        en_reg_pwm_7_0 <= 0;
        en_reg_pwm_15_8 <= 0;
        pwm_duty_cycle <= 0;
        sync_chain_sclk <= 0;
        sync_chain_copi <= 0;
        sync_chain_nCS <= 0;
        cdc_copi_bit <= 0;
        cdc_sclk <= 0;
        cdc_nCS <= 0;
        copi_data <= 0;
        copi_ready <= 0;
        sclk_cnt <= 0;
    end else begin
    
        // Continuously sample data into CDC synchronizers

        // Sampling sclk
        sync_chain_sclk <= (sync_chain_sclk << 1) | sclk;
        cdc_sclk <= sync_chain_sclk[2];

        // Sampling nCS
        sync_chain_nCS <= (sync_chain_nCS << 1) | cs_n;
        cdc_nCS <= sync_chain_nCS[1];

        // Sampling copi bit
        sync_chain_copi <= (sync_chin_copi << 1) | copi;
        cdc_copi_bit <= sync_chain_copi[1];

        // Sample copi_bit when chip select is set low
        if (!cdc_nCS) begin

            if (cdc_sclk && !copi_ready) begin

                // sclk is high, so capture copi bit
                copi_data <= (copi_data << 1) | cdc_copi_bit;

                // track the number of SCLK edges during SPI transaction
                sclk_cnt <= sclk_cnt + 1;

                // mark as a finished copi_bit transaction
                copi_ready <= 1;

            end else if (!cdc_sclk) begin

                // sclk is low, data is now valid, reset copi_ready
                copi_ready <= 0;
            end

        end else begin
            
            // Transaction has finished since cs_n is deasserted. Update register outputs now. 

            if (sclk_cnt == 16 and copi_data[15] == write) begin

                // only update output registers if COPI is a write

                // Wire copi_data[7:0] to the respective register outputs depending on address value
                if (copi_data[14:8] == out_7_0) begin
                    en_reg_out_7_0 <= copi_data[7:0];
                end else if (copi_data[14:8] == out_15_8) begin
                    en_reg_out_15_8 <= copi_data[7:0];
                end else if (copi_data[14:8] == pwm_7_0) begin
                    en_reg_pwm_7_0 <= copi_data[7:0];
                end else if (copi_data[14:8] == pwm_15_8) begin
                    en_reg_pwm_15_8 <= copi_data[7:0];
                end else if (copi_data[14:8] == duty_cycle) begin
                    pwm_duty_cycle <= copi_data[7:0];
                end

            end

            // reset the copi_data reg and sclk_cnt
            copi_data <= 0;
            sclk_cnt <= 0;
        end
           
    end
end

wire _unused = &{};

end module