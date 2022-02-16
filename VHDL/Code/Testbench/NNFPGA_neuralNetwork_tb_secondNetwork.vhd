--IEEE Lib for logic and numeric signals
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.math_real.all;

use std.textio.all;
use ieee.std_logic_textio.all;

library design_lib;
use design_lib.NNFPGA_pkg.all;
use design_lib.NNFPGA_statics.all;

use design_lib.NNFFPGA_Network_firstModel_statics.all;
use design_lib.NNFFPGA_Network_secondModel_statics.all;

--vunit test lib
LIBRARY VUNIT_LIB;
CONTEXT VUNIT_LIB.VUNIT_CONTEXT;

--entity declaration. Runner is used by VUNIT
entity NNFPGA_neuralNetwork_tb_secondNetwork IS
    generic(generics    : string;
            runner_cfg  : string := runner_cfg_default);
end entity NNFPGA_neuralNetwork_tb_secondNetwork;

architecture tb of NNFPGA_neuralNetwork_tb_secondNetwork is
    type t_tbCFG is record
        dataSize   				: positive;	
        fixedpointPos			: positive; 
    end record t_tbCFG;

    --decode the generic from the string as we need to pass them as a string1
    impure function decode(encoded_tb_cfg : string) return t_tbCFG is
    begin
        return (dataSize                => positive'value(get(encoded_tb_cfg, "dataSize")),
                fixedpointPos           => positive'value(get(encoded_tb_cfg, "fixedpointPos")));
    end function decode;

    --define constants 
    constant c_clkPeriod       : time := 10 ns;  
    constant tbCfg             : t_tbCFG := decode(generics);
    constant stimuliFilename   : string := "C:\Users\Unknown\Documents\Master-Convolution\VHDL\Code\Testbench\inSecond.txt";
    constant testFilename      : string := "test.txt";
    constant outputFilenameRaw : string := "C:\Users\Unknown\Documents\Master-Convolution\VHDL\Code\Testbench\outSecondRAW.txt";
    constant outputFilenameRGB : string := "C:\Users\Unknown\Documents\Master-Convolution\VHDL\Code\Testbench\outSecondRGB.txt";


    signal  xSize, ySize       : integer:= 0;


    --signals for the DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal en       : std_logic := '0';


    signal startSaveRGB   : std_logic := '0';
    signal startSaveRaw   : std_logic := '0';

    signal rBuffer, gBuffer, bBuffer        : std_logic_vector(7 downto 0);

    signal greyIn			   			    : std_logic_vector(c_DataWidth-1 downto 0);

    signal firstNetworkDataIn 				: t_variableSizeLogicVectorArray(0 to (c_InputShape**2)-1)(c_DataWidth-1 downto 0);
	signal firstNetworkDataOut				: t_variableSizeLogicVectorArray(0 to c_networkfirstModelLayerInformation(c_networkfirstModelLayerInformation'length-1).neuronCount-1)(c_DataWidth-1 downto 0);

    signal secondNetworkDataIn 				: t_variableSizeLogicVectorArray(0 to (c_networksecondModelLayerInformation(0).inputCount-1))(c_DataWidth-1 downto 0) := (others => (others => '0'));
	signal secondNetworkDataOut				: t_variableSizeLogicVectorArray(0 to c_networksecondModelLayerInformation(c_networksecondModelLayerInformation'length-1).neuronCount-1)(c_DataWidth-1 downto 0);

    signal detectedClass                   : integer   := 0; 

    signal rgb_out  						: std_logic_vector(23 downto 0);
begin                     
    secondNetwork : entity design_lib.NNFPGA_neuralNetwork
        generic map(dataWidth 			=> c_DataWidth,
                    fixedPointPos		=> c_FixedPointPos,
                    networkInformation  => c_networksecondModelLayerInformation,
                    weights 			=> c_networksecondModelWeights)


        port map(   clk        	=> clk,
                    rst			=> rst,
    
                    dataIn	    => secondNetworkDataIn,
                    dataOut	    => secondNetworkDataOut); 

    maxPos : entity design_lib.NNFPGA_maxPosition 
        generic map(inputCount 	  => secondNetworkDataOut'length,
                    dataWidth		      => c_DataWidth,
                    pipelineDistance 	  => 5)
     port map(  clk       => clk,										

                dataIn		=> secondNetworkDataOut,
                dataOut 	=> detectedClass);

    encoder : entity design_lib.NNFPGA_Encoding2RGB 
    port map(clk       => clk,											
        
            dataIn		=> detectedClass,
            rgbOut 		=> rgb_out);

                        

     --create the process for VUnit
     test_runner : process                

        file stimuliFile        : text;
        variable l         		: line;
        variable stimuliStatus  : file_open_status;

        variable secondLayerSimIn : t_variableSizeLogicVectorArray(0 to (c_networksecondModelLayerInformation(0).inputCount-1))(c_DataWidth-1 downto 0) := (others => (others => '0'));

        variable i, tempInt    : integer;          
    begin
        -- setup VUnit
        test_runner_setup(runner, runner_cfg);
        
        -- loop through all the tests
        while test_suite loop
            ----------------Test 1----------------
            if run("SecondNetworkTest") then
                info("=================================");
                info("TEST CASE: Read a file and run it through the second network");
                info("=================================");
               

                file_open(stimuliStatus, stimuliFile, stimuliFilename, read_mode);
                readline(stimuliFile, l);          -- read line 1 with comment
                readline(stimuliFile, l);          -- read line 2 with x, y size
                
                read(l, i); 
                xSize <= i;
                read(l, i); 
                ySize <= i;

                --wait until the rst is low 
                wait until rst = '0';
                
                while not endfile(stimuliFile) loop
                    --read the pixel data for each line
                    readline(stimuliFile, l);

                    for i in 0 to 63-1 loop
                        read(l, tempInt);
                        secondLayerSimIn(i) := std_logic_vector(to_signed(tempInt,c_DataWidth));
                    end loop;

                    --only run it once per clock cycle 
                    wait until rising_edge(clk);

                    secondNetworkDataIn <= secondLayerSimIn;
                end loop;

                rBuffer <= (others => '0');
                gBuffer <= (others => '0');
                bBuffer <= (others => '0');
            end if;
        end loop;

        --make sure we clean everything up so we can exit without creating false fails
        test_runner_cleanup(runner);

    end process test_runner;


    outputWriterRGB : process
        file outputFile     : text;
        variable l          : line;
        variable outStatus  : file_open_status;

        variable r,g,b,count: integer := 0; 
    begin
        file_open(outStatus, outputFile, outputFilenameRGB, write_mode);

        wait until startSaveRGB; 

        write (l, string'("RGB Image as HEX Values"));       
        writeline(outputFile, l);

        write(l, xSize);
        write(l, string'(" "));
        write(l, ySize);
        writeLine(outputFile, l);

        Loop1 : loop
            wait until rising_edge(clk);

            r := to_integer(unsigned(rgb_out(23 downto 16)));
            g := to_integer(unsigned(rgb_out(15 downto 8)));
            b := to_integer(unsigned(rgb_out(7 downto 0)));

            write(l, r);
            write(l, string'(" "));
            write(l, g);
            write(l, string'(" "));
            write(l, b);
            writeLine(outputFile, l);

            count := count + 1;

            if count = xSize * ySize-1 then
                assert false severity failure;
            end if;
        end loop; 
    end process outputWriterRGB;


    outputWriterRaw : process
        file outputFile     : text;
        variable l          : line;
        variable outStatus  : file_open_status;

        variable intOut : integer := 0;
        variable i : integer;
        variable count : integer := 0;
    begin
        file_open(outStatus, outputFile, outputFilenameRaw, write_mode);

        wait until startSaveRaw; 

        write (l, string'("Network Output as HEX Values"));       
        writeline(outputFile, l);

        write(l, xSize);
        write(l, string'(" "));
        write(l, ySize);
        writeLine(outputFile, l);

        Loop1 : loop
            wait until rising_edge(clk);

            for i in secondNetworkDataOut'range loop 
                intOut := to_integer(signed(secondNetworkDataOut(i)));
                write(l, intOut);
                write(l, string'(" "));
            end loop;

            writeLine(outputFile, l);

            count := count + 1;

            if count = xSize * ySize-1 then
                exit;
            end if;
        end loop; 
    end process outputWriterRaw;


    --watchdog in case the simulation stalls without failing. 100 ms is more than long enough to finish all the tests in this situation 
    test_runner_watchdog(runner, 100 ms);

    --signal generation for the testbench
    clk         <= NOT clk after c_clkPeriod / 2;
    rst         <= '0' after 5 * (c_clkPeriod / 2);
    en          <= '1' after 5 * (c_clkPeriod / 2);

    -- that is the delay for the first signal to propage through the entire network 
    startSaveRGB   <= '1' after 53 * c_clkPeriod;
    startSaveRaw   <= '1' after 50 * c_clkPeriod;

end architecture tb;