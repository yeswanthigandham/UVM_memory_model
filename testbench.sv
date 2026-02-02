package tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  //`uvm_object_utils(seq_item)
  
  rand bit [31:0]datain;
  rand bit [3:0]addr;
  rand bit wren;
  rand bit rden;
  bit [31:0]dataout;
  
  function new(string name="seq_item");
    super.new(name);
  endfunction
  
  constraint address { addr inside {[0:15]}; }
  constraint rd_wren { rden + wren <= 1 ; }
  
  `uvm_object_utils_begin(seq_item)
    `uvm_field_int(datain,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_int(wren,UVM_ALL_ON)
    `uvm_field_int(rden,UVM_ALL_ON)
  `uvm_field_int(dataout,UVM_ALL_ON)
  `uvm_object_utils_end
 
endclass

class myseq extends uvm_sequence#(seq_item);
  `uvm_object_utils(myseq)
  rand int num;
  function new(string name="myseq");
    super.new(name);
  endfunction
  constraint rand_num { 
    num inside {[1:100]};
  }
  virtual task body;
    `uvm_info(get_type_name(),"Inside sequence body task\n",UVM_LOW);
    assert(this.randomize());
    `uvm_info(get_type_name(),$sformatf(" randomised num %0d \n",num),UVM_LOW);
    repeat(num)
      begin
        seq_item seq_item1;
        seq_item1=seq_item::type_id::create("seq_item1");
        start_item(seq_item1);
        assert(seq_item1.randomize());
        finish_item(seq_item1);
        
      end
  endtask
  
endclass

class seqr extends uvm_sequencer#(seq_item);
  `uvm_component_utils(seqr)
  
  function new(string name="seqr",uvm_component parent);
    super.new(name,parent);
  endfunction
  
   
endclass

class driver extends uvm_driver#(seq_item);
  `uvm_component_utils(driver)
  virtual intf vif;
  
  function new(string name="driver",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual intf)::get(this,"","vif",vif)) begin
       `uvm_error(get_type_name(),"Error getting virtual intf");
    end
  endfunction
       
  task run_phase(uvm_phase phase);
  
    forever begin
      seq_item seq_item1;
      seq_item_port.get_next_item(seq_item1);
       @(posedge vif.clk);
      vif.datain <= seq_item1.datain;
      vif.addr <= seq_item1.addr;
      vif.wren <= seq_item1.wren;
      vif.rden <=seq_item1.rden;
      
      seq_item_port.item_done();
      
    end
    
  endtask
  
endclass

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  virtual intf vif;
  
  uvm_analysis_port#(seq_item) a_port;
  
  seq_item seq_item1;
  
  function new(string name="mon",uvm_component parent);
    super.new(name,parent);
    a_port=new("a_port",this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual intf)::get(this,"","vif",vif))
       `uvm_error(get_type_name(),"Error getting virtual intf");
  endfunction
       
  task run_phase(uvm_phase phase);
    forever begin
      seq_item1=seq_item::type_id::create("seq_item1",this);
        @(posedge vif.clk);
      if(vif.wren) begin
      seq_item1.datain = vif.datain;
      seq_item1.addr = vif.addr;
      seq_item1.wren = vif.wren;
      end
      else if (vif.rden) begin
      seq_item1.addr = vif.addr;
      seq_item1.rden = vif.rden; 
        @(posedge vif.clk);
      seq_item1.dataout = vif.dataout; 
      end
      a_port.write(seq_item1);
      
    end
         
  endtask
       
endclass
       

class agent extends uvm_agent;
    `uvm_component_utils(agent)
    seqr seqr1;
    driver driver1;
    monitor monitor1;
    
    
    function new(string name="agent",uvm_component parent);
      super.new(name,parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor1=monitor::type_id::create("monitor1",this);
      if(get_is_active()==UVM_ACTIVE) begin
      	seqr1=seqr::type_id::create("seqr1",this);
        driver1 =driver::type_id::create("driver1",this);
      end

    endfunction
    
    
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if(get_is_active() == UVM_ACTIVE) begin
      driver1.seq_item_port.connect(seqr1.seq_item_export);
      end
    endfunction
    
    
    
endclass

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  
  uvm_analysis_imp#(seq_item,scoreboard) a_export;
  
  bit [31:0]ref_mem[16];
  
  function new(string name="scoreboard",uvm_component parent);
    super.new(name,parent);
   
  endfunction
  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     a_export=new("a_export",this);
  endfunction
  
  virtual function void write(seq_item seq_item1);
    if(seq_item1.wren) begin
      ref_mem[seq_item1.addr]=seq_item1.datain;
      `uvm_info(get_type_name(),$sformatf(" addr=%0d  data=%0h\n",seq_item1.addr,seq_item1.datain),UVM_LOW);
      
    end
    else if(seq_item1.rden) begin
      
      if(seq_item1.dataout !== ref_mem[seq_item1.addr])
           begin
             
             `uvm_info(get_type_name(),$sformatf("mismatch in read data addr=%0d EXP=%0h and ACT=%0h \n",seq_item1.addr,ref_mem[seq_item1.addr],seq_item1.dataout),UVM_LOW);
             `uvm_error(get_type_name(),"mismatch in read data \n");
           end
      else begin
        `uvm_info(get_type_name(),$sformatf("MATCH in read data addr=%0d EXP=%0h and ACT=%0h \n",seq_item1.addr,ref_mem[seq_item1.addr],seq_item1.dataout),UVM_LOW);        
      end
    end
    
    
  endfunction
  
  
endclass
       
class env extends uvm_env;
  `uvm_component_utils(env)
  agent ag;
  scoreboard scbd;
  
  function new(string name="env",uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ag=agent::type_id::create("ag",this);
    scbd=scoreboard::type_id::create("scbd",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ag.monitor1.a_port.connect(scbd.a_export);
  endfunction
  
  
endclass
       
class basic_test extends uvm_test;
  `uvm_component_utils(basic_test)

  env env1; 
  
  function new(string name="basic_test",uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env1=env::type_id::create("env1",this);
  endfunction
  
  task run_phase(uvm_phase phase);
    myseq myseq1;
    phase.raise_objection(this);
    myseq1=myseq::type_id::create("myseq1");
    myseq1.start(env1.ag.seqr1);
    phase.drop_objection(this);
  endtask
  
endclass

       
endpackage



`timescale 1ns/1ps
import uvm_pkg::*;
import tb_pkg::*;
`include "uvm_macros.svh"

module tb_top;

  // Clock
  logic clk;

  // Interface
   intf vif (clk);

  // DUT instance
  simple_mem dut (
    .clk     (clk),
    .rst     (vif.rst),
    .rden    (vif.rden),
    .wren    (vif.wren),
    .addr    (vif.addr),
    .datain  (vif.datain),
    .dataout (vif.dataout)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;   // 100 MHz
  end

  // Reset generation
  initial begin
    vif.rst    = 1;
    vif.rden   = 0;
    vif.wren   = 0;
    vif.addr   = 0;
    vif.datain = 0;

    repeat (2) @(posedge clk);
    vif.rst = 0;
  end

  // UVM configuration and test start
  initial begin
    // Make virtual interface visible to UVM
    uvm_config_db#(virtual intf)::set(
      null, "*", "vif", vif
    );

    // Start UVM
    run_test("basic_test");
    
    
  end

  initial begin
    $dumpvars;
    $dumpfile ("dump.vcd");
  end
  
initial begin
  #1000;
  $finish;
end
  
endmodule
