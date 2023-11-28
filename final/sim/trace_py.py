import random

# Function to generate a random trace file
def generate_trace_file():
    # Open a file for writing


# Open and write to each file

    with open("trace_file.txt", "w") as file:
    
        
        #here it is generating for 10 rows of data
        for sim_time in sorted(random.sample(range(100), 20)): 
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
            
            #address 34 bits
            address = (row & 0b1111111111111111) << 18|(high_column & 0b111111) << 12 |(bank & 0b11) << 10 |(bank_group & 0b111) << 7 |(channel & 0b1) << 6 |(low_column & 0b1111) << 2 |(byte_sel & 0b11) << 0     

            #address = (0b0111111111111111 & 0b1111111111111111) << 18|(0b101010 & 0b111111) << 12 |(0b01 & 0b11) << 10 |(0b000 & 0b111) << 7 |(0b0 & 0b1) << 6 |(0b1010 & 0b1111) << 2 |(0b11 & 0b11) << 0     



            # Write the values to the file
            file.write(f"{sim_time}\t{core}\t{operation}\t{address:0X}\n")
            
# Generate the trace file
generate_trace_file()
