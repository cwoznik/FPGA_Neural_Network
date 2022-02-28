-- NNFPGA_rgb2grey
--
-- Converts RGB into Greyscale by weighted averaging, scaling the output to desired bitwidth 
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity NNFPGA_rgb2grey is
	--declare the generics in order to easily adapt the module for other situations 
	generic(inputDataSize   : integer;
			outputDataSize  : integer);
	
	 
	port(   clk        	: in 	std_logic;	--clock input
			rst			: in 	std_logic;  --rst input

			--rgb inputs 		
			rIn			: in std_logic_vector(inputDataSize-1 downto 0);
			gIn			: in std_logic_vector(inputDataSize-1 downto 0);
			bIn			: in std_logic_vector(inputDataSize-1 downto 0);

			--greysacale output of desired datasize 
			dataOut		: out std_logic_vector((outputDataSize-1) downto 0)); 
			
end NNFPGA_rgb2grey;


architecture behave of NNFPGA_rgb2grey is		
begin
	process (clk) 
		--variable to store the input before shifting to the desired data size
		variable greyFullBit : std_logic_vector(inputDataSize-1 downto 0);
	begin
		if rising_edge(clk) then
			-- if reset is enabled dataOut should be all 0
			if (rst = '1') then 
				dataOut <= (others => '0');
			else
				--instead of using multiplications approximate the weighted averaging with shifts. Wighted average is 0.21R+0,72G+0,07B
				--with the shift we average 0.25R+0,6875G+0,0625B, it can be improved with more shifts but the approximation seems sufficient
				--alternative would be: R >> 2 - R >> 5 - R >> 7; G >> 1 + G >> 3 + G >> 4 + G >> 5; B >> 2 + B >> 7. 
				greyFullBit := std_logic_vector(	shift_right(unsigned(rIn),2) + 	--r * 0,25
													shift_right(unsigned(gIn),1) + 	--g * 0,5
													shift_right(unsigned(gIn),3) + 	--g * 0,125
													shift_right(unsigned(gIn),4) + 	--g * 0,0625
													shift_right(unsigned(bIn),4)); 	--b * 0,0625
					
				--if we want a bigger output data than the input data									
				if (outputDataSize > inputDataSize) then 		
					-- we need to shift the values to the right	
					dataOut <= std_logic_vector(shift_left(resize(unsigned(greyFullBit),dataOut'length),outputDataSize-inputDataSize)); 
					
				--if it is smaller, we need to shift it left. If it is the same it does not matter since shift 0 does nothing 
				else 
					dataOut <= std_logic_vector(resize(shift_right(unsigned(greyFullBit),inputDataSize-outputDataSize),dataOut'length));
				end if;
			end if;
		end if;
	end process;
	
end behave;