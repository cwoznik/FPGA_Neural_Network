-- NNFPGA_staticMultiplier
--
-- Neuron module for the neural network
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

use work.NNFPGA_pkg.all; 

entity NNFPGA_neuron is
	--declare the generics in order to easily adapt the module for other situations 
	generic(inputDataWidth 		: integer;
			outputDataWidth		: integer;
			fixedPointPos		: integer;
			weightsArray		: t_variableSizeIntegerArray;
			activationFunction 	: integer);
	
	 
	port(   clk        	: in 	std_logic := '0';	--clock input
			rst			: in 	std_logic := '0';  --rst input

			--data inputs. Minus 2 as the weighsArray also contains the weight for the bias neuron. So we have one input less than weights 		
			dataIn		: in t_variableSizeLogicVectorArray(0 to weightsArray'length-2)(inputDataWidth -1 downto 0) := (others=>(others => '0'));

			--output  
			dataOut		: out std_logic_vector(outputDataWidth-1 downto 0)  := (others => '0')); 
			
end NNFPGA_neuron;


architecture behave of NNFPGA_neuron is	
	constant multiplierDataOutputWidth 	: integer := 2*inputDataWidth-fixedpointPos;
	constant treeadderDataOuputWidth	: integer := multiplierDataOutputWidth + integer(ceil(log2(real(weightsArray'length))));
	constant treeaderPipelineDistance 	: integer := 8;

	signal multipierDataOut 		: t_variableSizeLogicVectorArray(0 to weightsArray'length-1)(multiplierDataOutputWidth-1 downto 0) := (others=>(others => '0'));
	signal treeadderDataOut 		: std_logic_vector(treeadderDataOuputWidth-1 downto 0) := (others => '0');
begin
	--instatiate the multiplicators for the inputs 
	multipicators : for i in 0 to weightsArray'length -2 generate
		multiplicatorX: entity work.NNFPGA_staticMultiplier
			generic map(dataSize   				=> inputDataWidth,
						fixedpointPos			=> fixedPointPos,
						multiplicationFactor 	=> weightsArray(i))
			port map( 	clk        	=> clk,
						rst			=> rst,	
		
						dataIn		=> dataIn(i),
						dataOut		=> multipierDataOut(i));
	end generate;

	--instatiate the multiplicator for the bias input. Its input is always 1.  
	biasMultiplicator : entity work.NNFPGA_staticMultiplier
		generic map(	dataSize   				=> inputDataWidth,
						fixedpointPos			=> fixedPointPos,
						multiplicationFactor 	=> weightsArray(weightsArray'length-1))
		port map( 	clk        	=> clk,
					rst			=> rst,	
	
					dataIn		=> std_logic_vector(to_signed(2**fixedPointPos,inputDataWidth)),
					dataOut		=> multipierDataOut(weightsArray'high));

	--instatiate the treeadder for the outputs of the multiplicators 
	treeAdder : entity work.NNFPGA_treeAdder 
		generic map(inputCount 			=> weightsArray'length,
					inputdataWidth		=> multiplierDataOutputWidth,
					pipelineDistance 	=> treeaderPipelineDistance)
	
		port map(	clk        	=> clk,										
					rst			=> rst,
							
					dataIn		=> multipierDataOut,
					dataOut		=> treeadderDataOut);

	--instatiate the actication function based on the generic
	--initiate no activation function if none is specified or softmax
	activationFunctionNone: if (activationFunction = 0) or (activationFunction = 5) generate 
		noActivation : entity work.NNFPGA_noActivation 
			generic map(inputDataWidth 	=> treeadderDataOuputWidth, 
						outputDataWidth	=> outputDataWidth)
		
			port map(	clk        	=> clk,
						rst 		=> rst,		
					
						dataIn		=> treeadderDataOut,
						dataOut		=> dataOut);
	end generate activationFunctionNone;

	--initiate RELU
	activationFunctionRelu: if (activationFunction = 1) generate 
		relu : entity work.NNFPGA_relu 
			generic map(inputDataWidth 	=> treeadderDataOuputWidth, 
						outputDataWidth	=> outputDataWidth)
		
			port map(	clk        	=> clk,
						rst 		=> rst,		
					
						dataIn		=> treeadderDataOut,
						dataOut		=> dataOut);
	end generate activationFunctionRelu;

	--initiate sigmoid
	activationFunctionSigmoid: if (activationFunction = 2) generate 
		sigmoid : entity work.NNFPGA_sigmoid
			generic map(inputDataWidth 	=> treeadderDataOuputWidth, 
						outputDataWidth	=> outputDataWidth,
						fixedPointPos 	=> fixedPointPos)
		
			port map(	clk        	=> clk,
						rst 		=> rst,		
					
						dataIn		=> treeadderDataOut,
						dataOut		=> dataOut);
	end generate activationFunctionSigmoid;			

	--initiate tanh
	activationFunctionTanH: if (activationFunction = 3)or(activationFunction = 4) generate 
		tanh_act : entity work.NNFPGA_tanh
		generic map(inputDataWidth 	=> treeadderDataOuputWidth, 
					outputDataWidth	=> outputDataWidth,
					fixedPointPos 	=> fixedPointPos)
		
			port map(	clk        	=> clk,
						rst 		=> rst,		
					
						dataIn		=> treeadderDataOut,
						dataOut		=> dataOut);
	end generate activationFunctionTanH;
	
end behave;