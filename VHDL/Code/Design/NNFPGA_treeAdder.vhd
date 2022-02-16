-- NNFPGA_oneShift.vhd
--
-- tree adder with generic input size and multiplications 
--
-- (c) Christian Woznik

-- tested with ModelSim, functionality proven
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

library work;
use work.NNFPGA_pkg.all; 

entity NNFPGA_treeAdder is
	generic (	inputCount 			: integer; 	--amount of input values to add
				inputdataWidth		: integer; 	--dataWidth of the input values
				pipelineDistance 	: integer); --after how many steps to add a register 

	port (	clk        	: in 	std_logic;											
			rst			: in 	std_logic;
						
			dataIn		: in 	t_variableSizeLogicVectorArray(0 to inputCount-1)(inputdataWidth-1 downto 0);

			--as we have a max of log2(inputCount) additions out output must be as many bits bigger than the input. Each addition increases the required datawidth by one bit
			--otherwise we risk overflows. Example: -128 + -128 = -256. If we do not addapt the datawidth we would get an overflow.
			dataOut		: out 	std_logic_vector(inputdataWidth + integer(ceil(log2(real(inputCount)))) -1 downto 0) := (others => '0'));
			
end NNFPGA_treeAdder;


architecture behave of NNFPGA_treeAdder is
	constant outputDataWidth : integer := inputdataWidth + integer(ceil(log2(real(inputCount))));
	--buffertype to store the values of the previous multiplications for each pipline step. We define more registers than we need as due to the nature of the tree adder 
	--each step only uses half the values the previous step used. However the extra registers will have no fan out and thus will be eliminated during the compilation
	type t_dataBuffer 	is array (0 to integer(ceil(log2(real(inputCount)))/real(pipelineDistance))) 
									of t_variableSizeLogicVectorArray(0 to inputCount -1)(outputDataWidth-1 downto 0);
	signal dataBuffer 	: t_dataBuffer;

begin
	process(clk)
		variable accumulatorStorage 	: t_variableSizeLogicVectorArray(0 to inputCount -1)(outputDataWidth-1 downto 0);
		variable i,j,k,step 			: integer;
	begin
		if rising_edge(clk)  then
			if rst = '1' then
				dataOut <= (others => '0');
				--dataBuffer <= (others => (others => (others => '0'))); uses a lot of resources
			else 
				k := 0;			--variable for the pipline stage 
				
				for i in 0 to dataIn'length -1 loop 													
					accumulatorStorage(i) := std_logic_vector(resize(signed(dataIn(i)),outputDataWidth)); 	--write the resized input to the variable, resize needed as we need to expand 
				end loop;																					--the two complement number the correct way
				
				for step in 0 to integer(ceil(log2(real(inputCount)))) loop 				--bin tree uses log2 steps to complete 
					if (step mod pipelineDistance = 0) then									--add a buffer every nth stage. To add the buffer we need to write the variable input							 
						--dataBuffer(k) 			<= accumulatorStorage;						--to the signal and then read it from there. Thus causing the usage of registers for this step
						--accumulatorStorage 	:= dataBuffer(k);		

						k := k+1; 
					end if; 
					
					for item in 0 to integer(ceil(real(inputCount) / real(2)))-1 loop			--iterate over the input, we only need to iterate through half, because we always add two elements 
						i := 2**(step+1)*item;													--calculate the position of the elements to add. In the first step we add all 2n to all 2n+1 elements and store it 
						j := i+2**step;															--in the place of the 2n element. In the next step we add all 4n to all 4n+2 items, then all 8n to 8n+4. And so on.
																								--See example at the end of the file
						next when((i > accumulatorStorage'right) or 							--important for every step after 1. We must stay within our arry 
											(j > accumulatorStorage'right));				
						accumulatorStorage(i) := std_logic_vector(signed(accumulatorStorage(i)) --do the addition
															+ signed(accumulatorStorage(j)));																
					end loop;  
				end loop;
				
				dataOut <= accumulatorStorage(0);
			end if; 
		end if;
	end process;
	 
end behave;

------------------------------Example Tree Adder------------------------------
-- Index     0 1     2 3     4 5     6 7     8 9     10 11
-- Elements  2 5     1 6     0 3     9 5     1 0      2  8
--           | |     | |     | |     | |     | |      |  |
--           ---     ---     ---     ---     ---      ----		first add 2N and 2N+1  Index(0+1, 2+3,etc.)
--           |       |       |       |       |        |     
-- Step=0    7 5     7 6     3 3    14 5     1 0     10   8
--           |       |       |       |       |        |    
--           ---------       ---------       ----------         then add 4N and 4N+2   Index(0+2, 4+6, etc.)
--           |               |               |
-- Step=1   14 5     7 6    17 3    14 5    11 0     10   8
--           |               |               |
--           -----------------               |                  then add 8N and 8N+4   Index(0+4, 8+12, etc.)
--           |                               |                  as there is no 12th element we do not perform an addition in this example 
-- Step=2   31 5     7 6    17 3    14 5    11 0     10   8
--           |                               |
--           ---------------------------------					then add 16N and 16N+8 Index(0+8, 16+24, etc.)
--		     |
-- Step=3   42 5     7 6    17 3    14 5    11 0     10   8
--		     |

-- Finally we get the result of all the values in the array at position 0. So the answer is (as allways) 42. 