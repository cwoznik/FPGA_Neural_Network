-- NNFPGA.vhd
--
-- top level module that implements the entire fpga design for this project
--
-- (c) Christian Woznik

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.NNFPGA_pkg.all;
use work.NNFPGA_statics.all;
use work.NNFFPGA_Network_firstModel_statics.all;
use work.NNFFPGA_Network_secondModel_statics.all;

library std;
use std.textio.all;

entity NNFPGA is
  port (clk       : in  std_logic;                      -- input clock 74.25 MHz, video 720p
        reset_n   : in  std_logic;                      -- reset (invoked during configuration)
        enable_in : in  std_logic_vector(2 downto 0);   -- three slide switches
        -- video in
        vs_in     : in  std_logic;                      -- vertical sync
        hs_in     : in  std_logic;                      -- horizontal sync
        de_in     : in  std_logic;                      -- data enable is '1' for valid pixel
        r_in      : in  std_logic_vector(7 downto 0);   -- red component of pixel
        g_in      : in  std_logic_vector(7 downto 0);   -- green component of pixel
        b_in      : in  std_logic_vector(7 downto 0);   -- blue component of pixel
        -- video out
        vs_out    : out std_logic;                      -- corresponding to video-in
        hs_out    : out std_logic;
        de_out    : out std_logic;
        r_out     : out std_logic_vector(7 downto 0);
        g_out     : out std_logic_vector(7 downto 0);
        b_out     : out std_logic_vector(7 downto 0);
        --
        clk_o     : out std_logic;                      -- output clock (do not modify)
        led       : out std_logic_vector(2 downto 0));  -- not supported by remote lab
end NNFPGA;

architecture behave of NNFPGA is

	-- input/output FFs
	signal reset            			    : std_logic;
	signal enable           			    : std_logic_vector(2 downto 0);
	signal rgb_out  						      : std_logic_vector(23 downto 0);
	signal rBuffer, gBuffer, bBuffer  : std_logic_vector(7 downto 0);
	signal greyIn			   			        : std_logic_vector(c_DataWidth-1 downto 0);
	signal vs_0, hs_0, de_0 			    : std_logic;
	signal vs_1, hs_1, de_1 			    : std_logic;
	
	signal firstNetworkDataIn 				: t_variableSizeLogicVectorArray(0 to (c_InputShape**2)-1)(c_DataWidth-1 downto 0);
	signal firstNetworkDataOut				: t_variableSizeLogicVectorArray(0 to c_networkfirstModelLayerInformation(c_networkfirstModelLayerInformation'length-1).neuronCount-1)(c_DataWidth-1 downto 0);

  signal secondNetworkDataIn 				: t_variableSizeLogicVectorArray(0 to (c_networksecondModelLayerInformation(0).inputCount-1))(c_DataWidth-1 downto 0);
	signal secondNetworkDataOut				: t_variableSizeLogicVectorArray(0 to c_networksecondModelLayerInformation(c_networksecondModelLayerInformation'length-1).neuronCount-1)(c_DataWidth-1 downto 0);

  signal detectedClass              : integer; 
 
begin  
	process
	begin

		wait until rising_edge(clk);

		-- input FFs for control
		reset  	<= not reset_n;
		enable 	<= enable_in;
		-- input FFs for video signal
		vs_0   	<= vs_in;
		hs_0   	<= hs_in;
		de_0   	<= de_in;
		rBuffer 	<= r_in;
		gBuffer 	<= g_in;
		bBuffer 	<= b_in;
	end process;

  --convert the RGB inputs to greyscale values for this project
  rgb2grey : entity work.NNFPGA_rgb2grey
    generic map(inputDataSize   => 8,
                outputDataSize  => c_DataWidth)
    port map( clk       => clk,
              rst		   => reset,
	 
              rIn		   => rBuffer,
              gIn		   => gBuffer,
              bIn		   => bBuffer,

              dataOut	=> greyIn); 

  --we need a 7x7 input so we delay the input and store it in this martix 
  inputDelay : entity work.NNFPGA_matrixDelay
      generic map(n				  	=> c_InputShape,
                  dataWidth 	  	=> c_DataWidth,
                  newLineLength	=> 1280)
      port map( clk     => clk,
                rst		=> reset,
                wrEn		=> de_0,
          
                dataIn	=> std_logic_vector(shift_right(unsigned(greyIn),c_DataWidth-c_FixedPointPos)),
                
                dataOut => firstNetworkDataIn);
  
  --the first network that is used to classify the subshapes 
  firstNetwork : entity work.NNFPGA_neuralNetwork
      generic map(dataWidth 			    => c_DataWidth,
                  fixedPointPos		    => c_FixedPointPos,
                  networkInformation  => c_networkfirstModelLayerInformation,
                  weights 			      => c_networkfirstModelWeights)


      port map( clk        	=> clk,
                rst			    => reset,

                dataIn	    => firstNetworkDataIn,
                dataOut		  => firstNetworkDataOut); 

  --the second network needs again a matrix. This time a 3x3. 
  interNetworkDelay_1 : entity work.NNFPGA_sparseMatrixDelayMultipleInput
        generic map(n				  	    => 15,
                    inputCount      => c_networkfirstModelLayerInformation(c_networkfirstModelLayerInformation'length-1).neuronCount,
                    dataWidth 	  	=> c_DataWidth,
                    newLineLength	  => 1280,
                    outputDim       => 3)
        port map( clk     => clk,
                  rst		  => reset,
                  wrEn		=> de_0,
            
                  dataIn	=> firstNetworkDataOut,
                  
                  dataOut => secondNetworkDataIn);     
              
  --run the second network to get a final classification                
  secondNetwork : entity work.NNFPGA_neuralNetwork
        generic map(dataWidth 			    => c_DataWidth,
                    fixedPointPos		    => c_FixedPointPos,
                   networkInformation  => c_networksecondModelLayerInformation,
                    weights 			      => c_networksecondModelWeights)


        port map( clk        	=> clk,
                  rst			    => reset,
 
 						dataIn	    => secondNetworkDataIn,
                  dataOut		  => secondNetworkDataOut); 

  --we only have the raw network output so we need to find the maximal value and thus the 
  --detected class
  maxPos : entity work.NNFPGA_maxPosition 
        generic map( inputCount 	      => secondNetworkDataOut'length,
                  dataWidth		      => c_DataWidth,
                  pipelineDistance 	=> 3)
        port map( clk       => clk,										

                dataIn		=> secondNetworkDataOut,
                dataOut 	=> detectedClass);

  --the class is just an integer. to display it we need to convert it to an RGB value
  encoder : entity work.NNFPGA_Encoding2RGB 
        port map(clk       => clk,											
            
              dataIn		=> detectedClass,
              rgbOut 		=> rgb_out);
            
  -- delay control signals to match pipeline stages of signal processing
  control : entity work.NNFPGA_sync
    generic map (delay => 57)
    port map (clk    => clk,
              reset  => reset,
              vs_in  => vs_0,
              hs_in  => hs_0,
              de_in  => de_0,
              vs_out => vs_1,
              hs_out => hs_1,
              de_out => de_1);

  process
  begin  
    wait until rising_edge(clk);
	 
    -- output FFs for video signal
    vs_out <= vs_1;
    hs_out <= hs_1;
    de_out <= de_1;
    if (de_1 = '1') then
      -- active video
      r_out <= rgb_out(23 downto 16);
      g_out <= rgb_out(15 downto 8);
      b_out <= rgb_out(7 downto 0);

    else
      -- blanking, set output to black
      r_out <= "00000000";
      g_out <= "00000000";
      b_out <= "00000000";

    end if;
  end process;

  -- do not modify
  clk_o <= clk;
  led   <= "000";

end behave;
