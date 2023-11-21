module msd_dimm;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
           
  int traceFile,out_file;
  int valuesRead;
  logic[11:0]core;
  logic[1:0]operation;
  logic[35:0]address;
  int time_unit;
  int rowCounter,last_line;
  bit read,write,inst_fetch;
  string ip_file;
  string op_file;
  int debug_en;
  longint unsigned q_ip_time[$];                  //input queue for request time
  int q_ip_oper[$];                               //input queue for operation
  logic [35:0] q_ip_addr[$];                      //input queue for address
  logic [37:0] q_mc[$:15], local_var,q_out_temp;  //q_mc -> [37:36] operation; [35:0] address
  longint unsigned sim_time =1;                   //Simulation time
  int sim_t;
  int q_full,q_empty;
  int violation_flag;
           
  always #1 sim_time = sim_time+1;
           
  task add_to_mc_q;
       local_var = {q_ip_oper.pop_front(), q_ip_addr.pop_front()};
           
          q_mc.push_back(local_var);
         if (debug_en)begin 
          $write(">>>@time:%t Adding new element to the queue.. %h ... at sim_time = %0d --> q_mc.size = %0d \n",$time, local_var, sim_time, q_mc.size()); 
          display_q;
         end 
  endtask
           
  task output_command(input[37:0] q_out_temp);
       if (q_out_temp[37:36] == 0 || q_out_temp[37:36] == 2) begin //Read operation. mem controller point of view instruction fetch is also read.
          $fwrite(out_file,"\t\t*********Read operation********* Value of operation=%0d address =%h \n",q_out_temp[37:36],q_out_temp[33:0]);
          $fwrite(out_file,"%t \t channel=%d ACT0 bankg=%d bank=%d row =%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $fwrite(out_file,"%t \t channel=%d ACT1 bankg=%d bank=%d row=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $fwrite(out_file,"%t \t channel=%d RD0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
          $fwrite(out_file,"%t \t channel=%d RD1  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
          $fwrite(out_file,"%t \t channel=%d PRE  bankg=%d bank=%d \n ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
       end 
       if (q_out_temp[37:36] == 1) begin
          $fwrite(out_file,"\t\t*********write operation********* Value of operation=%0d address =%h \n",q_out_temp[37:36],q_out_temp[33:0]);
          $fwrite(out_file,"%t \t channel=%d ACT0 bankg=%d bank=%d row =%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $fwrite(out_file,"%t \t channel=%d ACT1 bankg=%d bank=%d row=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $fwrite(out_file,"%t \t channel=%d WR0  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
          $fwrite(out_file,"%t \t channel=%d WR1  bankg=%d bank=%d column=%h \n",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],{q_out_temp[17:12],q_out_temp[5:2]});
          $fwrite(out_file,"%t \t channel=%d PRE  bankg=%d bank=%d \n ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
       end 
  endtask
           
  task rem_from_mc_q;
       q_out_temp=q_mc[0];
      if (debug_en)begin
      $write("q_out_temp= %0h \n",q_out_temp);
      end 
       output_command(q_out_temp);
        void' (q_mc.pop_front());
      if (debug_en)begin
       $write(">>>@time:%t Removing a queue %h elements from queue..  sim_time = %0d --> q_mc.size = %0d\n",$time,q_out_temp, sim_time, q_mc.size());
       display_q; 
      end    
       last_line ++; 
  endtask
           
  always@(sim_time) begin
         if ((q_ip_time.size() != 0) &&(q_full==0))begin
            sim_t=q_ip_time.pop_front;
            wait(sim_t<=sim_time);
           if (debug_en)begin
            $write("inside simulation time ip =%d, sim_time=%d \n",sim_t,sim_time);
           end 
            add_to_mc_q;
         end 
  end   
           
  always@(sim_time) begin
         if (q_mc.size() == 15) begin
            q_full=1;
            $fwrite(out_file," \n -----@time %t The queue is full stall cpu request until the queue request are satisfied and removed----- \n",$time);
         end else
            q_full=0;
         if (q_mc.size() == 0) begin
            q_empty=1;
            if (debug_en)begin
               $write("the queue is empty \n");
            end 
         end else
            q_empty=0;
  end   
           
  always@(sim_time) begin 
         if ((q_mc.size() != 0)||(q_full==1)) begin
            if (sim_time % 2 == 0)
            rem_from_mc_q;
         end 
  end   
           
  always@(sim_time) begin
         if ((q_ip_time.size() == 0) && (q_mc.size() ==0) && (q_full ==0) && (last_line == rowCounter)) begin
            if (debug_en)
               $write("value of last_line=%d, rowCounter=%d \n",last_line,rowCounter);
            // Both input queue and memory controller queue are empty
             #4 $finish;
         end 
  end   
           
  task display_q;
       $write("-----Displaying the values in Queue:\n ");
       for (int i=0; i<q_mc.size(); i++)begin
           $write("%h \n", q_mc[i]);
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
             valuesRead = 0;
             // Read values from the file.
             valuesRead = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);
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
             valuesRead = 0;
             valuesRead = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);
             q_ip_time.push_back(time_unit);
             q_ip_oper.push_back(operation);
             q_ip_addr.push_back(address);
             if (valuesRead == 4) begin
                if (debug_en)
                   $display ( "from row %d the value of time =%d  core=%d operation=%d address=%h",rowCounter,time_unit,core,operation,address);
                $fwrite(out_file,"from row %d the value of time =%d \t core=%d \t operation=%d \t address=%h \n",rowCounter,time_unit,core,operation,address);
                rowCounter++;
             end    
       end 
       // Close the file.
       void' (q_ip_time.pop_back());
       void' (q_ip_oper.pop_back());
       void' (q_ip_addr.pop_back());
       $fclose(traceFile);
           
  end   
endmodule
