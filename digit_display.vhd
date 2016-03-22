library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

entity digit_display is
	port (
          mode       : in integer range 0 to 1;
          force_mode_1, force_mode_0 : in std_logic;
          wallclk0, wallclk1, wallclk2, wallclk3,
          temp0, temp1, temp2 : in std_logic_vector(3 downto 0);
          cur_mode : out std_logic;
          SEG0, SEG1, SEG2, SEG3  : out std_logic_vector(6 downto 0));
end entity;

architecture rtl of digit_display is
  signal P0, P1, P2, P3 : std_logic_vector(6 downto 0);
  signal inP0, inP1, inP2, inP3 : std_logic_vector(3 downto 0);
begin
  -- Instances of converters from binary to 7seg displays
  conv7seg_0: entity work.conv7seg
    port map (
      input  => inP0,
      output => P0);
  conv7seg_1: entity work.conv7seg
    port map (
      input  => inP1,
      output => P1);
  conv7seg_2: entity work.conv7seg
    port map (
      input  => inP2,
      output => P2);
  conv7seg_3: entity work.conv7seg
    port map (
      input  => inP3,
      output => P3);
  
  -- purpose: Determine the output for the array of 7seg displays
  -- type   : combinational
  -- inputs : mode, wallclk0, wallclk1, wallclk2, wallclk3, temp0, temp1
  -- outputs: SEG0, SEG1, SEG2, SEG3
  outputlogic: process (mode, wallclk0, wallclk1, wallclk2, wallclk3, temp0, temp1, temp2,
                        force_mode_0, force_mode_1, P0, P1, P2, P3) is
  begin  -- process outputlogic
    if (force_mode_0 = '1') then
      inP0 <= wallclk0;
      inP1 <= wallclk1;
      inP2 <= wallclk2;
      inP3 <= wallclk3;
      SEG0 <= P0;
      SEG1 <= P1;
      SEG2 <= P2;
      SEG3 <= P3;
      cur_mode <= '0';
    elsif (force_mode_1 = '1') then
      inP0 <= "0000";
      inP1 <= temp0;
      inP2 <= temp1;
      inP3 <= temp2;
      SEG0 <= not "0111001";  -- draw a "C"
      SEG1 <= P1;
      SEG2 <= P2;
      SEG3 <= P3;
      cur_mode <= '1';
    else
      if (mode = 0) then
        inP0 <= wallclk0;
        inP1 <= wallclk1;
        inP2 <= wallclk2;
        inP3 <= wallclk3;
        SEG0 <= P0;
        SEG1 <= P1;
        SEG2 <= P2;
        SEG3 <= P3;
        cur_mode <= '0';
      else
        inP0 <= "0000";
        inP1 <= temp0;
        inP2 <= temp1;
        inP3 <= temp2;
        SEG0 <= not "0111001";  -- draw a "C"
        SEG1 <= P1; --not "1100011";  -- draw a "o"
        SEG2 <= P2;
        SEG3 <= P3;
        cur_mode <= '1';
      end if;
    end if;
  end process outputlogic;
end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity conv7seg is
  port (input: in std_logic_vector(0 to 3);
        output: out std_logic_vector(0 to 6));
end;

architecture rtl of conv7seg is
begin
  main: process (input) is
    variable temp: std_logic_vector(0 to 6);
  begin
    case input is
      when "0000" => temp := "1111110";
      when "0001" => temp := "0110000";
      when "0010" => temp := "1101101";
      when "0011" => temp := "1111001";
      when "0100" => temp := "0110011";
      when "0101" => temp := "1011011";
      when "0110" => temp := "1011111";
      when "0111" => temp := "1110000";
      when "1000" => temp := "1111111";
      when "1001" => temp := "1110011";
      when "1010" => temp := "1110111";
      when "1011" => temp := "0011111";
      when "1100" => temp := "1001110";
      when "1101" => temp := "0111101";
      when "1110" => temp := "1001111";
      when "1111" => temp := "1000111";
      when others => temp := "0000000";
    end case;
    output <= not temp(6) & not temp(5) & not temp(4) & not temp(3)
              & not temp (2) & not temp(1) & not temp(0);
  end process main;
end;
