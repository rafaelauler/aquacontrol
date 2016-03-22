library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity clk_div is
	generic	(
          MIN_COUNT : natural := 0;
          MAX_COUNT : natural := 1000);
	port (
          reset      : in std_logic;
          clk	     : in std_logic;
          clk_out    : out std_logic);
end entity;

architecture rtl of clk_div is
signal   cnt : integer range MIN_COUNT to MAX_COUNT;
signal   temporal : std_logic;
begin
  process (clk, reset)		
  begin
    if (reset = '0') then
      cnt <= 0;
      temporal <= '0';
    elsif (rising_edge(clk)) then	
      if (cnt = MAX_COUNT) then
        temporal <= not temporal;
        cnt <= 0;
      else
        cnt <= cnt + 1;
      end if;			
    end if;
  end process;
  clk_out <= temporal;
end rtl;
