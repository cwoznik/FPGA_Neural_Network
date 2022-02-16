-- NNFPGA_sparseMatrixDelayMultipleInput.vhd
--
-- This module implements a NNFPGA_matrixDelayMultipleInput however as we do not need all values
-- in this project we do not care about most of the outputs. This module reduces the output size
-- to the required values for easier handling
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.NNFPGA_pkg.all;


entity NNFPGA_sparseMatrixDelayMultipleInput is
	generic (	n				: integer;      --dimension of the matrix 
				inputCount		: integer;
				dataWidth 	    : integer;      --datawidth for the matrix
				newLineLength	: integer;      --when to start storing in a new line
				outputDim		: integer);		--we only want a certain amount of outputs from the full matrix

	port(   clk         : in 	std_logic;
			rst			: in 	std_logic;
			wrEn		: in	std_logic;
			
			dataIn		: in 	t_variableSizeLogicVectorArray(0 to inputCount-1) (dataWidth-1 downto 0);
			
			dataOut 	: out 	t_variableSizeLogicVectorArray(0 to inputCount*(outputDim**2)-1) (dataWidth-1 downto 0));
			
end NNFPGA_sparseMatrixDelayMultipleInput;


architecture behave of NNFPGA_sparseMatrixDelayMultipleInput is
	signal fullMatrixOutput :  t_variableSizeLogicVectorArray(0 to inputCount*(n**2)-1) (dataWidth-1 downto 0) := (others => (others => '0'));
begin
	--test if the matrix is actually possible	
	assert (n-1) mod (outputDim-1) = 0 
		report "Matrix and output dimensions do not match. Got n: " & integer'image(n) & " and outputDim: " & integer'image(outputDim) & ". n must be a multiple of outputDim + 1!"
	 	severity failure;
	
	--instantiate the full Matrix Delay 
	NNFPGA_matrixDelayMultipleInput_inst : ENTITY work.NNFPGA_matrixDelayMultipleInput(behave)
    generic map(n				=> n,
                inputCount      => inputCount,
                dataWidth 	    => dataWidth,
                newLineLength	=> newLineLength) 
    port map(
        clk        	=> clk,
        rst			=> rst,
        wrEn        => wrEn,

        dataIn      => dataIn,

        dataOut		=> fullMatrixOutput);

	process 
		variable finalOutput 						: t_variableSizeLogicVectorArray(0 to inputCount*outputDim**2-1) (dataWidth-1 downto 0);

		variable i,j,k								: integer := 0; 
		variable positionOutput,positionFullMatrix	: integer := 0;

		constant distance							: integer := (n-1)/(outputDim-1);
	begin
		wait until rising_edge(clk);

		for i in 0 to outputDim-1 loop
			for j in 0 to outputDim-1 loop
				--calculate the position in both matrixies
				positionOutput 		:= i*outputDim+j;
				positionFullMatrix 	:= (i*n+j)*distance;

				--as each cell contains more than one value we need to go through all of them
				for k in 0 to inputCount-1 loop
					finalOutput(positionOutput*inputCount+k) := fullMatrixOutput(positionFullMatrix*inputCount+k);
				end loop;
			end loop;
		end loop;
		
		dataOut <= finalOutput;
	end process;	

	
	
end behave;