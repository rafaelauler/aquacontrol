library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity relogio is
  port(
    reset      : in std_logic;
    enable     : in std_logic;
    clk24M     : in std_logic;
    adjust_min : in std_logic;
    adjust_hor : in std_logic;
    segundos, minutos : buffer integer range 0 to 59;
    horas : buffer integer range 0 to 23;
    hora_1, hora_2, minuto_1, minuto_2 : out std_logic_vector(3 downto 0);
    clk1HZ_out : out std_logic;
    enable1min_out : out std_logic
    );
end entity;

architecture rtl of relogio is
  signal enable_minuto, enable_hora : std_logic;
  signal clk1HZ : std_logic;
begin
  clk1HZ_out <= clk1HZ;
  enable1min_out <= enable_minuto;
  
  mainclkdiv: entity work.clk_div
    generic map (
      MIN_COUNT => 0,
      MAX_COUNT => 11999999)
    port map (
      reset   => reset,
      clk     => clk24M,
      clk_out => clk1HZ);
		
  hora_1 <= std_logic_vector(to_unsigned(horas / 10, hora_1'length));
  hora_2 <= std_logic_vector(to_unsigned(horas mod 10, hora_2'length));
  minuto_1 <= std_logic_vector(to_unsigned(minutos / 10, minuto_1'length));
  minuto_2 <= std_logic_vector(to_unsigned(minutos mod 10, minuto_2'length));
		
  -- purpose: contador segundos
  -- type   : sequential
  -- inputs : 
  seg_cnt: process (clk1HZ, reset) is
  begin  -- process fsm1
    if reset = '0' then                 -- asynchronous reset (active low)
      segundos <= 0;
      enable_minuto <= '0';
      enable_hora <= '0';
    elsif clk1HZ'event and clk1HZ = '1' then  -- rising clock edge
      if enable = '1' then				
        if (segundos = 58) then
          segundos <= segundos + 1;
          if (minutos = 59) then
            enable_minuto <= '1';
            enable_hora <= '1';
          else
            enable_minuto <= '1';
            enable_hora <= '0';
          end if;
        elsif (segundos = 59) then
          segundos <= 0;
          enable_minuto <= '0';
          enable_hora <= '0';
        else
          segundos <= segundos + 1;
          enable_minuto <= '0';
          enable_hora <= '0';
        end if;
      else
        enable_minuto <= '0';
        enable_hora <= '0';
      end if;
    end if;
  end process seg_cnt;
      
    -- purpose: contador minutos
    -- type   : sequential
    -- inputs : 
    min_cnt: process (clk1HZ, reset) is
    begin  -- process fsm1
      if reset = '0' then                 -- asynchronous reset (active low)
        minutos <= 0;
      elsif clk1HZ'event and clk1HZ = '1' then  -- rising clock edge
        if enable_minuto = '1' or adjust_min = '0' then				
          if (minutos = 59) then
            minutos <= 0;
          else
            minutos <= minutos + 1;
          end if;
        end if;
      end if;
    end process min_cnt;

    -- purpose: contador horas
    -- type   : sequential
    -- inputs : 
    hor_cnt: process (clk1HZ, reset) is
    begin  -- process fsm1
      if reset = '0' then                 -- asynchronous reset (active low)
        horas <= 0;
      elsif clk1HZ'event and clk1HZ = '1' then  -- rising clock edge
        if enable_hora = '1' or adjust_hor = '0' then
          if (horas = 23) then
            horas <= 0;
          else
            horas <= horas + 1;
          end if;
        end if;
      end if;
    end process hor_cnt;
	
end architecture rtl;
