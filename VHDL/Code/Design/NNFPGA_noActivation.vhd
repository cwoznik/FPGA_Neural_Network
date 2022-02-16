-- NNFPGA_oneShift.vhd
--
-- No activation function
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.Math_real.all;

entity NNFPGA_noActivation is
	generic (	inputDataWidth 	: integer;
				outputDataWidth	: integer);

	port (	clk        	: in 	std_logic := '0';	
			rst 		: in 	std_logic := '0';		
			
			dataIn		: in std_logic_vector(inputDataWidth-1 downto 0) := (others => '0');
			
			dataOut		: out std_logic_vector(outputDataWidth-1 downto 0) := (others => '0'));
			
end NNFPGA_noActivation;


architecture behave of NNFPGA_noActivation is	
	constant minValue : std_logic_vector(outputDataWidth-1 downto 0) := '1' & (outputDataWidth -2 downto 0 => '0');
	constant maxValue : std_logic_vector(outputDataWidth-1 downto 0) := '0' & (outputDataWidth -2 downto 0 => '1');
	--add one input buffer stage as all activation functions have it. 
	--That way we make sure, that we do not have a missmatch in the timings
	signal inputBuffer : std_logic_vector(inputDataWidth-1 downto 0);
begin
	process (clk) begin
		if rising_edge(clk) then
			inputBuffer <= dataIn;

			if rst = '1' then
				dataOut <= (others => '0');
			else
				if signed(inputBuffer) < signed(minValue) then
					dataOut <= minValue;
				elsif signed(inputBuffer) > signed(maxValue) then
					dataOut <= maxValue;
				else 
					dataOut <= std_logic_vector(resize(signed(inputBuffer),outputDataWidth));
				end if; 

			end if;
		end if;
	end process;
end behave;