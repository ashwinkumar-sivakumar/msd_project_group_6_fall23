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
  bit [1:0] dimm_count;

  always #1 sim_time = sim_time+1;

  task add_to_mc_q;
       local_var = {q_ip_oper.pop_front(), q_ip_addr.pop_front()};
       if (debug_en)
          q_mc.push_back(local_var);
          $display(">>>@time:%t Adding new element to the queue.. %h ... at sim_time = %0d --> q_mc.size = %0d\n",$time, local_var, sim_time, q_mc.size()); 
          display_q; 
  endtask

  task output_command(input[37:0] q_out_temp);
       if (q_out_temp[37:36] == 0 || q_out_temp[37:36] == 1) begin //Read operation. mem controller point of view instruction fetch is also read.
          $display("\t\t*********Read operation********* Value of operation=%0d",q_out_temp[37:36]);
          $display("%t \t channel=%d ACT0 bankg=%d bank=%d row =%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $display("%t \t channel=%d ACT1 bankg=%d bank=%d row=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $display("%t \t channel=%d RD0 bankg=%d bank=%d column=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[17:12]);
          $display("%t \t channel=%d RD1 bankg=%d bank=%d column=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[17:12]);
          $display("%t \t channel=%d PRE bankg=%d bank=%d ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
       end
       if (q_out_temp[37:36] == 2) begin
          $display("\t\t*********Write operation********* Value of operation=%0d",q_out_temp[37:36]);
          $display("%t \t channel=%d ACT0 bankg=%d bank=%d row =%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $display("%t \t channel=%d ACT1 bankg=%d bank=%d row=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[33:18]);
          $display("%t \t channel=%d WR0 bankg=%d bank=%d column=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[17:12]);
          $display("%t \t channel=%d WR1 bankg=%d bank=%d column=%d",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10],q_out_temp[17:12]);
          $display("%t \t channel=%d REF bankg=%d bank=%d ",$time,q_out_temp[6],q_out_temp[9:7],q_out_temp[11:10]);
       end 
  endtask

  task rem_from_mc_q;
       q_out_temp=q_mc[0];
       $display("q_out_temp= %0h ",q_out_temp);
       output_command(q_out_temp);
       q_mc.pop_front();
       dimm_count=0;
       $display(">>>@time:%t Removing a queue %h elements from queue..  sim_time = %0d --> q_mc.size = %0d\n",$time,q_out_temp, sim_time, q_mc.size());
       display_q;        
       last_line ++;
     /*  if (rowCounter+1==last_line)begin
          #1 $finish;
       end*/
  endtask

  always@(sim_time) begin
         if ((q_ip_time.size() != 0) &&(q_full==0))begin
            sim_t=q_ip_time.pop_front;
            wait(sim_t<=sim_time);
            $display("inside simulation time ip =%d, sim_time=%d",sim_t,sim_time);
            add_to_mc_q;
         end
  end

  always@(sim_time) begin
         if (q_mc.size() == 15) begin
            q_full=1;
            $display("The queue is full stall cpu request until the queue request are satisfied");
         end else
            q_full=0;
         if (q_mc.size() == 0) begin
            q_empty=1;
            $display("the queue is empty");
         end else
             q_empty=0;
  end

  always@(sim_time) begin 
         if ((q_mc.size() != 0)||(q_full==1)) begin
            #1 dimm_count =2; 
            $display("dimm_count =%d", dimm_count);
            rem_from_mc_q;
         end
  end

  always@(sim_time) begin
         if ((q_ip_time.size() == 0) && (q_mc.size() ==0) && (q_full ==0) && (last_line !=0)) begin
            // Both input queue and memory controller queue are empty
            #1 $finish;
         end
  end 
        
  task display_q;
       $write("MEMORY_CONTROLLER Q: ");
       for (int i=0; i<q_mc.size(); i++)begin
           $write("%h ", q_mc[i]);
       end
       $write("\n\n");
  endtask

  initial begin
       sim_time=0;
       void'($value$plusargs("ip_file=%s", ip_file));
       void'($value$plusargs("op_file=%s", op_file));
       void'($value$plusargs("debug_en=%d",debug_en));
  end

  initial begin
       if (debug_en)
          $display("Reading and displaying values from trace trace files...");
       // Open the file for reading and writing .
       traceFile = $fopen(ip_file, "r");
       out_file = $fopen(op_file, "w");
       if (traceFile == 0) begin
          if (debug_en)
             $display("Trace file not found. Opening the default trace file 'default_trace.txt' ... ");
          traceFile =$fopen("default_trace.txt","r");
       end
       if (out_file == 0) begin
          if (debug_en)
             $display("output file to print not found. Opening the default output file 'default_out.txt'... ");
          out_file = $fopen("default_output.txt", "w");
       end
       // Read and display values from the file.
       while (!$feof(traceFile)) begin
             // Initialize the values read counter.
             valuesRead = 0;
             // Read values from the file.
             valuesRead = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);
             q_ip_time.push_back(time_unit);
             q_ip_oper.push_back(operation);
             q_ip_addr.push_back(address);
             //$display("read =%d,write=%d,inst_fetch=%d",read,write,inst_fetch);
             if (valuesRead == 4) begin
                if (debug_en) begin 
                   $display ( "from row %d the value of time =%d  core=%d operation=%d address=%h",rowCounter,time_unit,core,operation,address);
                   $fwrite(out_file,"from row %d the value of time =%d \t core=%d \t operation=%d \t address=%h \n",rowCounter,time_unit,core,operation,address);
                end
                rowCounter++;
             end 
       end
       // Close the file.
       q_ip_time.pop_back();
       q_ip_oper.pop_back();
       q_ip_addr.pop_back();
       $fclose(traceFile);
       $fclose(out_file);
  end
endmodule
