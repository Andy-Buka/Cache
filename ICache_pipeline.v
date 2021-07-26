`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/30 09:38:28
// Design Name: 
// Module Name: ICache_pipeline
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//when hit, pipeline, two states
//first state : CPU data input, read request to Cache Ram 
//second state : get Cache Ram read data, output to CPU
`include "defines.v"
/*TODO:valid��rstʱ��գ� cacheָ� ͬʱ��дʱ����*/
module ICache_pipeline(
    input wire clk,
    input wire rst,
    input wire iuncache_i,
    output wire stall, 
    input wire flush,
    
    //Cache port with CPU
    input wire valid,           //valid request
    input wire [31:0] vaddr_i1,
    input wire [31:0] vaddr_i2,
    input wire [31:0] paddr_i,
    output wire data_ok1,       //data transfer out is OK
    output wire data_ok2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] raddr1,
    output wire [31:0] raddr2,
    
    // with BPU
    input wire [34:0] predict_pkti1,
    input wire [34:0] predict_pkti2,
    input wire instbuffer_full,
    output wire [34:0] predict_pkto1,
    output wire [34:0] predict_pkto2,
    output reg [31:0] icache_npc,
    
    //Cache port with AXI
    output wire [7:0] rd_len,
    output wire rd_req,          //read valid request
    output wire [31:0] rd_addr,  //read initial address
    input wire ret_valid,        //return data valid
    input wire [127:0] ret_data
    
    );
    
    wire [19:0] ptag_1;
    wire [7:0] index_1;
    wire [3:0] offset_1;
    wire valid_1;
    wire [31:0] vaddr_i1_1;
    wire [31:0] vaddr_i2_1;
    
    reg [19:0] ptag_2;
    reg [7:0] index_2;
    reg [3:0] offset_2;
    reg valid_2;
    reg [31:0] vaddr_i1_2;
    reg [31:0] vaddr_i2_2;
    reg iuncache_2;
    
    // branch_predict
//    reg [31:0] inst_delayslot_addr, inst_delayslot_addr_ff;
    reg keep_pta, keep_pta_ff;
    reg inst_delayslot, inst_delayslot_ff;
    reg instbuffer_full_ff;
    reg [31:0] icache_npc_ff;
    reg [34:0] predict_pkti1_2, predict_pkti2_2;
    reg inst_delayslot_fetch;  // Ϊ1��ʾȡ�����ӳٲ�ָ��
    reg inst_delayslot_fetch_ff;
    
    wire predict_dir1 = predict_pkti1_2[34];
    wire predict_dir2 = predict_pkti2_2[34];
    wire [31:0] predict_pta1 = predict_pkti1_2[33:2];
    wire [31:0] predict_pta2 = predict_pkti2_2[33:2];
    
    assign ptag_1 = paddr_i[31:12];
    assign index_1 = paddr_i[11:4];
    assign offset_1 = paddr_i[3:0];
    assign valid_1 = valid;
    assign vaddr_i1_1 = vaddr_i1;
    assign vaddr_i2_1 = vaddr_i2;
    
    //* Cache main part: Tagv + Data *//
    
    //each way: 1 TagV(256*21), [1 D(256*1)], 4 DataBank(256*32)
    wire [7:0] read_addr = stall ? index_2 : index_1;
    wire wea_way0;
    wire [20:0] way0_tagv;
    wire [31:0] way0_cacheline[3:0];
    wire rsta_busy1;
    wire rstb_busy1;
    wire read_enb0 = ~(wea_way0 && index_2 == read_addr);
    Tagv_dual_ram tagv_way0(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_tagv), .enb(read_enb0), .rstb(~rst), .rsta_busy(rsta_busy1), .rstb_busy(rstb_busy1));
    Data_dual_ram Bank0_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[0]), .enb(read_enb0));
    Data_dual_ram Bank1_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[1]), .enb(read_enb0));
    Data_dual_ram Bank2_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[2]), .enb(read_enb0));
    Data_dual_ram Bank3_way0(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way0), .wea(wea_way0), .addrb(read_addr), .clkb(clk), .doutb(way0_cacheline[3]), .enb(read_enb0));
    
    wire wea_way1;
    wire [20:0] way1_tagv;
    wire [31:0] way1_cacheline[3:0];
    wire rsta_busy2;
    wire rstb_busy2;
    wire read_enb1 = ~(wea_way1 && index_2 == read_addr);   
    Tagv_dual_ram tagv_way1(.addra(index_2), .clka(clk), .dina({1'b1, ptag_2}), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_tagv), .enb(read_enb1), .rstb(~rst), .rsta_busy(rsta_busy2), .rstb_busy(rstb_busy2));
    Data_dual_ram Bank0_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[0]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[0]), .enb(read_enb1));
    Data_dual_ram Bank1_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[1]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[1]), .enb(read_enb1));
    Data_dual_ram Bank2_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[2]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[2]), .enb(read_enb1));
    Data_dual_ram Bank3_way1(.addra(index_2), .clka(clk), .dina(read_from_AXI[3]), .ena(wea_way1), .wea(wea_way1), .addrb(read_addr), .clkb(clk), .doutb(way1_cacheline[3]), .enb(read_enb1));
    
    
    //* Hit Pipeline: 2 states, Idle and LookUp*//
    //* Not Hit: stall pipeline *//
    
    always@(posedge clk)begin
        if(~rst | flush)begin
            valid_2 <= 1'b0;
            ptag_2 <= 20'b0;
            index_2 <= 8'b0;
            offset_2 <= 4'b0;
            vaddr_i1_2 <= 32'h0;
            vaddr_i2_2 <= 32'h0;
            iuncache_2 <= 1'b0;
//            inst_delayslot_addr_ff <= 32'b0;
            keep_pta_ff <= 1'b0;
            predict_pkti1_2 <= 35'b0;
            predict_pkti2_2 <= 35'b0;
            instbuffer_full_ff <= 1'b0;
        end else if(stall)begin
            valid_2 <= valid_2;
            ptag_2 <= ptag_2;
            index_2 <= index_2;
            offset_2 <= offset_2;
            vaddr_i1_2 <= vaddr_i1_2;
            vaddr_i2_2 <= vaddr_i2_2;
            iuncache_2 <= iuncache_2;
            keep_pta_ff <= keep_pta_ff;
//            inst_delayslot_addr_ff <= inst_delayslot_addr_ff;
            predict_pkti1_2 <= predict_pkti1_2;
            predict_pkti2_2 <= predict_pkti2_2;
            instbuffer_full_ff <= instbuffer_full_ff;
        end else begin
            valid_2 <= valid_1;
            ptag_2 <= ptag_1;
            index_2 <= index_1;
            offset_2 <= offset_1;
            vaddr_i1_2 <= vaddr_i1_1;
            vaddr_i2_2 <= vaddr_i2_1;
            iuncache_2 <= iuncache_i;
            keep_pta_ff <= keep_pta;
//            inst_delayslot_addr_ff <= inst_delayslot_addr;
            predict_pkti1_2 <= predict_pkti1;
            predict_pkti2_2 <= predict_pkti2;
            instbuffer_full_ff <= instbuffer_full;
        end
    end
    
    always @(posedge clk) begin
        if (~rst | flush) begin
            icache_npc_ff <= 32'b0;
            inst_delayslot_fetch_ff <= 1'b1;
            inst_delayslot_ff <= 1'b0;
        end else begin
            icache_npc_ff <= icache_npc;
            inst_delayslot_fetch_ff <= inst_delayslot_fetch;
            inst_delayslot_ff <= inst_delayslot;
        end
    end

    wire hit;                               //hit:1
    wire nhit;
       
    wire data_ok_for_delayslot =  (iuncache_2 && ret_valid) ? 1'b1 :
                                   hit ? 1'b1 : 
                                   (nhit && ret_valid) ? 1'b1: 
                                   1'b0;
    // icache_npc
    always @(*) begin
        if (~rst)                                                           icache_npc = 32'hbfc00000;
//        else if (~inst_delayslot_fetch_ff & inst_delayslot_ff & data_ok1)   icache_npc = inst_delayslot_addr_ff;
//        else if (predict_dir1 & data_ok2)                                   icache_npc = predict_pta1;  // Ԥ���һ��ָ����ת��ȡ���ӳٲ�ָ�����ת
        else if (predict_dir1 & data_ok1)                                   icache_npc = predict_pta1;
        else if (predict_dir2 & data_ok2)                                   icache_npc = predict_pta2;
//        else if (iuncache_2 && icache_npc == vaddr_i1_2)                    icache_npc = vaddr_i2_2;  // iuncacheʱ��Ϊpc+4
        else if (instbuffer_full_ff)                                        icache_npc = icache_npc_ff;
        else if (iuncache_2 & ~keep_pta)                                    icache_npc = vaddr_i2_2;
        else if (stall)                                                     icache_npc = vaddr_i1;  // ��ͣ�򱣳�
        else if (&offset_1[3:2])                                            icache_npc = vaddr_i1 + 32'h4;  // ��ͬ�ֿ�ʱ��Ϊpc+4
        else                                                                icache_npc = vaddr_i1 + 32'h8;
    end
    
    // inst_delayslot
    always @(*) begin
        if (~rst) begin
            inst_delayslot = 1'b0;
//            inst_delayslot_addr = 32'b0;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (~inst_delayslot_fetch_ff & data_ok_for_delayslot) begin
            inst_delayslot = inst_delayslot_ff;
//            inst_delayslot_addr = inst_delayslot_addr_ff;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (inst_delayslot_fetch_ff & inst_delayslot_ff & data_ok1) begin
            inst_delayslot = 1'b0;
//            inst_delayslot_addr = 32'b0;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b0;
        end else if (predict_dir1 & data_ok2) begin
            inst_delayslot = 1'b0;
//            inst_delayslot_addr = 32'b0;
            inst_delayslot_fetch = 1'b0;
            keep_pta = 1'b1;
        end else if (predict_dir1 & data_ok1) begin
            inst_delayslot = 1'b1;
//            inst_delayslot_addr = predict_pta1;  // ȡ���ӳٲ�ָ�����ת��pta1
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b1;
        end else if (predict_dir2 & data_ok2) begin
            inst_delayslot = 1'b1;
//            inst_delayslot_addr = predict_pta2 + 32'h8;
            inst_delayslot_fetch = 1'b1;
            keep_pta = 1'b1;
        end else if (data_ok_for_delayslot) begin
             inst_delayslot = inst_delayslot_ff;
//            inst_delayslot_addr = inst_delayslot_addr_ff;
            inst_delayslot_fetch = inst_delayslot_fetch_ff;
            keep_pta = 1'b0;
        end else begin
            inst_delayslot = inst_delayslot_ff;
//            inst_delayslot_addr = inst_delayslot_addr_ff;
            inst_delayslot_fetch = inst_delayslot_fetch_ff;
            keep_pta = keep_pta_ff;
        end
    end
    
    assign predict_pkto1 = predict_pkti1_2;
    assign predict_pkto2 = predict_pkti2_2;
    
    wire hit_judge_way0;
    wire hit_judge_way1;
    
    //* LRU *//
    reg [255:0] LRU;    //LRU width depends on index
    wire LRU_current = LRU[index_2];
    always@(posedge clk)begin
        if(~rst)begin
            LRU <= 256'b0;
        end else if(data_ok_for_delayslot && hit)begin
            LRU[index_1] <= hit_judge_way0;
        end else if(data_ok_for_delayslot && !hit)begin
            LRU[index_1] <= !hit_judge_way0;
        end else begin
            LRU <= LRU;
        end
    end
    
    wire [31:0]read_from_AXI[3:0];
    for(genvar i = 0 ;i < 4; i = i+1) begin
        assign read_from_AXI[i] = ret_data[32*(i+1)-1:32*i];
    end
    
    // collision 
    reg collision_way0;
    reg collision_way1;
    reg [31:0]inst1_from_mem_2;
    reg [31:0]inst2_from_mem_2;
    reg [20:0]tagv_way0_2;
    reg [20:0]tagv_way1_2;
    
    always@(posedge clk)begin
        collision_way0 <= (wea_way0 && index_1 == index_2);
        collision_way1 <= (wea_way1 && index_1 == index_2);
        inst1_from_mem_2 <= read_from_AXI[offset_1[3:2]];
        inst2_from_mem_2 <= read_from_AXI[offset_1[3:2]+3'h1];
        tagv_way0_2 <= {1'b1,ptag_2};
        tagv_way1_2 <= {1'b1,ptag_2};
    end
    
    //*logics*//
    //////////inner logics
    assign wea_way0 = (ret_valid && LRU_current == 1'b0 && ~iuncache_2);
    assign wea_way1 = (ret_valid && LRU_current == 1'b1 && ~iuncache_2);
    
    //data select
    wire [31:0]inst1_way0 = collision_way0 ? inst1_from_mem_2 : way0_cacheline[offset_2[3:2]];     //cache address partition in page 228
    wire [31:0]inst2_way0 = ~(|raddr2[3:0]) ? 32'b0 : collision_way0 ? inst2_from_mem_2 : way0_cacheline[offset_2[3:2] + 'b1];
    wire [31:0]inst1_way1 = collision_way1 ? inst1_from_mem_2 : way1_cacheline[offset_2[3:2]];
    wire [31:0]inst2_way1 = ~(|raddr2[3:0]) ? 32'b0 : collision_way1 ? inst2_from_mem_2 : way1_cacheline[offset_2[3:2] + 'b1];
    wire [20:0]tagv_final_way0 = collision_way0 ? tagv_way0_2 : way0_tagv;
    wire [20:0]tagv_final_way1 = collision_way1 ? tagv_way1_2 : way1_tagv;
    
    //hit
    assign hit_judge_way0 = (tagv_final_way0[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way0[19:0]) ? 1'b1 : 1'b0;
    assign hit_judge_way1 = (tagv_final_way1[20] != 1'b1) ? 1'b0 : 
                            (ptag_2 == tagv_final_way1[19:0]) ? 1'b1 : 1'b0;
                            
    assign hit = (hit_judge_way0 | hit_judge_way1) && valid_2 && !iuncache_2;
    
//    assign nhit = !(hit_judge_way0 | hit_judge_way1) && valid_2 && !iuncache_2;
    assign nhit = iuncache_2 ? 1'b1 : ~(hit_judge_way0 | hit_judge_way1) & valid_2;    
    
    //////////output logics
    assign data_ok1 = ~inst_delayslot_fetch_ff ? 1'b0 :
                      (iuncache_2 && ret_valid) ? 1'b1 :
                      hit ? 1'b1 : 
                      (nhit && ret_valid) ? 1'b1: 
                      1'b0;
    
    assign data_ok2 = ~inst_delayslot_fetch_ff ? 1'b0 :
                      inst_delayslot_ff ? 1'b0 : 
                      (iuncache_2 && ret_valid) ? 1'b0 :
                      (offset_2[3:2] == 2'b11) ? 1'b0 : 
                      data_ok1;
    
    assign rdata1 = (iuncache_i && ret_valid) ? ret_data[31:0] :
                    (hit && hit_judge_way0) ? inst1_way0 : 
                    (hit && hit_judge_way1) ? inst1_way1 :
                    (nhit && ret_valid && offset_2[3:2] == 2'h0) ? read_from_AXI[0] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h1) ? read_from_AXI[1] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h2) ? read_from_AXI[2] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h3) ? read_from_AXI[3] :
                    32'b0;
    
    assign rdata2 = (hit && hit_judge_way0) ? inst2_way0 : 
                    (hit && hit_judge_way1) ? inst2_way1 :
                    (nhit && ret_valid && offset_2[3:2] == 2'h0) ? read_from_AXI[1] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h1) ? read_from_AXI[2] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h2) ? read_from_AXI[3] :
                    (nhit && ret_valid && offset_2[3:2] == 2'h3) ? read_from_AXI[0] :
                    32'b0;
    
    assign raddr1 = vaddr_i1_2;
    
    assign raddr2 = vaddr_i2_2;
        
    assign rd_len = (iuncache_i & rd_req) ? 8'h0 : 8'h3;
    
    assign rd_req = (nhit && !ret_valid);

    assign rd_addr = iuncache_i ? {ptag_2, index_2, offset_2} : {ptag_2, index_2, 4'b0};
    
    assign stall = (iuncache_2 && data_ok_for_delayslot == 1'b0) ? 1'b1 :
                   (nhit && data_ok_for_delayslot == 1'b0) ? 1'b1 :1'b0 ;
    
endmodule
