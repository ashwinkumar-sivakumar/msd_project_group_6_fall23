import random

# Function to generate a random trace file
def generate_trace_file():
    # Open a file for writing


# Open and write to each file

    with open("trace_file.txt", "w") as file:
    
        
        #here it is generating for 10 rows of data
        for sim_time in sorted(random.sample(range(101), 10)): 
            # Generate random values for each column
            #sim_time = random.randint(0, 100)
            core = random.randint(0, 11)
            operation = random.randint(0, 2)
            byte_sel = random.randint(0, 2**2 - 1) #No difference if we change/not
            low_column = random.randint(0, 2**4 - 1)
            channel=0 #fixed to 0
            bank_group = random.randint(0, 2**3 - 1) #3 bit
            bank = random.randint(0, 2**2 - 1) # 2 bit
            high_column =random.randint(0, 2**6 - 1) #6 bit
            row =random.randint(0, 2**16 - 1) # 16 bits
            address = (byte_sel & 0b11) << 32 | (low_column & 0b1111) << 28 |(channel & 0b1) << 26 | (bank_group & 0b111) << 23 | (bank & 0b11) << 21 | (high_column & 0b111111) << 12 | (row & 0b1111111111111111)  
            #address 34 bits


            # Write the values to the file
            file.write(f"{sim_time}\t{core}\t{operation}\t{address:0X}\n")
            
# Generate the trace file
generate_trace_file()
