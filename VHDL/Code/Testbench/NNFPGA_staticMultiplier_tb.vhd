--IEEE Lib for logic and numeric signals
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.math_real.all;

library design_lib;

--vunit test lib
LIBRARY VUNIT_LIB;
CONTEXT VUNIT_LIB.VUNIT_CONTEXT;

--entity declaration. Runner is used by VUNIT
entity NNFPGA_staticMultiplier_tb IS
    generic(generics    : string;
            runner_cfg  : string := runner_cfg_default);
end entity NNFPGA_staticMultiplier_tb;

architecture tb of NNFPGA_staticMultiplier_tb is
    type t_tb_cfg is record
        dataSize   				: positive;	
        fixedpointPos			: positive; 
        multiplicationFactor 	: integer;
    end record t_tb_cfg;

    --decode the generic from the string as we need to pass them as a string1
    impure function decode(encoded_tb_cfg : string) return t_tb_cfg is
    begin
        return (dataSize                => positive'value(get(encoded_tb_cfg, "dataSize")),
                fixedpointPos           => positive'value(get(encoded_tb_cfg, "fixedpointPos")),
                multiplicationFactor    => integer'value(get(encoded_tb_cfg, "multiplicationFactor")));
    end function decode;

    --define constants 
    constant C_CLK_PERIOD       : time := 10 ns;  
    constant tb_cfg : t_tb_cfg := decode(generics);

    --signals for the DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';

    signal dataIn   : std_logic_vector(tb_cfg.dataSize -1 downto 0) := (others => '0');

    signal dataOut  : std_logic_vector((2*tb_cfg.dataSize-tb_cfg.fixedpointPos)-1 downto 0) := (others => '0');

begin
    --DUT Instancs 
    NNFPGA_staticMultiplier_tb_inst : ENTITY design_lib.NNFPGA_staticMultiplier(behave)
    generic map(dataSize   				=> tb_cfg.dataSize,
                fixedpointPos			=> tb_cfg.fixedpointPos,
                multiplicationFactor 	=> tb_cfg.multiplicationFactor)
    port map(
        clk        	=> clk,
        rst			=> rst,
		
        dataIn		=> dataIn,

        dataOut		=> dataOut); 

    --create the process for VUnit
    test_runner : process
        variable expectedOutput : std_logic_vector((2*tb_cfg.dataSize-tb_cfg.fixedpointPos)-1 downto 0);
        --function to calculate the expected output
        impure function calcCorrectOutput(dataIn : std_logic_vector) return std_logic_vector is
            variable tempVal : integer;
        begin   
            tempVal := to_integer(signed(dataIn)) * tb_cfg.multiplicationFactor;
            return std_logic_vector(to_signed(tempVal, 2*dataIn'length)(dataOut'length-1+tb_cfg.fixedpointPos downto tb_cfg.fixedpointPos));
        end function;

        variable testInput : std_logic_vector(tb_cfg.dataSize -1 downto 0) := (others => '0');


    begin
        -- setup VUnit
        test_runner_setup(runner, runner_cfg);
        
        -- loop through all the tests
        while test_suite loop
            ----------------Test 1----------------
            if run("InputZero") then
                info("=================================");
                info("TEST CASE: Multiply with Zero");
                info("=================================");
                --set the expected output
                expectedOutput  := (others => '0');
                testInput       := (others => '0');

                --wait until the reset is low 
                wait until rst = '0';
                
                --set the dataIn to all 0
                dataIn <= testInput;

                --wait for two clock cycles as we have an input register 
                wait until rising_edge(clk);
                wait until rising_edge(clk);

                --check if the results match the expected result 
                check_equal(dataOut, expectedOutput, "Checking expected Data Output ");
            
            ----------------Test 2----------------
            elsif run("InputOne") then
                info("=================================");
                info("TEST CASE: Multiply with 1");
                info("=================================");   
                info(to_string(tb_cfg.multiplicationFactor));
                info(to_string(tb_cfg.multiplicationFactor));  
                --set the expected output
                testInput       := std_logic_vector(shift_left(to_signed(1,dataIn'length),tb_cfg.fixedpointPos));
                expectedOutput  := calcCorrectOutput(testInput);  

                --wait until the reset is low 
                wait until rst = '0';

                --set the dataIn to 1. We need to shift it doe to the fixedpoint 
                dataIn <= testInput;

                --wait for two clock cycles as we have an input register 
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                

                --check if the results match the expected result 
                check_equal(dataOut, expectedOutput, "Checking expected Data Output ");

            ----------------Test 3----------------
            elsif run("InputMaxNeg") then
                info("=================================");
                info("TEST CASE: DataIn max negative value");
                info("=================================");   
                --set the expected output
                testInput(testInput'High) := '1';
                expectedOutput := calcCorrectOutput(testInput);           

                --wait until the reset is low 
                wait until rst = '0';

                --set the dataIn to 1. We need to shift it doe to the fixedpoint 
                dataIn <= testInput;

                --wait for two clock cycles as we have an input register 
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                
                info("Multiplication Factor: "&to_string(tb_cfg.multiplicationFactor));
                    info("Input Value: "&to_string(testInput));
                    info("Expected Output: "&to_string(expectedOutput));
                    info("DUT Output: "&to_string(dataOut));

                --check if the results match the expected result 
                check_equal(dataOut, expectedOutput, "Checking expected Data Output ");   
                
                elsif run("InputMaxPos") then
                    info("=================================");
                    info("TEST CASE: DataIn max positive value");
                    info("=================================");   
                    --set the expected output
                    testInput :=  (testInput'high => '0', others => '1');
                    expectedOutput := calcCorrectOutput(testInput);           

                    --wait until the reset is low 
                    wait until rst = '0';

                    --set the dataIn to 1. We need to shift it doe to the fixedpoint 
                    dataIn <= testInput;
    
                    --wait for two clock cycles as we have an input register 
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    
                    info("Multiplication Factor: "&to_string(tb_cfg.multiplicationFactor));
                    info("Input Value: "&to_string(testInput));
                    info("Expected Output: "&to_string(expectedOutput));
                    info("DUT Output: "&to_string(dataOut));
    
                    --check if the results match the expected result 
                    check_equal(dataOut, expectedOutput, "Checking expected Data Output ");                   
            end if;
        end loop;

        --make sure we clean everything up so we can exit without creating false fails
        test_runner_cleanup(runner);

    end process test_runner;

    --watchdog in case the simulation stalls without failing. 10 ms is more than long enough to finish all the tests in this situation 
    test_runner_watchdog(runner, 10 ms);

    --signal generation for the testbench
    clk     <= NOT clk after C_CLK_PERIOD / 2;
    rst     <= '0' after 5 * (C_CLK_PERIOD / 2);

end architecture tb;