library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity clk_div_custom is
	port (
          reset      : in std_logic;
          clk		  : in std_logic;
          max_count  : in integer range 0 to 21600;
          force_lights_on : in std_logic;
          clk_out	  : out std_logic);
end entity;

architecture rtl of clk_div_custom is
signal   cnt      : integer range 0 to 21600;
signal   temporal : std_logic;
signal   max_count_sync : integer range 0 to 21600;
begin
  -- purpose: Synchronize the input max_count
  -- type   : sequential
  -- inputs : clk, reset, max_count
  -- outputs: max_count_sync
  syncmaxcnt: process (clk, reset) is
  begin  -- process syncmaxcnt
    if reset = '0' then                 -- asynchronous reset (active low)
      max_count_sync <= 0;
    elsif clk'event and clk = '1' then  -- rising clock edge
      if (force_lights_on = '1') then
        max_count_sync <= 1800;
      else
        max_count_sync <= max_count;
      end if;
    end if;
  end process syncmaxcnt;
  
  process (clk, reset)		
  begin
    if (reset = '0') then
      cnt <= 0;
      temporal <= '0';
    elsif (rising_edge(clk)) then	
      if (cnt = 21600) then
        temporal <= '1';
        cnt <= 0;
      elsif (cnt >= max_count_sync) then
        temporal <= '0';
        cnt <= cnt + 1;
      else
        temporal <= '1';
        cnt <= cnt + 1;
      end if;			
    end if;
  end process;
  clk_out <= temporal;
end rtl;
