-- NNFPGA_maxPosition.vhd
--
-- Calculates the maximum to determine the class of the object via treesearch
-- Can to be piplined to solve timing problems 

-- toDo: at negative values disable piplining completly
-- workaround: just set the pipleline distance to an high number
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

use work.NNFPGA_pkg.all; 

entity NNFPGA_maxPosition is
	generic (	inputCount 			: integer;
				dataWidth			: integer;
				pipelineDistance 	: integer);
	port 	(clk        : in 	std_logic;											
			
			dataIn		: in t_variableSizeLogicVectorArray(0 to inputCount-1)(dataWidth-1 downto 0);
			
			dataOut 	: out integer := 0);
			
end NNFPGA_maxPosition;


architecture behave of NNFPGA_maxPosition is		
	type t_positionStorage is array (0 to inputCount-1) of integer range 0 to inputCount-1;		
	type t_positionStorageArray is array (0 to integer(ceil(ceil(log2(real(inputCount))))/real(pipelineDistance))) 
											of t_positionStorage; -- position buffers for pipelining
	signal postitionStorageArray : t_positionStorageArray; 
	
	type t_dataStorageArray is array (0 to integer(ceil(ceil(log2(real(inputCount))))/real(pipelineDistance))) 
											of t_variableSizeLogicVectorArray(0 to dataIn'length-1)(dataWidth-1 downto 0); --data buffer for pipelining
	signal dataStorageArray : t_DataStorageArray;
	
begin
	process(clk)
		variable storage 	: t_variableSizeLogicVectorArray(0 to inputCount-1)(dataWidth-1 downto 0);
		variable positions	: t_positionStorage; 
		variable i,j,k,step	: integer;
	begin
		if rising_edge(clk)  then
			for i in 0 to inputCount-1 loop
				positions(i) := i;
			end loop;
		
			k := 0;
			
			storage := dataIn;
			
			for step in 0 to integer(ceil(log2(real(inputCount)))) loop 					--treesearch uses log2 steps to complete 
			
				if (step mod pipelineDistance = 0) then										--add a buffer every second stage  															
					dataStorageArray(k) 			<= storage;
					storage 						:= dataStorageArray(k);
					
					if (step /= 0) then														--no nessecity to store the positions at position 0
						postitionStorageArray(k) 	<= positions;
						positions					:= postitionStorageArray(k);
					end if;
					
					k := k+1; 
				end if; 
				
				for item in 0 to integer(ceil(real(inputCount) / real(2)))-1 loop		--iterate over the input, we only need to iterate through half, because we always compare two elements 
					i := 2**(step+1)*item;												--calculate the first element to compare. For the first step this formular is 2*item
					j := i+2**step;														--calculate the second element. For the first step this is 2*item+1 so we compare the two neighbours 
					next when((i > storage'right) or (j > storage'right));				--important for every step after 1. We must stay within our arry 
					if (signed(storage(j)) > signed(storage(i))) then					--if the right number is bigger move it
						storage(i) := storage(j);										--since in the second step we have i=4*item and j=4*item+2 we then compare only the remaining value
						positions(i) := positions(j);									--this is completed until we only have one number left 
					end if;																		
				end loop;  
			end loop;
			
			dataOut <= positions(0); 
		end if; 
	end process;
	 
end behave;