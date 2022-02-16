-- NNFPGA_tanh.vhd
--
-- LUT for the activation funktion sigmoid
--
-- sigmoid(x) = 1/(1+e^(-x))
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.Math_real.all;


entity NNFPGA_tanh is
	generic (	inputDataWidth 	: integer;
				outputDataWidth	: integer;
				fixedPointPos	: integer);

	port (	clk        	: in 	std_logic := '0';
			rst			: in 	std_logic := '0';	
			
			dataIn		: in 	std_logic_vector(inputDataWidth-1 downto 0) := (others => '0');
			
			dataOut		: out 	std_logic_vector(outputDataWidth-1 downto 0) := (others => '0'));
			
end NNFPGA_tanh;


architecture lut of NNFPGA_tanh is		
	constant romBits : integer := fixedPointPos + 2; --We only need to look at the values from -2 to ~2 in the lut as tanh(2|-2) = 0,964|-0,964 so the error is small enough
	type sigmoidTab is array(0 to 2**romBits-1) OF STD_LOGIC_VECTOR (outputDataWidth-1 downto 0); --array for the output values 

	signal sigmoidRom: sigmoidTab;

	signal inputBuffer : std_logic_vector(inputDataWidth-1 downto 0);

begin

	romGenerator: for i in 0 to 2**romBits -1 GENERATE									--Generation of the LUT via Generate statment that way we do not need to create if manually
		constant x: real := real((real(i-2**(romBits-1))*real(4)/real(2**romBits))); 	--calculate x for a given i, i goes from 0 to 2**romBits-1 but x must go from -2 to 2
		CONSTANT y: REAL := (exp(x)-exp(-x))/(exp(x)+exp(-x));							--calulate the value for the tanh function
		CONSTANT yn: std_logic_vector(outputDataWidth-1 DOWNTO 0) := std_logic_vector(to_signed(INTEGER(y*real(2**fixedPointPos)),outputDataWidth)); --convert float to fixed point and store it as slv 
	BEGIN
		sigmoidRom(i) <= STD_LOGIC_VECTOR(yn);	--store the values in the LUT 
	END GENERATE;
	 
	process (clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				dataOut <= (others => '0');
			else
				inputBuffer <= dataIn;
			
				if (signed(inputBuffer) > 2**(romBits-1)-1) then 								--sigmoid function is 1 for values over 2 - 2^(fixedPointPos)	
					dataOut <= std_logic_vector(to_signed(2**fixedPointPos,dataOut'length));  	--write out 1
				else 
					if (signed(inputBuffer) < -2**(romBits-1)) then								-- and 1 for values under -2 
						dataOut <= std_logic_vector(to_signed(-2**fixedPointPos,dataOut'length)); 			
					else 																		--if the value is between -2 and 2 then use the LUT 
						dataOut <= sigmoidRom(to_integer(signed(inputBuffer))+2**(romBits-1)); 	
					end if; 
				end if;
			end if;
		end if;
	end process;
	
end lut;