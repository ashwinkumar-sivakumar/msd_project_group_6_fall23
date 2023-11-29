module msd_dimm;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
                   
  int traceFile,out_file;
  int scan_col_cnt;
  logic[11:0]core;
  logic[1:0]operation;
  logic[35:0]address;
  int time_unit;
  int rowCounter,last_line;
  string ip_file;
  string op_file;
  int debug_en; 
  longint unsigned q_trace_timodule msd_dimm;
 
  int traceFile,out_file;
  int scan_col_cnt;
  logic[11:0]core;
  logic[1:0]operation;
  logic[35:0]address;
  int time_unit;
  int rowCounter,last_line;
  string ip_file;
  string op_file;
  int debug_en; 
  longint unsigned q_trace_time[$];               //queue for request time
  int ip_q_oper[$];                               //queue for operation
  logic [35:0] ip_q_addr[$];                      //queue for address
  logic [37:0] master_q[$:15], temp_var,q_out_temp;  //master_q -> [37:36] operation; [35:0] address
  longint unsigned sim_time =1;                   //Simulation time
  int sim_t;       
  int q_full,q_empty;
  int violation_flag;
  int bank_g_access_count;
  bit [2:0]bank_g_queue[2:0];
  int queue_ptr=0;
                   
                   
  int tRP = 10; 
  int tRCD = 8;  
  int tCL = 6;  
  int tBURST = 4;
  int tRTP = 2; 
  int tWR = 10; 
  int tCWL = 8;
  typedef enum logic[3:0] {START, ACT0, RD0, WR0, ACT1, RD1, WR1, BURST, PRE,IDLE} states_t;
                   
  states_t cur_state,next_state;

  logic [15:0] row;
  logic [9:0]  column;
  logic [1:0]  bank;
  logic [2:0]  bank_g;
  logic [1:0]  op_out;
  logic channel;
  int d_time;   
  bit done;        
  bit onProcess;

                   
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
                   
       //output_command(q_out_temp,DONE);
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
         if (master_q.size() == 16) begin
            q_full=1;
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
                   
  always@(*) begin
         $fwrite(out_file," \n -----time=%t,@sim_time = %d \n",$time,sim_time); 
         if ((master_q.size() != 0)||(master_q.size() == 16)) begin
            if (sim_time % 2 == 0) begin
               case (next_state)
                   
                    START: begin
                      if(master_q.size() !=0 && onProcess == 0) begin
                      $fwrite(out_file," \n -----Entered START state \n"); 
                      onProcess = 1;
                      q_out_temp=master_q[0];
                      row = q_out_temp[33:18];
                      column = { q_out_temp[17:12],q_out_temp[5:2] };
                      bank = q_out_temp[11:10];
                      bank_g = q_out_temp[9:7];
                      channel = q_out_temp[6];
                      op_out = q_out_temp[37:36];
                      d_time = sim_time; 
                      next_state = ACT0;
                      end else
                      next_state = IDLE;
                    end 
                    ACT0: begin
                     $fwrite(out_file," \n -----Entered ACT0 state \n"); 
                      onProcess = 1;
                     if(bank_g_queue[bank_g]==1) begin
                       $fwrite(out_file," \n -----same bank \n");
                       wait ((d_time + tRP) == sim_time);
                        if (op_out == 0 || op_out == 2)  
                           next_state = RD0;                      
                        if (op_out ==1)
                           next_state = WR0;
 
                      end
                      if(bank_g_queue[bank_g]==0) begin
                       $fwrite(out_file," \n -----different bank \n");
                        if (op_out == 0 || op_out == 2)  
                           next_state = RD0;                      
                        if (op_out ==1)
                           next_state = WR0;

                         bank_g_queue[bank_g]=1;
                      end
                     
                                         
                     d_time = sim_time;
                     $fwrite(out_file,"%t \t channel=%d ACT0 bankg=%d bank=%d row =%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]); 
                    end 
                    RD0: begin
                     $fwrite(out_file," \n -----Entered RD0 state \n");
                     onProcess = 1;
                     wait ((d_time + tRCD) == sim_time);
                     next_state = PRE;                  
                     d_time = sim_time;
                     $fwrite(out_file,"%t \t channel=%d RD0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                    end 
                    WR0: begin
                     $fwrite(out_file," \n -----Entered WR0 state \n");
                      onProcess = 1;
                     wait ((d_time+tRCD) == sim_time);
                     next_state = PRE;          
                     d_time = sim_time;
                     $fwrite(out_file,"%t \t channel=%d WR0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                    end
                     
                    PRE: begin
                     $fwrite(out_file," \n -----Entered PRE state \n");
                      if (op_out == 0 || op_out == 2) 
                      wait ((d_time + tRTP) == sim_time);
                      if (op_out == 1)
                      wait((d_time + tCWL + tBURST + tWR) == sim_time);
                      onProcess = 0; 
                      done = 1;
                      del_from_master_q;
                      next_state = START;
                      $fwrite(out_file,"%t \t channel=%d PRE  bankg=%d bank=%d \n ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]); 
                      $fwrite(out_file,"%t \t done=%d \n",$time,done);
                    end
                    IDLE: begin
                      if(onProcess==0) begin
                     $fwrite(out_file," \n -----Entered IDLE state \n"); 
                      next_state = START;
                    end 
                    end  
                    default: next_state = START;
               endcase 
            end 
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
             if ((address[6]!=0) || (operation >= 3) || (core >= 12)) begin
                if(debug_en)
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
                if (debug_en)
                   $display ( "from row %d the value of time =%d  core=%d operation=%d address=%h",rowCounter,time_unit,core,operation,address);
                $fwrite(out_file,"from row %d the value of time =%d \t core=%d \t operation=%d \t address=%h \n",rowCounter,time_unit,core,operation,address);
                rowCounter++;
             end    
       end         
       // Close the file.
       void' (q_trace_time.pop_back());
       void' (ip_q_oper.pop_back());
       void' (ip_q_addr.pop_back());
       $fclose(traceFile);
  end              
endmoduleme[$];               //queue for request time
  int ip_q_oper[$];                               //queue for operation
  logic [35:0] ip_q_addr[$];                      //queue for address
  logic [37:0] master_q[$:15], temp_var,q_out_temp;  //master_q -> [37:36] operation; [35:0] address
  longint unsigned sim_time =1;                   //Simulation time
  int sim_t;       
  int q_full,q_empty;
  int violation_flag;
                   
                   
  int tRP = 10; 
  int tRCD = 8;  
  int tCL = 6;  
  int tBURST = 4;
  int tRTP = 2;  
  typedef enum logic[2:0] {IDLE, START, ACT, RD, WR, BURST, PRE} states_t;
                   
  states_t cur_state,next_state;
  logic [15:0] row;
  logic [9:0]  column;
  logic [1:0]  bank;
  logic [2:1]  bank_g;
  logic [1:0]  op_out;
  logic channel;
  int d_time;   
  bit done;        
  bit onProcess;
                   
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
                   
       //output_command(q_out_temp,DONE);
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
         if (master_q.size() == 16) begin
            q_full=1;
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
                   
  always@(*) begin
         $fwrite(out_file," \n -----time=%t,@sim_time = %d \n",$time,sim_time); 
         if ((master_q.size() != 0)||(master_q.size() == 16)) begin
            if (sim_time % 2 == 0) begin
               case (next_state)
                   
                    IDLE: begin
                      if(onProcess==0) begin
                     $fwrite(out_file," \n -----Entered IDLE state \n"); 
                      next_state = START;
                    end 
                    end 
                   
                    START: begin
                     $fwrite(out_file," \n -----Entered START state \n"); 
                      onProcess = 1;
                      q_out_temp=master_q[0];
                      row = q_out_temp[33:18];
                      column = { q_out_temp[17:12],q_out_temp[5:2] };
                      bank = q_out_temp[11:10];
                      bank_g = q_out_temp[9:7];
                      channel = q_out_temp[6];
                      op_out = q_out_temp[37:36];
                      d_time = sim_time;
                      next_state = ACT;
                    end 
                    ACT: begin
                     $fwrite(out_file," \n -----Entered ACT state \n"); 
                      onProcess = 1;
                      wait((d_time + tRP) == sim_time);
                      $fwrite(out_file,"%t \t channel=%d ACT0 bankg=%d bank=%d row =%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
                      $fwrite(out_file,"%t \t channel=%d ACT1 bankg=%d bank=%d row=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
                      if (op_out == 0 || op_out == 2)  
                         next_state = RD; 
                      else
                         next_state = WR; 
                    end 
                    RD: begin
                     $fwrite(out_file," \n -----Entered RD state \n");
                      onProcess = 1;
                      wait ((d_time + tRP + tRCD) == sim_time);
                      $fwrite(out_file,"%t \t channel=%d RD0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                      $fwrite(out_file,"%t \t channel=%d RD1  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                      next_state = PRE;
                    end 
                    WR: begin
                     $fwrite(out_file," \n -----Entered WR state \n");
                      onProcess = 1;
                      wait ((d_time + tRP + tRCD) == sim_time);
                      $fwrite(out_file,"%t \t channel=%d WR0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                      $fwrite(out_file,"%t \t channel=%d WR1  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
                      next_state = PRE;
                    end 
                    PRE: begin
                     $fwrite(out_file," \n -----Entered PRE state \n");
                      wait ((d_time + tRP + tRCD + tRTP) == sim_time);
                      done = 1;
                      onProcess = 0;
                      del_from_master_q;
                      if (master_q.size() != 0)
                         next_state = START;
                      else
                      next_state = IDLE; 
                      $fwrite(out_file,"%t \t channel=%d PRE  bankg=%d bank=%d \n ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
                      $fwrite(out_file,"%t \t done=%d \n",$time,done);
                    
                    end 
                    default: next_state = IDLE;
               endcase 
            end 
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
             if ((address[6]!=0) || (operation >= 3) || (core >= 12)) begin
                if(debug_en)
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
                if (debug_en)
                   $display ( "from row %d the value of time =%d  core=%d operation=%d address=%h",rowCounter,time_unit,core,operation,address);
                $fwrite(out_file,"from row %d the value of time =%d \t core=%d \t operation=%d \t address=%h \n",rowCounter,time_unit,core,operation,address);
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
