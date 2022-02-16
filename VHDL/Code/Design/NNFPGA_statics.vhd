--Packe for variable size of std_logic_vector

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package NNFPGA_statics is
	constant c_InputShape					: integer := 7;
	constant c_FixedPointPos				: integer := 5;	
	constant c_DataWidth					: integer := 8;	
end package NNFPGA_statics; 