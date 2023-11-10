
module msd_dimm;
 
int traceFile,out_file;
int valuesRead;
logic[11:0]core;
logic[1:0]operation;
logic[35:0]address;
int time_unit;

int rowCounter;

 string ip_file;
 string op_file;
 int debug_en;

  initial begin
	void'($value$plusargs("ip_file=%s", ip_file));
	void'($value$plusargs("op_file=%s", op_file));
	void'($value$plusargs("debug_en=%d",debug_en));
  end
  initial begin
    if(debug_en)
    $display("Reading and displaying values from trace trace files...");

    // Open the file for reading and writing .

   
   traceFile = $fopen(ip_file, "r");
   
   out_file = $fopen(op_file, "w");
   
    if (traceFile == 0) begin
      if(debug_en)
      $display("Trace file not found. Opening the default trace file 'default_trace.txt' ... ");
      traceFile =$fopen("default_trace.txt","r");
      
    end
    if (out_file == 0) begin
      if(debug_en)
      $display("output file to print not found. Opening the default output file 'default_out.txt'... ");
      out_file = $fopen("default_output.txt", "w");
      
    end


    // Read and display values from the file.
    while (!$feof(traceFile)) begin
      // Initialize the values read counter.
      valuesRead = 0;

      // Read values from the file.
     
      valuesRead = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);

      if (valuesRead == 4) begin
        if(debug_en) begin 
        $display ( "from row %d the value of time =%d  core=%12d operation=%2h address=%h",rowCounter,time_unit,core,operation,address);
        $fwrite(out_file,"from row %d the value of time =%d \t core=%12d \t operation=%2h \t address=%h \n",rowCounter,time_unit,core,operation,address);
        end
        rowCounter++;

      end 
      
    end

    // Close the file.
    $fclose(traceFile);
    $fclose(out_file);
    $finish;
  end
endmodule
