`timescale 1 ns / 100 ps

module tb_axi4l_ipif ();

    parameter C_ADDR_WIDTH = 12;
    parameter C_DATA_WIDTH = 32;

    // AXI i/f
    //---------
    logic aclk    = 0;
    logic aresetn = 0;
    //
    logic [C_ADDR_WIDTH-1:0] s_axi_awaddr  = 0;
    logic [             2:0] s_axi_awprot  = 0;
    logic                    s_axi_awvalid = 0;
    logic                    s_axi_awready = 0;
    //
    logic [  C_DATA_WIDTH-1:0] s_axi_wdata  = 0;
    logic [C_DATA_WIDTH/8-1:0] s_axi_wstrb  = 0;
    logic                      s_axi_wvalid = 0;
    logic                      s_axi_wready = 0;
    //
    logic [1:0] s_axi_bresp  = 0;
    logic       s_axi_bvalid = 0;
    logic       s_axi_bready = 0;
    //
    logic [C_ADDR_WIDTH-1:0] s_axi_araddr  = 0;
    logic [             2:0] s_axi_arprot  = 0;
    logic                    s_axi_arvalid = 0;
    logic                    s_axi_arready = 0;
    //
    logic [C_DATA_WIDTH-1:0] s_axi_rdata  = 0;
    logic [             1:0] s_axi_rresp  = 0;
    logic                    s_axi_rvalid = 0;
    logic                    s_axi_rready = 0;

    // Write i/f
    //-----------
    logic [31:0] reg_a_b = 0;
    logic [31:0] reg_c_d = 0;

    // Stimulation

    always #5 aclk = ~aclk;

    //-------------------------------------------------------------------------
    // Task: reset_slave_and_interface
    // Brief: Reset the DUT and all input signal to DUT
    //-------------------------------------------------------------------------

    task reset_slave_and_interface();
        @(posedge aclk);
        // AXI
        aresetn <= 0;
        s_axi_awaddr  <= 0;
        s_axi_awprot  <= 0;
        s_axi_awvalid <= 0;
        s_axi_wdata   <= 0;
        s_axi_wstrb   <= 0;
        s_axi_wvalid  <= 0;
        s_axi_bready  <= 0;
        s_axi_araddr  <= 0;
        s_axi_arprot  <= 0;
        s_axi_arvalid <= 0;
        s_axi_rready  <= 0;
        // WR
        reg_a_b <= 0;
        reg_c_d <= 0;
        repeat(16) @(posedge aclk);
        @(posedge aclk) aresetn <= 1;
        repeat(16) @(posedge aclk);
    endtask;

    // Test cases

    //-------------------------------------------------------------------------
    // Task: test_single_write_same_time
    // Brief: Test if DUT can accept signal AXI write. Only write response is
    //        checked. No write effect is checked.
    //-------------------------------------------------------------------------

    task test_single_write_same_time();
        logic awok, wok, bok, wregok;
        awok = 0;
        wok = 0;
        bok = 0;
        wregok = 0;
        reset_slave_and_interface();

        fork
            // Set write address
            begin
                @(posedge aclk);
                s_axi_awaddr  <= 32'b0;
                s_axi_awvalid <= 1'b1;
                repeat(16) begin
                    @(posedge aclk);
                    if (s_axi_awready) begin
                        awok = 1;
                        s_axi_awvalid <= 1'b0;
                        break;
                    end
                end
            end

            // Set write data
            begin
                @(posedge aclk);
                s_axi_wdata   <= 32'hABCD_1234;
                s_axi_wstrb   <= 4'b1111;
                s_axi_wvalid  <= 1'b1;
                repeat(16) begin
                    @(posedge aclk);
                    if (s_axi_wready) begin
                        wok = 1;
                        s_axi_wvalid <= 1'b0;
                        break;
                    end
                end
            end

            // Response to write
            begin
                @(posedge aclk);
                s_axi_bready  <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_bvalid) begin
                        bok = 1;
                        s_axi_bready <= 1'b0;
                        break;
                    end
                end
            end

            // Check written data
            begin
                repeat(16) begin
                    @(posedge aclk);
                    if (reg_a_b == 32'hABCD_1234) begin
                        wregok <= 1;
                        break;
                    end
                end
            end

        join

        @(posedge aclk);
        if (awok && wok && bok && wregok) begin
            $info("%t, Test \"test_single_write_sampe_time\" success.", $time);
        end else begin
            $warning("%t, Test \"test_single_write_sampe_time\" fail.", $time());
        end
    endtask;


    //-------------------------------------------------------------------------
    // Task: test_single_write_address_before_data
    // Brief: Test if DUT can accept signal AXI write. Write address is assert
    //        before data. Only write response is checked. No write effect is
    //        checked.
    //-------------------------------------------------------------------------

    task test_single_write_address_before_data();
        logic awok, wok, bok, wregok;
        awok = 0;
        wok = 0;
        bok = 0;
        wregok = 0;
        reset_slave_and_interface();

        fork
            // Set write address
            begin
                @(posedge aclk);
                s_axi_awaddr  <= 32'b0;
                s_axi_awvalid <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_awready) begin
                        awok = 1;
                        s_axi_awvalid <= 1'b0;
                        break;
                    end
                end
            end

            // Set write data
            begin
                @(posedge aclk);
                @(posedge aclk);
                s_axi_wdata   <= 32'hABCD_1234;
                s_axi_wstrb   <= 4'b1111;
                s_axi_wvalid  <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_wready) begin
                        wok = 1;
                        s_axi_wvalid <= 1'b0;
                        break;
                    end
                end
            end

            // Response to write
            begin
                @(posedge aclk);
                s_axi_bready  <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_bvalid) begin
                        bok = 1;
                        s_axi_bready <= 1'b0;
                        break;
                    end
                end
            end

            // Check written data
            begin
                repeat(16) begin
                    @(posedge aclk);
                    if (reg_a_b == 32'hABCD_1234) begin
                        wregok <= 1;
                        break;
                    end
                end
            end

        join

        @(posedge aclk);
        if (awok && wok && bok && wregok) begin
            $info("%t, Test \"test_single_write_address_before_data\" success.", $time());
        end else begin
            $warning("%t, Test \"test_single_write_address_before_data\" fail.", $time());
        end
    endtask;


    //-------------------------------------------------------------------------
    // Task: test_single_read
    // Brief: Test if DUT can accept signal AXI read. Read response is present
    //        after address is assert. Only read response is checked. No read
    //        effect is checked.
    //-------------------------------------------------------------------------

    task test_single_read();
        logic arok, rok;
        arok = 0;
        rok = 0;
        reset_slave_and_interface();

        fork

            begin
                @(posedge aclk);
                reg_c_d <= 32'hABCD_1234;
            end

            // Set read address
            begin
                @(posedge aclk);
                s_axi_araddr  <= 32'h0000_0004;
                s_axi_arvalid <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_arready) begin
                        arok = 1;
                        s_axi_arvalid <= 1'b0;
                        break;
                    end
                end
            end

            // Response to read
            begin
                @(posedge aclk);
                s_axi_rready  <= 1'b1;
                repeat (16) begin
                    @(posedge aclk);
                    if (s_axi_rvalid) begin
                        if (s_axi_rdata == 32'hABCD_1234) begin
                            rok = 1;
                        end
                        s_axi_rready <= 1'b0;
                        break;
                    end
                end
            end

        join

        @(posedge aclk);
        if (arok && rok) begin
            $info("%t, Test \"test_single_read\" success.", $time());
        end else begin
            $warning("%t, Test \"test_single_read\" fail.", $time());
        end
    endtask;

    initial begin
        $display("%t, simulation ends.", $time());

        #1000;
        test_single_write_same_time();
        #1000;
        test_single_write_address_before_data();
        #1000;
        test_single_read();
        #1000;

        $finish();
    end

    final begin
        $display("%t, simulation ends.", $time());
    end

    axi4l_slv_top #(
        .C_ADDR_WIDTH(C_ADDR_WIDTH),
        .C_DATA_WIDTH(C_DATA_WIDTH)
    ) UUT (.*);

endmodule
