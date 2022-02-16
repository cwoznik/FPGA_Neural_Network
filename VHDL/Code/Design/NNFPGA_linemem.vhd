-- NNFPGA_linemem.vhd
--
-- line memory with variable pixel delay
--
-- FPGA Vision Remote Lab http://h-brs.de/fpga-vision-lab
-- (c) Marco Winzker, Hochschule Bonn-Rhein-Sieg, 03.01.2018

-- expanded by Christian Woznik to allow generics and thus more configurability 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity NNFPGA_linemem is
	generic(	dataWidth 		: integer;
				    memoryLength 	: integer);
	port (clk       : in  std_logic;
		    reset     : in  std_logic;
		    write_en  : in  std_logic;
		    data_in   : in  std_logic_vector(dataWidth-1 downto 0);
		    data_out  : out std_logic_vector(dataWidth-1 downto 0));
end NNFPGA_linemem;

architecture behave of NNFPGA_linemem is

  type ram_array is array (0 to memoryLength-2) of std_logic_vector(dataWidth-1 downto 0);
  signal ram : ram_array  := (others => (others => '0'));
  
  signal outputBuffer : std_logic_vector(dataWidth-1 downto 0);

begin

  process
    variable wr_address : integer range 0 to memoryLength-2;
    variable rd_address : integer range 0 to memoryLength-2;
  begin
    wait until rising_edge(clk);

    if (write_en = '1') then
		outputBuffer 		<= ram(rd_address);
      data_out        	<= outputBuffer;
      ram(wr_address) 	<= data_in;
    end if;

    if (reset = '1') then
      wr_address := 0;
      rd_address := 1;
    elsif (write_en = '1') then
      wr_address := rd_address;
      if (rd_address = memoryLength-2) then
        rd_address := 0;
      else
        rd_address := rd_address + 1;
      end if;
    end if;
  end process;

end behave;
