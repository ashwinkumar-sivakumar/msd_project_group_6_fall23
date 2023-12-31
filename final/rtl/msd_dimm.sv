module msd_dimm;
  int traceFile,out_file;
  int scan_col_cnt;
  int core;
  int operation;
  logic[35:0]address;
  int time_unit;
  int rowCounter,last_line;
  string ip_file;
  string op_file;
  int debug_en;
  bit cl;
  longint unsigned q_trace_time[$];               //queue for request time
  int ip_q_oper[$];                               //queue for operation
  logic [35:0] ip_q_addr[$];                      //queue for address
  logic [37:0] master_q[$:15], temp_var,q_out_temp;  //master_q -> [37:36] operation; [35:0] address
  longint unsigned sim_time =1;                   //Simulation time
  int sim_t;      
  int q_full,q_empty;
  int violation_flag;
  bit  uniq_bank [7:0][3:0];
  int bank_g_time [7:0][3:0];
  int bank_g_s_rem_time;
  int queue_ptr=0;
  int row_c=0;
  longint unsigned temp_time;   
  logic [15:0] row;
  logic [9:0]  column;
  logic [1:0]  bank;
  logic [2:0]  bank_g;
  logic [1:0]  op_out;
  logic channel;
  int d_time;  
  bit done;        
  bit onProcess;
  longint unsigned dimm_counter =0; 
  // *******Timming Constraints***********                 
  int tRP = 2*39;
  int tRCD =2*39;  
  int tCL =2*40 ;  
  int tBURST =2*8;
  int tRTP = 2*18;
  int tWR = 2*30;
  int tCWL = 2*38;
  int tRC = 2*115;
  // ************************************
  typedef enum logic[3:0] {IDLE, ACT0, RD0, WR0, ACT1, RD1, WR1, BURST, PRE} states_t;
                   
  states_t cur_state,next_state;

  always #1 sim_time = sim_time+1;
                   
  task insert_to_master_q;
       temp_var = {ip_q_oper.pop_front(), ip_q_addr.pop_front()};
       master_q.push_back(temp_var);
       if (debug_en)begin
          $write(">>>@time:%t Adding new element to the queue.. %h ... at sim_time = %0d --> master_q.size = %0d \n",$time, temp_var, sim_time, master_q.size());
          display_q;
       end        
  endtask          
                   
  task del_from_master_q;
       if (debug_en)begin
          $write("q_out_temp= %0h \n",q_out_temp);
       end        
       if (done==1) begin
          void' (master_q.pop_front());
          done=0;
          if (debug_en)begin
             $write(">>>@time:%t Removing a queue %h elements from queue..  sim_time = %0d --> master_q.size = %0d\n",$time,q_out_temp, sim_time, master_q.size());
             display_q;
          end        
          last_line ++;
       end        
  endtask          
                   
  always@(*) begin
         if ((q_trace_time.size() != 0) &&(master_q.size() != 16))begin
            sim_t=q_trace_time.pop_front;
            wait(sim_t<=sim_time);
            if (debug_en)begin
               $write("inside simulation time ip =%d, sim_time=%d \n",sim_t,sim_time);
            end
            insert_to_master_q;
         end      
         if (master_q.size() == 16) begin
            q_full=1;
            if(debug_en)
            $fwrite(out_file," \n -----@time %t The queue is full stall cpu request until the queue request are satisfied and removed----- \n",$time);
         end else
            q_full=0;
         if (master_q.size() == 0) begin
            q_empty=1;
            if (debug_en)begin
               $write("the queue is empty \n");
            end
         end else
            q_empty=0;
  end              
                   
  always@(sim_time) begin
         if ((sim_time % 2 == 0)&&(sim_time!=0)) begin
            dimm_counter++;
         end              
  end  
                
  always@(*) begin
         if (sim_time % 2 == 0) begin
            case (next_state)
                 ACT0: begin
                     if (debug_en)
                        $fwrite(out_file," \n -----Entered ACT0 state \n");
                     onProcess = 1;
                     q_out_temp=master_q[0];
                     row = q_out_temp[33:18];
                     column = { q_out_temp[17:12],q_out_temp[5:2] };
                     bank = q_out_temp[11:10];
                     bank_g = q_out_temp[9:7];
                     channel = q_out_temp[6];
                     op_out = q_out_temp[37:36];
                     d_time = sim_time;
                     if (temp_time == sim_time)
                        wait (sim_time == temp_time+2);
                     if (uniq_bank[bank_g][bank]==1) begin
                        if (debug_en)
                           $fwrite(out_file," \n -----same bank \n");
                        bank_g_s_rem_time = d_time- bank_g_time[bank_g][bank];
                        if (debug_en)
                           $fwrite(out_file," \n bank_g_s_rem_time=%d,d_time=%d\n",bank_g_s_rem_time,d_time);
                        if (bank_g_s_rem_time<=tRP) begin
                           wait ((d_time + (tRP- bank_g_s_rem_time -2)) == sim_time);
                           if (op_out == 0 || op_out == 2) //mem controller point of view instruction fetch is also Read. 
                              next_state = RD0;                      
                           if (op_out ==1)
                              next_state = WR0;
                        end else begin
                        if (op_out == 0 || op_out == 2)  
                           next_state = RD0;                      
                        if (op_out ==1)
                           next_state = WR0;
                        end
                     end
                     if (uniq_bank[bank_g][bank]==0) begin
                        if (debug_en)
                           $fwrite(out_file," \n -----different bank \n");
                        if (op_out == 0 || op_out == 2)  
                           next_state = RD0;                      
                        if (op_out ==1)
                           next_state = WR0;
                        uniq_bank[bank_g][bank]=1;
                     end
                     $fwrite(out_file,"%0t \t %d \t ACT0 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);                
                     d_time = sim_time;
                     #2 $fwrite(out_file,"%0t \t %d \t ACT1 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);                      
                 end
                     
                 RD0:  begin
                     if (debug_en)
                        $fwrite(out_file," \n -----Entered RD0 state \n");
                     onProcess = 1;
                     wait ((d_time + tRCD) == sim_time);
                     d_time = sim_time;
                     next_state = PRE;
                     $fwrite(out_file,"%0t \t %d \t RD0 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                     #2 $fwrite(out_file,"%0t \t %d \t RD1 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                 end

                 WR0:  begin
                     if (debug_en)
                        $fwrite(out_file," \n -----Entered WR0 state \n");
                     onProcess = 1;
                     wait ((d_time+tRCD) == sim_time);
                     d_time = sim_time;
                     next_state = PRE;        
                     $fwrite(out_file,"%0t \t %d \t WR0 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                     #2 $fwrite(out_file,"%0t \t %d \t WR1 \t %d \t %d \t %h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                 end
                     
                 PRE: begin
                     if (debug_en)
                        $fwrite(out_file," \n -----Entered PRE state \n");
                     if (op_out == 0 || op_out == 2) begin
                         wait ((d_time + tCL + tBURST +2) == sim_time);
                     end
                     if (op_out == 1)
                        wait((d_time + tCWL + tBURST + tWR +2) == sim_time);
                     onProcess = 0;
                     done = 1;
                     del_from_master_q;
                     bank_g_time[bank_g][bank]=sim_time;
                     if (debug_en)
                        $fwrite(out_file," \t bank_g_time[%d][%d]=%d \n",bank_g,bank,bank_g_time[bank_g][bank]);
                     if (master_q.size() !=0 && done==0 && onProcess==0)
                        next_state = ACT0;
                     else
                        next_state = IDLE;
                     $fwrite(out_file,"%0t \t %d \t PRE \t %d \t %d \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
                     temp_time = sim_time;
                     if (debug_en)
                        $fwrite(out_file,"%0t \t done=%d \n",$time,done);
                 end

                 IDLE: begin
                     if (onProcess==0) begin
                        if (debug_en)
                           $fwrite(out_file," \n -----Entered IDLE state \n");
                        if (master_q.size() !=0 && onProcess == 0)
                           next_state = ACT0;
                     end
                 end  
                 default: next_state = IDLE;
               endcase
            end
  end              
                   
  always@(sim_time) begin
         if ((q_trace_time.size() == 0) && (master_q.size() ==0) && (q_full ==0) && (last_line == rowCounter)) begin
            if (debug_en)
               $write("value of last_line=%d, rowCounter=%d \n",last_line,rowCounter);
            // Both input queue and memory controller queue are empty
            #4 $finish;
         end      
  end              
                   
  task display_q;
       $write("-----Displaying the values in Queue:\n ");
       for (int i=0; i<master_q.size(); i++)begin
           $write("%h \n", master_q[i]);
       end        
       $write("---------------------------------\n");
  endtask          
                   
  initial begin
       sim_time=0;
       void'($value$plusargs("ip_file=%s", ip_file));
       void'($value$plusargs("op_file=%s", op_file));
       void'($value$plusargs("debug_en=%d",debug_en));
       violation_flag = 0;
  end              
                   
  initial begin
       if (debug_en)begin
          $display("Reading and displaying values from trace trace files...");
       end        
       // Open the file for reading and writing .
       traceFile = $fopen(ip_file, "r");
       out_file = $fopen(op_file, "w");
       if (traceFile == 0) begin
          if (debug_en)begin
             $display("Trace file not found. Opening the default trace file 'default_trace.txt' ... ");
          end  
          traceFile =$fopen("default_trace.txt","r");
       end        
       if (out_file == 0) begin
          if (debug_en)begin
             $display("output file to print not found. Opening the default output file 'default_out.txt'... ");
          end  
          out_file = $fopen("default_output.txt", "w");
       end        
       while (!$feof(traceFile)) begin
             // Initialize the values read counter.
             scan_col_cnt = 0;
             // Read values from the file.
             scan_col_cnt = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);
             row_c = row_c + 1;
             //if ((address[6]!=0) || address[35] ==1 || address[34] == 1 || (operation >= 3) || (core >= 12)) begin
             if ((address[6]!=0) || (operation >= 3) || (core >= 12)) begin
                if (debug_en)
                   $display("Error in trace file row_c=%d, address[6]=%d,address[35]=%d,address[34]=%d,operation=%d,core=%d",row_c,address[6],address[35],address[34],operation,core);
             $display("Error trace file is not proper, Opening default trace file");
             violation_flag=1;
             break;
             end
       end        
       $display("value of violation_flag=%d",violation_flag);
       if (violation_flag==1)
          traceFile = $fopen("default_trace.txt","r");
       else        
          traceFile = $fopen(ip_file, "r");
       while (!$feof(traceFile)) begin
             scan_col_cnt = 0;
             scan_col_cnt = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);
             q_trace_time.push_back(time_unit);
             ip_q_oper.push_back(operation);
             ip_q_addr.push_back(address);
             if (scan_col_cnt == 4) begin
                if (debug_en) begin
                   $display ("from row %d the value of time =%d \t core=%d \t operation=%d  \t bankg=%d \t bank=%d \t address=%h \n",rowCounter,time_unit,core,operation,address[9:7],address[11:10],address);
                   $fwrite(out_file,"from row %d the value of time =%d \t core=%d \t operation=%d  \t bankg=%d \t bank=%d \t address=%h \n",rowCounter,time_unit,core,operation,address[9:7],address[11:10],address);
                end
                rowCounter++;
             end    
       end        
       // Close the file.
       void' (q_trace_time.pop_back());
       void' (ip_q_oper.pop_back());
       void' (ip_q_addr.pop_back());
       $fclose(traceFile);
  end              
endmodule
