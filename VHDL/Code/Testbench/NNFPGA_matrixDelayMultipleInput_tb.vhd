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
entity NNFPGA_matrixDelayMultipleInput_tb IS
    generic(generics    : string;
            runner_cfg  : string := runner_cfg_default);
end entity NNFPGA_matrixDelayMultipleInput_tb;

architecture tb of NNFPGA_matrixDelayMultipleInput_tb is
    type t_tbCFG is record
                n				: positive;  
                dataWidth 	    : positive;  
                newLineLength	: positive;
    end record t_tbCFG;

    --decode the generic from the string as we need to pass them as a string
    impure function decode(encoded_tb_cfg : string) return t_tbCFG is
    begin
        return (n               => positive'value(get(encoded_tb_cfg, "n")),
                dataWidth       => positive'value(get(encoded_tb_cfg, "dataWidth")),
                newLineLength   => positive'value(get(encoded_tb_cfg, "newLineLength")));
    end function decode;

    --define constants 
    constant c_clkPeriod        : time := 10 ns;  
    --decode the config data 
    constant tbCfg : t_tbCFG    := decode(generics);

    --signals for the DUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal wrEn     : std_logic := '0';

    signal dataIn   : t_variableSizeLogicVectorArray(0 to 7)(tbCfg.dataWidth -1 downto 0) := (others => (others => '0'));

    signal dataOut  : t_variableSizeLogicVectorArray(0 to 8*tbCfg.n*tbCfg.n-1) (tbCfg.dataWidth-1 downto 0) := (others => (others => '0'));

begin
    --DUT Instancs 
    NNFPGA_matrixDelayMultipleInput_inst : ENTITY design_lib.NNFPGA_matrixDelayMultipleInput(behave)
    generic map(n				=> tbCfg.n,
                inputCount      => 8,
                dataWidth 	    => tbCfg.dataWidth,
                newLineLength	=> tbCfg.newLineLength) 
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

        impure function arrangeVslvArray(len : integer; start : integer; dataWidth : integer) return t_variableSizeLogicVectorArray is 
            variable VslvArray : t_variableSizeLogicVectorArray(0 to len-1)(dataWidth-1 downto 0); 
        begin
            for i in 0 to len-1 loop
                VslvArray(i) := std_logic_vector(to_signed(i+start,dataWidth));
            end loop;

            return VslvArray;
        end function;

        --variable for a random test sequence, Fill with random values
        variable testSequence       : t_variableSizeLogicVectorArray(0 to 7)(tbCfg.dataWidth -1 downto 0) := (others => (others => '0'));
        variable fullTestSequence   : t_variableSizeLogicVectorArray(0 to (8*tbCfg.n*tbCfg.newLineLength)-1)(tbCfg.dataWidth -1 downto 0) := (others => (others => '0'));  
        variable i,j,k              : integer := 0;

        variable sequPos, outPos    : integer := 0;
    begin
        -- setup VUnit
        test_runner_setup(runner, runner_cfg);
        
        -- loop through all the tests
        while test_suite loop
            ----------------Test 1----------------
            --Testing the output for the first n inputs 
            if run("arrangeLineTest") then
                info("=================================");
                info("TEST CASE: line Test with arrange");
                info("=================================");

                --wait until the module is actually accepting data
                wait until rst = '0';
                --write the first row of values from the random array into the DUT
                for i in 0 to tbCfg.n -1 loop
                    testSequence := arrangeVslvArray(8,i*8,tbCfg.dataWidth);
                    wait until rising_edge(clk);
                    dataIn <= testSequence;

                end loop;
                --wait 3 more clk cycle for the signal to be put on the output. 2 clock cycle extra as we have an input and output register 
                for i in 0 to 2 loop
                    wait until rising_edge(clk);
                end loop;
                --compare each output with the expected value
                for i in 0 to tbCfg.n-1 loop
                    testSequence := arrangeVslvArray(8,i*8,tbCfg.dataWidth);
                    info("run "&to_string(i));
                    for j in testSequence'range loop
                        info(to_string(j)&": "&to_string(8*(tbCfg.n-1)*tbCfg.n+i*testSequence'length+j) & ": " & to_string(dataOut(8*(tbCfg.n-1)*tbCfg.n+i*testSequence'length+j)) & "/" & to_string(testSequence(j)));
                        --test if the output is correct. Last value in DataOut should be the nth value in testSequence. The first in TestSequence should be the nth in dataOut
                        check_equal(dataOut(8*(tbCfg.n-1)*tbCfg.n+i*testSequence'length+j), testSequence(j), "Checking expected Data Output ");
                    end loop;
                end loop;      

            elsif run("fullRandomTest") then
                info("=================================");
                info("TEST CASE: fill with entire random vectors");
                info("=================================");

                fullTestSequence := rand_slvArray(8*tbCfg.n*tbCfg.newLineLength, tbCfg.dataWidth);

                --wait until the module is actually accepting data
                wait until rst = '0';

                --write the first row of values from the random array into the DUT
                for i in 0 to (fullTestSequence'length / 8)-1-12 loop
                    wait until rising_edge(clk);
                    dataIn <= fullTestSequence(i*8 to (i+1)*8-1);

                end loop;
                --wait 3 more clk cycle for the signal to be put on the output. 2 clock cycle extra as we have an input and output register 
                for i in 0 to 2 loop
                    wait until rising_edge(clk);
                end loop;
                --compare each output with the expected value 

                for i in 0 to tbCfg.n -1 loop
                    for j in 0 to tbCfg.n -1 loop
                        for k in 0 to 8 -1 loop
                            --test if the output is correct. 
                            sequPos := (i+1) * 8 * tbCfg.newLineLength + j*tbCfg.n + k - tbCfg.n*8;
                            outPos  := i * 8 * tbCfg.n + j*tbCfg.n + k;

                            check_equal(dataOut(outPos), fullTestSequence(sequPos), "Checking expected Data Output ");
                        end loop;
                    end loop;
                end loop;

                info("Sequence");
                for i in 0 to tbCfg.n -1 loop
                    for j in 0 to tbCfg.newLineLength -1 loop
                        outPos  := i * 8 * tbCfg.newLineLength + j*8;
                        info(to_string(fullTestSequence(outPos)));
                    end loop;
                end loop;

                info("output");
                for i in 0 to tbCfg.n -1 loop
                    for j in 0 to tbCfg.n -1 loop
                        outPos  := i * 8 * tbCfg.n + j*8;
                        info(to_string(dataOut(outPos)));
                    end loop;
                end loop;

                assert false severity failure;        
            end if;
        end loop;

        --make sure we clean everything up so we can exit without creating false fails
        test_runner_cleanup(runner);

    end process test_runner;

    --watchdog in case the simulation stalls without failing. 10 ms is more than long enough to finish all the tests in this situation 
    test_runner_watchdog(runner, 10 ms);

    --signal generation for the testbench
    clk     <= NOT clk after c_clkPeriod / 2;
    rst     <= '0' after 5 * (c_clkPeriod / 2);
    wrEn    <= '1' after 5 * (c_clkPeriod / 2);

end architecture tb;