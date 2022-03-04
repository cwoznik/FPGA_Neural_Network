-- NNFPGA_stdLogicDelay
--
-- delays a single std_logic signal for an given length. Minimum delay = 2 
--
-- (c) Christian Woznik

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity NNFPGA_stdLogicDelay is
  generic (delay : integer);
  port (clk     : in  std_logic;
        reset   : in  std_logic;
        dataIn  : in  std_logic;
        dataOut : out std_logic);
end NNFPGA_stdLogicDelay;

architecture behave of NNFPGA_stdLogicDelay is


  type delayArray is array (1 to delay) of std_logic;
  signal dataDelay : delayArray;

begin

  process
  begin
    wait until rising_edge(clk);

     -- first value of array is current input
     dataDelay(1) <= dataIn;

    -- delay according to generic
    for i in 2 to delay loop
      dataDelay(i) <= dataDelay(i-1);
    end loop;

  end process;

  -- last value of array is output
  dataOut <= dataDelay(delay);

end behave;
