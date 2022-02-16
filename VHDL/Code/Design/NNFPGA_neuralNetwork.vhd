-- NNFPGA_staticMultiplier
--
-- Neuron module for the neural network
--
-- (c) Christian Woznik

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

use work.NNFPGA_pkg.all; 

entity NNFPGA_neuralNetwork is
	generic(dataWidth 			: integer;
			fixedPointPos		: integer;
			networkInformation  : t_networkInformation;
			weights 			: t_variableSizeIntegerArray);
	
	 
	port(   clk        	: in 	std_logic := '0'; 
			rst			: in 	std_logic := '0'; 

			dataIn		: in t_variableSizeLogicVectorArray(0 to networkInformation(networkInformation'low).inputCount-1)(dataWidth -1 downto 0) := (others=>(others => '0'));

			dataOut		: out t_variableSizeLogicVectorArray(0 to networkInformation(networkInformation'high).neuronCount-1)(dataWidth-1 downto 0)  := (others=>(others => '0'))); 
			
end NNFPGA_neuralNetwork;


architecture behave of NNFPGA_neuralNetwork is	 

	function countStoragePlaces(networkInformation : t_networkInformation) return integer is
		variable storagePlaces : integer := 0;
	begin   
		for i in networkInformation'range loop
			storagePlaces := storagePlaces + networkInformation(i).inputCount;
		end loop;

		storagePlaces := storagePlaces + networkInformation(networkInformation'high).neuronCount; 

		return storagePlaces;
	end function;

	function calculateWeightsStartPosition(networkInformation : t_networkInformation; high : integer) return integer is 
	begin
		if high = 0 then
			return 0;
		else 
			return calculateWeightsStartPosition(networkInformation, high -1) + (networkInformation(high-1).inputCount +1) * networkInformation(high-1).neuronCount;
		end if;
	end function;

	function calculateOutputStartPosition(networkInformation  : t_networkInformation; high : integer) return integer is
		variable startPosition : integer := 0;
	begin   
		if high = 0 then
			return 0;
		end if;
		
		for i in 0 to high-1 loop
			startPosition := startPosition + networkInformation(i).inputCount;
		end loop;

		return startPosition;
	end function;



	constant storagePlaces : integer := countStoragePlaces(networkInformation); 
	signal layerConnection : t_variableSizeLogicVectorArray(0 to storagePlaces-1)(dataWidth-1 downto 0) := (others => (others => '0'));

begin 
	--instatiate the neurons for the layer
	process (clk) begin
		if rising_edge(clk) then
			layerConnection(0 to networkInformation(networkInformation'low).inputCount-1) <= dataIn;
		end if; 
	end process;

	layers : for i in networkInformation'range generate
		constant inputStartPosition 	: integer := calculateOutputStartPosition(networkInformation,i);
		constant inputStopPosition 		: integer := calculateOutputStartPosition(networkInformation,i+1);

		constant weightsStartPosition 	: integer := calculateWeightsStartPosition(networkInformation,i);
		constant weightsStopPosition	: integer := calculateWeightsStartPosition(networkInformation,i+1);

		--we need to slice it before in order to always have a range of 0 .. weitghtsCount for the array
		--otherwise we get an array with a range from weightsStartPosition .. weightsStopPosition which causes problems in the layer as we try to access
		--the value 0 there and it is out of range
		constant weightsSlice 			: t_variableSizeIntegerArray(0 to weightsStopPosition-weightsStartPosition-1) := weights(weightsStartPosition to weightsStopPosition-1);
	begin
		layerX: entity work.NNFPGA_layer
			generic map(dataWidth 			=> dataWidth,
						fixedPointPos		=> fixedPointPos,
						layerInformation	=> networkInformation(i),
						weights				=> weightsSlice)
			port map(   clk        	=> clk,
						rst			=> rst,
	
						dataIn		=> layerConnection(inputStartPosition to inputStopPosition-1),
						dataOut		=> layerConnection(inputStopPosition to inputStopPosition + networkInformation(i).neuronCount-1)); 
	end generate;	

	process(clk)
		constant outputStartPosition 	: integer := calculateOutputStartPosition(networkInformation,networkInformation'length);
	begin
		if rising_edge(clk) then
			if rst = '1' then
				dataOut <= (others => (others => '0'));
			else 
				dataOut <= layerConnection(outputStartPosition to layerConnection'length -1);
			end if;
		end if;
	end process;

	
end behave;