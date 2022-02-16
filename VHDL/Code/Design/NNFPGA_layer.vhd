-- NNFPGA_layer.vhd
--
-- This module instantiates the individual neurons for the network
-- for that it splits the weights array for each neuron
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

use work.NNFPGA_pkg.all; 

entity NNFPGA_layer is
	--declare the generics in order to easily adapt the module for other situations 
	generic(dataWidth 			: integer;
			fixedPointPos		: integer;
			layerInformation	: t_layerInformation;
			weights 			: t_variableSizeIntegerArray); 
	port(   clk        	: in 	std_logic := '0'; 
			rst			: in 	std_logic := '0';  	

			--data inputs. Minus 2 as the weighsArray also contains the weight for the bias neuron. So we have one input less than weights 		
			dataIn		: in t_variableSizeLogicVectorArray(0 to layerInformation.inputCount-1)(dataWidth -1 downto 0) := (others=>(others => '0'));

			--output  
			dataOut		: out t_variableSizeLogicVectorArray(0 to layerInformation.neuronCount-1)(dataWidth-1 downto 0)  := (others=>(others => '0'))); 
			
end NNFPGA_layer;


architecture behave of NNFPGA_layer is	
	signal neuronsOutput : t_variableSizeLogicVectorArray(0 to layerInformation.neuronCount-1)(dataWidth-1 downto 0)  := (others=>(others => '0')); 
begin 
	--test if we have the correct amount of weights. If not we throw an error and stop compilation
	assert (weights'length mod (layerInformation.inputCount+1) = 0) report "Can not devide the weights into subarrays of equal length! Got "
				& integer'image(weights'length)&" for "&integer'image(layerInformation.inputCount)&" inputs" severity failure; 

	--instatiate the neurons for the layer
	neurons : for i in 0 to layerInformation.neuronCount -1 generate
		--we need to slice it before in order to always have a range of 0 .. layerInformation.inputCount for the array
		--otherwise we get an array with a range from (i)*layerInformation.inputCount .. (i+1)*layerInformation.inputCount which causes problems in the neuron as we try to access
		--the value 0 there and it is out of range
		constant sliceWeights : t_variableSizeIntegerArray(0 to layerInformation.inputCount) := weights(i*(layerInformation.inputCount+1) to (i+1)*(layerInformation.inputCount+1)-1);
	begin	
		neuronX: entity work.NNFPGA_neuron
			generic map(inputDataWidth 		=> dataWidth,
						outputDataWidth		=> dataWidth, 
						fixedPointPos		=> fixedPointPos,
						weightsArray		=> sliceWeights,
						activationFunction 	=> layerInformation.activationFunction)
			port map(	clk        	=> clk,
						rst			=> rst, 

						dataIn		=> dataIn,
						dataOut		=> neuronsOutput(i));
	end generate;	

	process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				dataOut <= (others => (others => '0'));
			else 
				dataOut <= neuronsOutput;
			end if;
		end if;
	end process;

	
end behave;