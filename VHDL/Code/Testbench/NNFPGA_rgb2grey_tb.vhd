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
entity NNFPGA_rgb2grey_tb IS
    generic(generics    : string;
            runner_cfg  : string := runner_cfg_default);
end entity NNFPGA_rgb2grey_tb;

architecture tb of NNFPGA_rgb2grey_tb is
    type tb_cfg_t is record
        inputDataWidth      : positive;
        outputDataWidth     : positive;
    end record tb_cfg_t;

    --decode the generic from the string as we need to pass them as a string
    impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
    begin
        return (inputDataWidth  => positive'value(get(encoded_tb_cfg, "inputDataWidth")),
                outputDataWidth => positive'value(get(encoded_tb_cfg, "outputDataWidth")));
    end function decode;

    --define constants 
    constant C_CLK_PERIOD       : time := 10 ns;  
    constant tb_cfg : tb_cfg_t := decode(generics);

    --signals for the DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';

    signal rIn      : std_logic_vector(tb_cfg.inputDataWidth-1 downto 0) := (others => '0');
    signal gIn      : std_logic_vector(tb_cfg.inputDataWidth-1 downto 0) := (others => '0');
    signal bIn      : std_logic_vector(tb_cfg.inputDataWidth-1 downto 0) := (others => '0');

    signal dataOut  : std_logic_vector(tb_cfg.outputDataWidth-1 downto 0) := (others => '0');

begin
    --DUT Instancs 
    NNFPGA_rgb2grey_tb_inst : ENTITY design_lib.NNFPGA_rgb2grey(behave)
    generic map(inputDataSize   => tb_cfg.inputDataWidth,
                outputDataSize  => tb_cfg.outputDataWidth) 
    port map(
        clk        	=> clk,
        rst			=> rst,

        rIn			=> rIn,
        gIn			=> gIn,
        bIn			=> bIn,

        dataOut		=> dataOut);

    --create the process for VUnit
    test_runner : process
        -- declare an impure function to check the result from the simulation
        -- an impure fuction can access objects outside the local scope. With a pure function we would have to pass in all the variables.
        impure function calculateExpectedResult return std_logic_vector is
            variable additionResult : integer;
        begin
            --addition done via division. 
            additionResult :=   to_integer(unsigned(rIn)) / 4 + 
                                to_integer(unsigned(gIn)) / 2 + 
                                to_integer(unsigned(gIn)) / 8 +
                                to_integer(unsigned(gIn)) / 16 +
                                to_integer(unsigned(bIn)) / 16;

            --test if we need to shift the value up or down
            if (tb_cfg.outputDataWidth > tb_cfg.inputDataWidth) then
                --shift it up
                return std_logic_vector(shift_left(to_unsigned(additionResult,tb_cfg.outputDataWidth),tb_cfg.outputDataWidth-tb_cfg.inputDataWidth));
            else
                --shift it down. The resize is needed as inputdatawidth is greater than outputdatawidth. If we change the vector size during the conversion from int to unsigned
                --we would cut off bits.
                return std_logic_vector(resize(shift_right(to_unsigned(additionResult,tb_cfg.inputDataWidth),tb_cfg.inputDataWidth-tb_cfg.outputDataWidth),tb_cfg.outputDataWidth));
            end if;
        end;

    begin
        -- setup VUnit
        test_runner_setup(runner, runner_cfg);
        
        -- loop through all the tests
        while test_suite loop
            ----------------Test 1----------------
            --Testing the output for an all zero input
            --r, g, b => 0
            if run("all_zero_test") then
                info("=================================");
                info("TEST CASE: all 0 input check");
                info("=================================");
                info("Input Datawidth is: "&integer'image(tb_cfg.inputDataWidth));
                info("Output Datawidth is: "&integer'image(tb_cfg.outputDataWidth));                
                --set the in and output to the desired value
                rIn <= (others => '0');
                gIn <= (others => '0');
                bIn <= (others => '0');

                --wait until the reset is low 
                wait until rst = '0';
                --wait until a rising clock edge
                wait until rising_edge(clk);
                --check the output
                check_equal(dataOut, 0, "Checking expected Data Output with refference");
            elsif run("all_one_test") then
            ----------------Test 2----------------
            --Testing the output for an all 1 input
            --r, g, b => (others => 1)                
                info("=================================");
                info("TEST CASE: all 1 input check");
                info("================================="); 
                info("Input Datawidth is: "&integer'image(tb_cfg.inputDataWidth));
                info("Output Datawidth is: "&integer'image(tb_cfg.outputDataWidth));
                
                --setting all inputs to 1
                rIn <= (others => '1');
                gIn <= (others => '1');
                bIn <= (others => '1');

                --wait until both rst is low and a rising edge
                wait until rst = '0';
                wait until rising_edge(clk);                

                check_equal(dataOut, calculateExpectedResult, "Checking expected Data Output with refference");
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