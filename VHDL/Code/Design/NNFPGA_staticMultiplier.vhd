-- NNFPGA_staticMultiplier
--
-- Multiplies the input with a fixed value 
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity NNFPGA_staticMultiplier is
	--declare the generics in order to easily adapt the module for other situations 
	generic(dataSize   				: positive;		--datasize of the input 
			fixedpointPos			: positive; 	--fixedpoint position is the same for the input, the multiplication factor and the output
			multiplicationFactor 	: integer); 	--multiplication factor has the same datawidth than the input
	
	 
	port(   clk        	: in 	std_logic := '0';	--clock input
			rst			: in 	std_logic := '0';  --rst input

			--data inputs 		
			dataIn		: in std_logic_vector(dataSize -1 downto 0) := (others => '0');

			--output  
			dataOut		: out std_logic_vector((2*dataSize-fixedpointPos)-1 downto 0)  := (others => '0')); 
			
end NNFPGA_staticMultiplier;


architecture behave of NNFPGA_staticMultiplier is		
	constant minVal : integer := -2**(dataSize-1);
	constant maxVal : integer := 2**(dataSize-1)-1;
begin
	process (clk) 
		variable multiplicationResult : integer; 
	begin
		--make sure the multiplication factor is inside the valid range. Otherwise overflows might occur
		assert (minVal <= multiplicationFactor) report "multiplication factor smaller than allowed! Got: "&integer'image(multiplicationFactor)&", Min: "&integer'image(minVal) severity failure;
		assert (maxVal >= multiplicationFactor) report "multiplication factor bigger than allowed! Got: "&integer'image(multiplicationFactor)&", Max: "&integer'image(maxVal) severity failure; 

		if rising_edge(clk) then
			-- if reset is enabled dataOut should be all 0
			if (rst = '1') then 
				dataOut <= (others => '0');
			else
				--do a multiplication of the input with the fixed factor
				multiplicationResult := to_integer(signed(dataIn)) * multiplicationFactor;
				--with a fixedpoint multiplication the resulting fixedpoint position is the sum of both positions
				--as we do not need such a big number we just shift the result right by the fixed point position 
				dataOut <= std_logic_vector(resize(shift_right(to_signed(multiplicationResult,2*dataSize),fixedpointPos),dataOut'length));
			end if;
		end if;
	end process;
	
end behave;