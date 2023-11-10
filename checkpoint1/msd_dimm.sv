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
	$value$plusargs("ip_file=%s", ip_file);
	$value$plusargs("op_file=%s", op_file);
	$value$plusargs("debug_en=%d", debug_en);
  end
  initial begin
    if(debug_en)
    $display("Reading and displaying values from trace.txt...");

    // Open the file for reading.
    
   traceFile = $fopen(ip_file, "r");
   out_file = $fopen("output.txt", "w");
   // traceFile =$fopen("trace.txt","r");
    if (traceFile == 0) begin
       if(debug_en)
      $display("Error: Could not open the file.");
      $finish;
    end

    // Read and display values from the file.
    while (!$feof(traceFile)) begin
      // Initialize the values read counter.
      valuesRead = 0;

      // Read values from the file.
      valuesRead = $fscanf(traceFile, "%d %d %d %h", time_unit, core, operation, address);

      if (valuesRead == 4) begin
        if(debug_en)
        $display ( "from row %d the value of time =%d  core=%12d operation=%2h address=%h",rowCounter,time_unit,core,operation,address);
        $fwrite(out_file,"from row %d the value of time =%d \t core=%12d \t operation=%2h \t address=%h \n",rowCounter,time_unit,core,operation,address);
        rowCounter++;

      end 
     if (valuesRead != 4) begin
        if(debug_en)
       // $display("Error:Invalid inputs");
        $finish;
      end
    end

    // Close the file.
    $fclose(traceFile);
    $finish;
  end
endmodule
