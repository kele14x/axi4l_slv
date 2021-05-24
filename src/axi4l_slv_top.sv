//*****************************************************************************
//  Copyright (C) 2020  kele14x
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//*****************************************************************************
`timescale 1 ns / 1 ps `default_nettype none

// Note: AxPROT not supported (not connected)

module axi4l_slv_top #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32
) (
    // AXI4-Lite Slave
    //=================
    input var                     aclk,
    input var                     aresetn,
    //
    input var  [  ADDR_WIDTH-1:0] s_axi_awaddr,
    input var  [             2:0] s_axi_awprot,
    input var                     s_axi_awvalid,
    output var                    s_axi_awready,
    //
    input var  [  DATA_WIDTH-1:0] s_axi_wdata,
    input var  [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input var                     s_axi_wvalid,
    output var                    s_axi_wready,
    //
    output var [             1:0] s_axi_bresp,
    output var                    s_axi_bvalid,
    input var                     s_axi_bready,
    //
    input var  [  ADDR_WIDTH-1:0] s_axi_araddr,
    input var  [             2:0] s_axi_arprot,
    input var                     s_axi_arvalid,
    output var                    s_axi_arready,
    //
    output var [  DATA_WIDTH-1:0] s_axi_rdata,
    output var [             1:0] s_axi_rresp,
    output var                    s_axi_rvalid,
    input var                     s_axi_rready,
    // IRQ Ports
    //==========
    output var                    irq_reg_irq,
    // Register Ports
    //===============
    // Register REG_IRQ
    // Field REG_IRQ.BIT0
    input var                     reg_irq_bit0,
    // Register A
    // Field A.B
    output var [            31:0] reg_a_b,
    // Register C
    // Field C.D
    input var  [            31:0] reg_c_d
);

  initial begin
    assert ((DATA_WIDTH == 32) || (DATA_WIDTH == 64))
    else $error("AXI-4 Lite interface only support DATA_WIDTH=32 or 64");
  end

  // RRESP/BRESP
  localparam logic [1:0] RespOkay = 2'b00;  // OKAY, normal access success
  localparam logic [1:0] ResqExokay = 2'b01;  // EXOKAY, exclusive access success
  localparam logic [1:0] ResqSlverr = 2'b10;  // SLVERR, slave error
  localparam logic [1:0] ResqDecerr = 2'b11;  // DECERR, decoder error


  // Write State Machine
  //=====================

  typedef enum int {
    S_WRRST,  // in reset
    S_WRIDLE,  // idle, waiting for both write address and write data
    S_WRADDR,  // write data is provided, waiting for write address
    S_WRDATA,  // write address is provided, waiting for write data
    S_WRREQ,  // Set write request
    S_WRDEC,  // write transaction decode
    S_WRRESP  // response to axi master
  } wr_state_t;

  wr_state_t wr_state, wr_state_next;

  var logic wr_valid, wr_addr_valid, wr_data_valid;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_state <= S_WRRST;
    end else begin
      wr_state <= wr_state_next;
    end
  end

  always_comb begin
    case (wr_state)
      S_WRRST: wr_state_next = S_WRIDLE;
      S_WRIDLE:
      wr_state_next = (s_axi_awvalid && s_axi_wvalid) ? S_WRREQ :
                                                         s_axi_awvalid ? S_WRADDR :
                                                         s_axi_wvalid  ? S_WRDATA : S_WRIDLE;
      S_WRADDR: wr_state_next = !s_axi_wvalid ? S_WRADDR : S_WRREQ;
      S_WRDATA: wr_state_next = !s_axi_awvalid ? S_WRDATA : S_WRREQ;
      S_WRREQ: wr_state_next = S_WRDEC;
      S_WRDEC: wr_state_next = S_WRRESP;
      S_WRRESP: wr_state_next = !s_axi_bready ? S_WRRESP : S_WRIDLE;
      default: wr_state_next = S_WRRST;
    endcase
  end

  assign wr_valid = ((wr_state == S_WRIDLE) && s_axi_awvalid && s_axi_wvalid) ||
        ((wr_state == S_WRADDR) && s_axi_wvalid) ||
        ((wr_state == S_WRDATA) && s_axi_awvalid);

  assign wr_addr_valid = ((wr_state == S_WRIDLE) && s_axi_awvalid) ||
        ((wr_state == S_WRDATA) && s_axi_awvalid);

  assign wr_data_valid = ((wr_state == S_WRIDLE) && s_axi_wvalid) ||
        ((wr_state == S_WRADDR) && s_axi_wvalid);


  // Write Address Channel
  //-----------------------

  var logic [ADDR_WIDTH-3:0] wr_addr;

  // We are waiting for both write address and write data, but only write
  // address is provided. Register it for later use.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_addr <= 'd0;
    end else if (wr_addr_valid) begin
      wr_addr <= s_axi_awaddr[ADDR_WIDTH-1:2];
    end
  end

  // Slave can accept write address if idle, or if only write data is
  // provided.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_awready <= 1'b0;
    end else begin
      s_axi_awready <= (wr_state_next == S_WRIDLE || wr_state_next == S_WRDATA);
    end
  end


  // Write Data Channel
  //--------------------

  var logic [  DATA_WIDTH-1:0] wr_data;
  var logic [DATA_WIDTH/8-1:0] wr_be;

  // We are waiting for both write address and write data, but only write
  // data is provided. Register it for later use.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_data <= 'd0;
      wr_be   <= 'd0;
    end
    if (wr_data_valid) begin
      wr_data <= s_axi_wdata;
      wr_be   <= s_axi_wstrb;
    end
  end

  // Slave can accpet write data if idle, or if only write address is
  // provided.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_wready <= 1'b0;
    end else begin
      s_axi_wready <= (wr_state_next == S_WRIDLE || wr_state_next == S_WRADDR);
    end
  end


  // Write response channel
  //------------------------

  var logic wr_req, wr_dec_err;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_req <= 1'b0;
    end else begin
      wr_req <= wr_valid;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_bvalid <= 1'b0;
    end else begin
      s_axi_bvalid <= (wr_state_next == S_WRRESP);
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_bresp <= 0;
    end else if (wr_req) begin
      s_axi_bresp <= wr_dec_err ? ResqDecerr : RespOkay;
    end
  end


  // Read State Machine
  //====================

  // Read Iteration Interval = 2 (back-to-back read transaction)
  // Read Latency = 2 (from AWADDR transaction to RDATA transaction)

  typedef enum int {
    S_RDRST,
    S_RDIDLE,
    S_RDREQ,
    S_RDDEC,
    S_RDRESP
  } rd_state_t;

  rd_state_t rd_state, rd_state_next;

  var logic rd_valid;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_state <= S_RDRST;
    end else begin
      rd_state <= rd_state_next;
    end
  end

  always_comb begin
    case (rd_state)
      S_RDRST:  rd_state_next = S_RDIDLE;
      S_RDIDLE: rd_state_next = !s_axi_arvalid ? S_RDIDLE : S_RDREQ;
      S_RDREQ:  rd_state_next = S_RDDEC;
      S_RDDEC:  rd_state_next = S_RDRESP;
      S_RDRESP: rd_state_next = !s_axi_rready ? S_RDRESP : S_RDIDLE;
      default:  rd_state_next = S_RDRST;
    endcase
  end

  assign rd_valid = (rd_state == S_RDIDLE) && s_axi_arvalid;


  // Read Address Channel
  //----------------------

  var logic [ADDR_WIDTH-3:0] rd_addr;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_addr <= 'd0;
    end else if (rd_valid) begin
      rd_addr <= s_axi_araddr[ADDR_WIDTH-1:2];
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_arready <= 1'b0;
    end else begin
      s_axi_arready <= (rd_state_next == S_RDIDLE);
    end
  end


  // Read Data/Response Channel
  //-------------------

  var logic rd_req, rd_dec_err;
  var logic [DATA_WIDTH-1:0] rd_data;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_req <= 1'b0;
    end else begin
      rd_req <= rd_valid;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_rvalid <= 1'b0;
    end else begin
      s_axi_rvalid <= (rd_state_next == S_RDRESP);
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_rdata <= 0;
    end else if (rd_req) begin
      s_axi_rdata <= rd_data;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axi_rresp <= 0;
    end else if (rd_req) begin
      s_axi_rresp <= rd_dec_err ? ResqDecerr : RespOkay;
    end
  end


  // Register Model
  //===============

  // Register REG_IRQ @ Address Offset 0
  //------------------------------------

  // Field REG_IRQ.BIT0 @ Bit Offset 0
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  logic reg_irq_bit0_ireg;
  logic reg_irq_bit0_d;
  logic reg_irq_bit0_int;
  logic reg_irq_bit0_trap;
  logic reg_irq_bit0_mask;
  logic reg_irq_bit0_force;
  logic reg_irq_bit0_dbg;
  logic reg_irq_bit0_trig;

  always_ff @(posedge aclk) begin
    reg_irq_bit0_ireg <= reg_irq_bit0;
    reg_irq_bit0_d <= reg_irq_bit0_ireg;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_irq_bit0_int <= 'b0;
    end else begin
      reg_irq_bit0_int <= reg_irq_bit0_trap & reg_irq_bit0_mask;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_irq_bit0_trap <= 'b0;
    end else if (wr_req && wr_addr == 'd1) begin
      reg_irq_bit0_trap <= reg_irq_bit0_trap & wr_data[0];
    end else begin
      reg_irq_bit0_trap <= reg_irq_bit0_trap |
        (reg_irq_bit0_ireg & (~reg_irq_bit0_d | ~reg_irq_bit0_trig));
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_irq_bit0_mask <= 'b0;
    end else if (wr_req && wr_addr == 'd2) begin
      reg_irq_bit0_mask <= wr_data[0];
    end else begin
      reg_irq_bit0_mask <= reg_irq_bit0_mask;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_irq_bit0_force <= 'b0;
    end else if (wr_req && wr_addr == 'd3) begin
      reg_irq_bit0_force <= wr_data[0];
    end else begin
      reg_irq_bit0_force <= 'b0;
    end
  end

  always_ff @(posedge aclk) begin
    reg_irq_bit0_dbg <= reg_irq_bit0_ireg;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_irq_bit0_trig <= 'b0;
    end else if (wr_req && wr_addr == 'd5) begin
      reg_irq_bit0_trig <= wr_data[0];
    end else begin
      reg_irq_bit0_trig <= reg_irq_bit0_trig;
    end
  end

  // Register REG_A @ Address Offset 8
  //----------------------------------

  // Field B @ Bit Offset 0
  //~~~~~~~~~~~~~~~~~~~~~~~

  logic [31:0] reg_a_b_oreg;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      reg_a_b_oreg <= 'b0;
    end else if (wr_valid && wr_addr == 'd8) begin
      reg_a_b_oreg <= wr_data;
    end else begin
      reg_a_b_oreg <= reg_a_b_oreg;
    end
  end

  assign reg_a_b = reg_a_b_oreg;

  // Register REG_C @ Address Offset 9
  //----------------------------------

  // Field D @ Bit Offset 0
  //~~~~~~~~~~~~~~~~~~~~~~~

  logic [31:0] reg_c_d_ireg;

  always_ff @(posedge aclk) begin
    reg_c_d_ireg <= reg_c_d;
  end

  // Write Decode
  //=============

  // If master is tring to write to a hole register, return a decode error
  always_ff @(posedge aclk) begin
    case (wr_addr)
      'd0:     wr_dec_err <= 1'b0;
      'd1:     wr_dec_err <= 1'b0;
      'd2:     wr_dec_err <= 1'b0;
      'd3:     wr_dec_err <= 1'b0;
      'd4:     wr_dec_err <= 1'b0;
      'd5:     wr_dec_err <= 1'b0;
      'd8:     wr_dec_err <= 1'b0;
      default: wr_dec_err <= 1'b1;
    endcase
  end


  // Read Data
  //==========

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_data <= 'b0;
    end else if (rd_req && rd_addr == 'd8) begin
      rd_data <= reg_a_b_oreg;
    end else if (rd_req && rd_addr == 'd9) begin
      rd_data <= reg_c_d_ireg;
    end
  end


  // Read Decode
  //============

  // Register.Field A.B
  always_ff @(posedge aclk) begin
    case (rd_addr)
      'd0:     rd_dec_err <= 1'b0;
      'd1:     rd_dec_err <= 1'b0;
      'd2:     rd_dec_err <= 1'b0;
      'd3:     rd_dec_err <= 1'b0;
      'd4:     rd_dec_err <= 1'b0;
      'd5:     rd_dec_err <= 1'b0;
      'd8:     rd_dec_err <= 1'b0;
      default: rd_dec_err <= 1'b1;
    endcase
  end

endmodule

`default_nettype wire
