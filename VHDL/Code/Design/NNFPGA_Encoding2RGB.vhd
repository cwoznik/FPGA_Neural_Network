-- NNFPGA_Encoding2RGB.vhd
--
-- Creates RGB value from an integer value for the output 
-- ToDo: change so it is configurable via generics
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity NNFPGA_Encoding2RGB is
	port (	clk        	: in 	std_logic;											
			
			dataIn		: in integer range 0 to 11;
			
			rgbOut 		: out std_logic_vector(23 downto 0));
			
end NNFPGA_Encoding2RGB;

architecture behave of NNFPGA_Encoding2RGB is	
	--ToDo. Generate the color list during complile in order to accept different bitwidth 
	subtype t_color is std_logic_vector(23 downto 0);
	type t_colorArray is array (0 to 11) of t_color;
	constant colors : t_colorArray := (		0=> "000000000000000000000000",     	--0x2F4F4F (dark cyan)
											1=> "000000001111111100000000",			--0x000080 (dark blue)
											2=> "000000000000000011111111",			--0x8470FF (light blue)
											3=> "111111111111111100000000",			--0xADD8E6 (light turquoise)
											4=> "111111110000000000000000",			--0x006400 (dark green)
											5=> "000000000000000000000000",			--0x7CFC00 (neon green)
											6=> "000000000000000000000000",			--0x12F669 (light green)
											7=> "000000000000000000000000",			--0xFFFF00 (yellow)
											8=> "000000000000000000000000",			--0xB8868F (rose)
											9=> "000000000000000000000000", 		--0xB22222 (red)
											10=> "000000000000000000000000",		--0xFFFFFF (white)
											11=> "000000000000000000000000");		--0x000000 (black)

begin
	process(clk)
	begin
		if rising_edge(clk)  then
			rgbOut <= colors(dataIn);
			
		end if; 
	end process;
	 
end behave;