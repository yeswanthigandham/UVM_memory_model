
interface intf (input logic clk);
  logic        rst;
  logic        rden;
  logic        wren;
  logic [3:0]  addr;
  logic [31:0]  datain;
  logic [31:0]  dataout;
endinterface


// Code your design here
//uvm for mem model


module simple_mem (
  input  logic        clk,
  input  logic        rst,
  input  logic        rden,
  input  logic        wren,
  input  logic [3:0]  addr,
  input  logic [31:0]  datain,
  output logic [31:0]  dataout
);

  logic [31:0] mem [0:15];

  always_ff @(posedge clk) begin
    if (rst) begin
      dataout <= '0;
    end else begin
      if (wren)
        mem[addr] <= datain;

      if (rden)
        dataout <= mem[addr];
    end
  end
endmodule
