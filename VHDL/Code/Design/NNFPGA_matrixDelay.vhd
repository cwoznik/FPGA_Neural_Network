-- NNFPGA_oneShift.vhd
--
-- Storage for a nxn arry for filter
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.NNFPGA_pkg.all;


entity NNFPGA_matrixDelay is
	generic (	n				: integer;      --dimension of the matrix 
				dataWidth 	    : integer;      --datawidth for the matrix
				newLineLength	: integer);     --when to start storing in a new line 
	port(   clk         : in 	std_logic;
			rst			: in 	std_logic;
			wrEn		: in	std_logic;
			
			dataIn		: in 	std_logic_vector(dataWidth-1 downto 0);
			
			dataOut 	: out t_variableSizeLogicVectorArray(0 to n*n-1) (dataWidth-1 downto 0));
			
end NNFPGA_matrixDelay;


architecture behave of NNFPGA_matrixDelay is
    --signal to store all the data to shift 
    --
    --    ^
    --    |    0            1         2      ...    n-2        n-1
    --                               ...
    --    | (n-2)*n    (n-2)*n+1  (n-2)*n+2  ... (n-1)*n-2  (n-1)*n-1
    --    | (n-1)*n    (n-1)*n+1  (n-1)*n+2  ...   n*n-2      n*n-1
    --    ------------------------------------------------------------>
    signal dataStorrage 	: t_variableSizeLogicVectorArray(0 to n*n-1)(dataWidth-1 downto 0) := (others => (others => '0'));
    --signal to store the output of the memory modules 
    signal lineMemOut		: t_variableSizeLogicVectorArray(0 to n*n-2)(dataWidth-1 downto 0);

begin				
	--instantiate the line momory 
	Memory : for i in n downto 2 generate		-- no memory needed for the last line, so we only need n-1 times linememory
		LineMem : entity work.NNFPGA_linemem 
		generic map(dataWidth 		=> dataWidth,
					memoryLength 	=> newLineLength-1)
		port map (	clk      => clk,
					reset    => rst,
					write_en => wrEn,
					data_in  => dataStorrage((i)*n -1), 		--connect the LineMem with the previous one. start from the lower right corner
					data_out => lineMemOut(i-2)); 				--and always move one row upwards. That way we will always have the most current data
                                                                --in the lowest line memory 
	end generate; 	
	
	process 
		variable position 	: integer;
		variable x,y 		: integer;
	begin
		wait until rising_edge(clk);
		
		dataStorrage(n*n-1) <= dataIn; 		        --the bottom right value (n*n-1) is the current value. so write the current value to the memory
		for i in n-1 downto 1 loop                  --for all the instances of the line memory 
			dataStorrage(i*n-1) <= lineMemOut(i-1); --write the output into the right most field of the storage array, so for the fist line memory we store the output in (n-1)*n -1
		end loop;                                   --the most right value of the second lowest row
	
		
		for y in 0 to n-1 loop 						                --loop to the storrage vertically
			for x in 1 to n-1 loop                                  --loop to the storrage horizontally. we do not need to move the most left element in each row as the right element 
				position := (y*n)+x;                                --of the next row is fed by line memory 
				dataStorrage(position-1) <= dataStorrage(position); --and shift the data one position 
			end loop; 
		end loop;
		
		dataOut <= dataStorrage;
	end process;	

	
	
end behave;