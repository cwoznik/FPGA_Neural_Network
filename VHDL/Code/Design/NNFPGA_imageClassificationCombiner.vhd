-- NNFPGA_imageClassificationCombiner
--
-- This module delays the original image input and overlays it with the classification for the area
-- mixBitStart and mixBitStop are the start and stop bits for the classification. So if you want to have 
-- the classification in the foreground you have to have to use the high bits
-- Example: mixBitStart <= dataWidth -3 
--          mixBitStop  <= dataWidth -1 
-- 
--
-- (c) Christian Woznik

--import the standard libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

USE ieee.math_real.log2;
USE ieee.math_real.ceil;

use work.NNFPGA_pkg.all; 

entity NNFPGA_imageClassificationCombiner is
	--declare the generics in order to easily adapt the module for other situations 
	generic(dataWidth 			: integer;
            colorChannels       : integer;
            delayClocks         : integer;
            mixBitStart         : integer;
            mixBitStop          : integer); 
	port(   clk        	            : in 	std_logic := '0'; 
			rst			            : in 	std_logic := '0';  	

			imageDataIn             : in    std_logic_vector(colorChannels*dataWidth-1 downto 0);
            classificationDataIn    : in    std_logic_vector(colorChannels*dataWidth-1 downto 0);

			dataOut		            : out   std_logic_vector(colorChannels*dataWidth-1 downto 0));
			
end NNFPGA_imageClassificationCombiner;


architecture behave of NNFPGA_imageClassificationCombiner is	
    -- constant needed for the linemem instance 
    constant writeEn        : std_logic := '1';

    -- output of the linemem instance 
    signal delayedImageData : std_logic_vector(colorChannels*dataWidth-1 downto 0);

begin 
    -- test the ranges of the mix bits. Throw readable errors if the are outside the allowed ranges 
    assert mixBitStart <= mixBitStop 
        report  "mixBitStart must be smaller or equal than MixBitStop! Currently Start: " & integer'image(mixBitStart) & "; Stop: " & integer'image(mixBitStop)
        severity failure;

    assert mixBitStart >= 0 and mixBitStart < dataWidth 
        report "mixBitStart is out of range 0 to " & integer'image(dataWidth-1) & "! Current Value: " & integer'image(mixBitStart)
        severity failure;

    assert mixBitStop >= 0 and mixBitStop < dataWidth 
        report "mixBitStop is out of range 0 to " & integer'image(dataWidth-1) & "! Current Value: " & integer'image(mixBitStop)
        severity failure; 

    -- instatiate the linememory to delay the image data
	imageDataDelay : entity work.NNFPGA_linemem
        generic map(dataWidth 		=> colorChannels*dataWidth,
                    memoryLength 	=> delayClocks)

        port  map(  clk       => clk,
                    reset     => rst,
                    write_en  => writeEn,
                    data_in   => imageDataIn,
                    data_out  => delayedImageData);

    -- mix the data according to the generics 
    process(clk) begin
        if rising_edge(clk) then
            if rst = '0' then
                for i in 1 to colorChannels loop
                    if mixBitStart = 0 and mixBitStop=dataWidth-1 then
                        dataOut(i*dataWidth-1 downto (i-1)*dataWidth) <= classificationDataIn(i*dataWidth-1 downto (i-1)*dataWidth);
                    elsif mixBitStart = 0 then
                        dataOut(i*dataWidth-1 downto (i-1)*dataWidth) <=    delayedImageData(i*dataWidth-1 downto (i-1)*dataWidth + mixBitStop) &
                                                                            classificationDataIn(i*dataWidth-1 downto i*dataWidth-mixBitStart);
                    elsif mixBitStop = dataWidth-1 then
                        dataOut(i*dataWidth-1 downto (i-1)*dataWidth) <=    classificationDataIn(i*dataWidth-1 downto (i-1)*dataWidth + mixBitStart) & 
                                                                            delayedImageData(i*dataWidth-1 downto i*dataWidth-mixBitStart);
                    else 
                        dataOut(i*dataWidth-1 downto (i-1)*dataWidth) <=    delayedImageData(i*dataWidth-1 downto (i-1)*dataWidth + mixBitStop) & 
                                                                            classificationDataIn((i-1)*dataWidth + mixBitStop-1 downto (i-1)*dataWidth + mixBitStart) &
                                                                            delayedImageData((i-1)*dataWidth + mixBitStart-1 downto (i-1)*dataWidth);
                    end if; 
                end loop;
            else 
                dataOut <= (others => '0');
            end if; 
        end if; 
    end process; 
end behave;