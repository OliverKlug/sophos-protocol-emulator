task host;
    input [2:0] cmd;
    input [3:0] nib;
    begin
        @(negedge clk);
        ui_in = {1'b0, cmd, nib};
        @(negedge clk);
        ui_in[7] = 1'b1;
        @(negedge clk);
        ui_in[7] = 1'b0;
    end
endtask

task shift16;
    input [15:0] w;
    begin
        host(3'd0, w[15:12]);
        host(3'd0, w[11:8]);
        host(3'd0, w[7:4]);
        host(3'd0, w[3:0]);
    end
endtask

task imem_wr;
    input [15:0] w;
    begin
        shift16(w);
        host(3'd1, 4'd0);
    end
endtask

task set_addr;
    input [4:0] a;
    begin
        shift16({11'd0, a});
        host(3'd2, 4'd0);
    end
endtask

task fifo_push;
    input [15:0] w;
    begin
        shift16(w);
        host(3'd3, 4'd0);
    end
endtask

task halt;
    begin
        host(3'd5, 4'd0);
    end
endtask

task start0;
    begin
        host(3'd5, 4'b0001);
    end
endtask
