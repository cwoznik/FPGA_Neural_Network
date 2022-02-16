-- NNFPGA_oneShift.vhd
--
-- Activation funktion Relu 
--          x if x > 0
-- relu = {
--			0 else
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.Math_real.all;

entity NNFPGA_relu is
	generic (	inputDataWidth 	: integer;
				outputDataWidth	: integer);

	port (	clk        	: in 	std_logic := '0';	
			rst 		: in 	std_logic := '0';		
			
			dataIn		: in std_logic_vector(inputDataWidth-1 downto 0) := (others => '0');
			
			dataOut		: out std_logic_vector(outputDataWidth-1 downto 0) := (others => '0'));
			
end NNFPGA_relu;


architecture behave of NNFPGA_relu is	
	constant maxValue : std_logic_vector(outputDataWidth-1 downto 0) := '0' & (outputDataWidth -2 downto 0 => '1');
	--add one input buffer stage
	signal inputBuffer : std_logic_vector(inputDataWidth-1 downto 0);
begin
	process (clk) begin
		if rising_edge(clk) then
			--if we have reset output 0
			if rst = '1' then
				dataOut <= (others => '0');
			else
				inputBuffer <= dataIn;						--write the data into the buffer 
				
				if (signed(inputBuffer) < 0) then 			--if we have a negative number then relu is 0 
					dataOut <= (others =>'0');
				else if (signed(inputBuffer) > signed(maxValue)) then 		--if the input is bigger than the we can store it in output, clamp it to the max
						dataOut <= maxValue;								--for 2's complement 2^(n-1)-1 is the maximum number. 
																			--Could also be represented as dataOut <= (dataOut'high <= '0', others => '1')
					else 													--if ihe value is 0 <= datain < 2^(outputDataWidth-1)-1 just return the value
						dataOut <= inputBuffer(outputDataWidth-1 downto 0);
					end if;
				end if;
			end if;
		end if;
	end process;
end behave;