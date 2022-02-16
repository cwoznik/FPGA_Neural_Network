-- NNFPGA_pkg
--
-- stores all required types and defines for the project 
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package NNFPGA_pkg is 
	--array to std_logic_vectors
	type t_variableSizeLogicVectorArray is array (natural range <>) of std_logic_vector; 
	--array of integer
	type t_variableSizeIntegerArray is array (natural range <>) of integer;

	--record for layer information
	type t_layerInformation is record
		activationFunction 	: integer range 0 to 10;
		inputCount			: integer range 0 to 2**10;
		neuronCount			: integer range 0 to 2**10; 
	end record t_layerInformation;

	--array for the network 
	type t_networkInformation is array (natural range <>) of t_layerInformation;
	
end package NNFPGA_pkg;