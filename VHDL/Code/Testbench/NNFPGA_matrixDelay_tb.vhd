--IEEE Lib for logic and numeric signals
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.math_real.all;

library design_lib;
use design_lib.NNFPGA_pkg.all;

--vunit test lib
LIBRARY VUNIT_LIB;
CONTEXT VUNIT_LIB.VUNIT_CONTEXT;

--entity declaration. Runner is used by VUNIT
entity NNFPGA_matrixDelay_tb IS
    generic(generics    : string;
            runner_cfg  : string := runner_cfg_default);
end entity NNFPGA_matrixDelay_tb;

architecture tb of NNFPGA_matrixDelay_tb is
    type t_tb_cfg is record
                n				: positive;  
                dataWidth 	    : positive;  
                newLineLength	: positive;
    end record t_tb_cfg;

    --decode the generic from the string as we need to pass them as a string
    impure function decode(encoded_tb_cfg : string) return t_tb_cfg is
    begin
        return (n               => positive'value(get(encoded_tb_cfg, "n")),
                dataWidth       => positive'value(get(encoded_tb_cfg, "dataWidth")),
                newLineLength   => positive'value(get(encoded_tb_cfg, "newLineLength")));
    end function decode;

    --define constants 
    constant C_CLK_PERIOD       : time := 10 ns;  
    --decode the config data 
    constant tb_cfg : t_tb_cfg := decode(generics);

    --signals for the DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal wrEn     : std_logic := '0';

    signal dataIn   : std_logic_vector(tb_cfg.dataWidth -1 downto 0) := (others => '0');

    signal dataOut  : t_variableSizeLogicVectorArray(0 to tb_cfg.n*tb_cfg.n-1) (tb_cfg.dataWidth-1 downto 0) := (others => (others => '0'));

begin
    --DUT Instancs 
    NNFPGA_matrixDelay_tb_inst : ENTITY design_lib.NNFPGA_matrixDelay(behave)
    generic map(n				=> tb_cfg.n,
                dataWidth 	    => tb_cfg.dataWidth,
                newLineLength	=> tb_cfg.newLineLength) 
    port map(
        clk        	=> clk,
        rst			=> rst,
        wrEn        => wrEn,

        dataIn      => dataIn,

        dataOut		=> dataOut);

    --create the process for VUnit
    test_runner : process
        --seeds for the rng 
        variable seed1, seed2 : integer := 999;
        --impure function to create an random t_variableSizeLogicVectorArray
        impure function rand_slvArray(len : integer; dataWidth : integer) return t_variableSizeLogicVectorArray is
            variable r : real;
            variable slvArray : t_variableSizeLogicVectorArray(0 to len - 1)(dataWidth-1 downto 0);
            variable slv : std_logic_vector(dataWidth-1 downto 0);
        begin
            --loop through all the elements of the vector 
            for i in slvArray'range loop
                --loop through each bit in the std_logic_vecot 
                for j in slv'range loop 
                    --get a random float 
                    uniform(seed1, seed2, r);
                    --shorthand if 0
                    slv(j) := '1' when r > 0.5 else '0';
                end loop;
                --write the random value to the array
                slvArray(i) := slv;
                --reset the value for the vetor
                slv := (others => '0');
            end loop;
            return slvArray;
        end function;

        --variable for a random test sequence, Fill with random values
        variable testSequence : t_variableSizeLogicVectorArray(0 to tb_cfg.n*tb_cfg.newLineLength-1)(tb_cfg.dataWidth -1 downto 0) := rand_slvArray(tb_cfg.n*tb_cfg.newLineLength,tb_cfg.dataWidth);

    begin
        -- setup VUnit
        test_runner_setup(runner, runner_cfg);
        
        -- loop through all the tests
        while test_suite loop
            ----------------Test 1----------------
            --Testing the output for the first n inputs 
            if run("oneLineTest") then
                info("=================================");
                info("TEST CASE: random "&integer'image(tb_cfg.n)&" value sequence");
                info("=================================");

                --wait until the module is actually accepting data
                wait until rst = '0';
                --write the first row of values from the random array into the DUT
                for i in 0 to tb_cfg.n -1 loop
                    wait until rising_edge(clk);
                    dataIn <= testSequence(i);
                end loop;
                --wait 3 more clk cycle for the signal to be put on the output. 2 clock cycle extra as we have an input and output register 
                for i in 0 to 2 loop
                    wait until rising_edge(clk);
                end loop;
                --compare each output with the expected value

                for i in 0 to tb_cfg.n -1 loop
                    --test if the output is correct. Last value in DataOut should be the nth value in testSequence. The first in TestSequence should be the nth in dataOut
                    check_equal(dataOut((tb_cfg.n-1)*tb_cfg.n+i), testSequence(i), "Checking expected Data Output ");
                end loop;


            ----------------Test ----------------
            --Testing the output for all inputs
            elsif run("fullTest") then
                info("=================================");
                info("TEST CASE: full random "&integer'image(tb_cfg.n)&" x "&integer'image(tb_cfg.n)&" test");
                info("=================================");

                --wait until the module is actually accepting data
                wait until rst = '0';
                --write the full test sequence to the input
                for i in 0 to tb_cfg.n*tb_cfg.newLineLength -1 loop
                    wait until rising_edge(clk);
                    dataIn <= testSequence(i);
                end loop;
                --wait 3 more clk cycle for the signal to be put on the output. 2 clock cycle extra as we have an input and output register 
                for i in 0 to 2 loop
                    wait until rising_edge(clk);
                end loop;

                --compare each output with the expected value
                for i in 0 to tb_cfg.n -1 loop
                    for j in 0 to tb_cfg.n -1 loop
                        --test if the output is correct. 
                        check_equal(dataOut((tb_cfg.n*i)+j), testSequence((tb_cfg.newLineLength*(i+1))-tb_cfg.n+j), "Checking expected Data Output ");
                    end loop;
                end loop;                  
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
    wrEn    <= '1' after 5 * (C_CLK_PERIOD / 2);

end architecture tb;