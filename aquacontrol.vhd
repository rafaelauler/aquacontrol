library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;
use work.all;

entity aquacontrol is
  
  port (
    clk24M                 : in  std_logic;                      -- clock
    reset                  : in  std_logic;
    force_mode_0           : in  std_logic;
    force_mode_1           : in  std_logic;
    force_lights_on        : in  std_logic;
    low_light_mode         : in  std_logic;
    cold_mode              : in  std_logic;
    adc_clk_out            : out std_logic;
    adc_n_cs                 : out std_logic;
    adc_n_rd                 : out std_logic;
    adc_n_wr                 : out std_logic;
    adc_n_intr            : in  std_logic;
    adc_result            : in std_logic_vector (7 downto 0);
    adjust_hor, adjust_min : in std_logic;
    pwm_led                : out std_logic;
    fan_out                : out std_logic;
    LEDG                   : out std_logic_vector (7 downto 0);  -- led array green
    LEDR                   : out std_logic_vector (9 downto 0);  -- led array red
    SEG0, SEG1, SEG2, SEG3 : out std_logic_vector(6 downto 0));  -- 7seg disp

end entity aquacontrol;

architecture rtl of aquacontrol is
  component conv_7seg is
    port (x: in std_logic_vector(3 downto 0);
          y: out std_logic_vector(6 downto 0));
  end component conv_7seg;
    
  signal P0, P1, P2, P3: std_logic_vector(3 downto 0);
  signal P_enable : std_logic;
  signal hora_1, hora_2, minuto_1, minuto_2 : std_logic_vector(3 downto 0);
  signal segundos, minutos : integer range 0 to 59;
  signal horas : integer range 0 to 23;
  signal adc0, adc1, adc2 : std_logic_vector(3 downto 0);
  signal adc_sync, adc_sync2 : integer range 0 to 255;
  signal display_counter : integer range 0 to 120000000;
  signal cur_display_state : integer range 0 to 1;
  signal max_count_in, max_count : integer range 0 to 24000;
  signal total_time : integer range -86400 to 86400;
  signal clk1HZ, adc_clk, enable1min : std_logic;
  signal show_mode, fan : std_logic;
  signal temp9s, temp8s, temp7s, temp6s, temp5s, temp4s : integer range 0 to 255;
  signal temp3s, temp2s, temp1s, tempnow, temp_avg  : integer range 0 to 255;
  

  type state_type is (start_state,
                      begin_conversion_state,
                      begin_conversion_state2,
                      wait_state,
                      read_state,
                      wait_state2,
                      finish_state);
  signal current_state, next_state: state_type;

begin  -- architecture rtl

  adc_clk_out <= adc_clk;
  fan_out <= fan;

  disp1: entity work.digit_display
    port map (
      mode => cur_display_state,
      force_mode_1 => force_mode_1,
      force_mode_0 => force_mode_0,
      wallclk0 => minuto_2,
      wallclk1 => minuto_1,
      wallclk2 => hora_2,
      wallclk3 => hora_1,
      temp0 => adc0,
      temp1 => adc1,
      temp2 => adc2,
      cur_mode => show_mode,
      SEG0 => SEG0,
      SEG1 => SEG1,
      SEG2 => SEG2,
      SEG3 => SEG3);
  
  rel: entity work.relogio port map(reset, '1', clk24M, adjust_min,
                                    adjust_hor, segundos, minutos, horas,
                                    hora_1, hora_2, minuto_1, minuto_2,
                                    clk1HZ, enable1min);

  LEDG <= "000000" & not fan & not reset;
  LEDR <= "00000000" & show_mode & not show_mode;
  
  pwm_gen : entity work.clk_div_custom port map (reset,clk24M,
                                                 max_count, force_lights_on, pwm_led);
  
  adcclkdiv: entity work.clk_div
    generic map (
      MIN_COUNT => 0,
      MAX_COUNT => 700)
    port map (
      reset   => reset,
      clk     => clk24M,
      clk_out => adc_clk);
		
  -- purpose: Calculates the LED duty cycle
  -- type   : combinational
  -- inputs : total_time, low_light_mode
  -- outputs: max_count_in
  -- obs: 21600 -> 6:00 AM
  total_time <= (segundos + minutos * 60 + horas * 3600) - 21600;
  process (total_time, low_light_mode)
  begin
    if (low_light_mode = '1') then
      if (total_time >= 0 and total_time <= 21600) then -- between 6AM and 12PM
        max_count_in <= total_time / 16;
      elsif (total_time > 21600 and total_time <= 43200) then -- 12PM and 6PM
        max_count_in <= (43200 - total_time) / 16;
      else
        max_count_in <= 0;
      end if;
    else
      if (total_time >= 0 and total_time <= 21600) then -- between 6AM and 12PM
        max_count_in <= total_time;
      elsif (total_time > 21600 and total_time <= 43200) then -- 12PM and 6PM
        max_count_in <= 43200 - total_time;
      else
        max_count_in <= 0;
      end if;      
    end if;    
  end process;

  -- purpose: Synchronizes the result of the LED duty cycle
  -- type   : sequential
  -- inputs : clk1HZ, reset, max_count_in
  -- outputs: max_count
  maxcnt: process (clk1HZ, reset) is
  begin  -- process maxcnt
    if reset = '0' then                 -- asynchronous reset (active low)
      max_count <= 0;
    elsif clk1HZ'event and clk1HZ = '1' then  -- rising clock edge
      max_count <= max_count_in;
    end if;
  end process maxcnt;
  
  -- purpose: Implements a counter to switch 7seg display
  -- type   : sequential
  -- inputs : 
  display_cnt: process (clk24M, reset) is
  begin  -- process fsm1
    if reset = '0' then  -- asynchronous reset (active low)
      display_counter <= 0;
    elsif clk24M'event and clk24M = '1' then  -- rising clock edge		
      if (display_counter = 72727272) then -- 3 seconds
        display_counter <= 0;
        if (cur_display_state = 0) then
          cur_display_state <= 1;
        else
          cur_display_state <= 0;
        end if;			
      else
        display_counter <= display_counter + 1;
      end if;
    end if;
  end process display_cnt;

  
  -- purpose: Implements flipflops to read the current adc value
  -- type   : sequential
  -- inputs : adc_clk, reset, P_enable, adc_result
  ff7seg: process (adc_clk, reset) is
  begin  -- process fsm1
    if reset = '0' then  -- asynchronous reset (active low)
      adc_sync <= 0;
    elsif adc_clk'event and adc_clk = '1' then  -- rising clock edge
      if P_enable = '1' then
        adc_sync <= to_integer(unsigned(adc_result(7 downto 0)));
      end if;
    end if;
  end process ff7seg;

  -- purpose : Shift register that records that last 10 temperature measurements
  -- type    : sequential
  -- inputs  : clk1HZ, reset, adc_sync
  -- outputs : temp9s, temp8s, temp7s, temp6s, temp5s, temp4s, temp3s, temp2s,
  -- temp1s, tempnow, adc_sync2
  tempshiftreg : process (clk1HZ, reset) is
  begin
    if reset = '0' then
      temp9s <= 0;
      temp8s <= 0;
      temp7s <= 0;
      temp6s <= 0;
      temp5s <= 0;
      temp4s <= 0;
      temp3s <= 0;
      temp2s <= 0;
      temp1s <= 0;
      tempnow <= 0;
      adc_sync2 <= 0;      
    elsif clk1HZ'event and clk1HZ = '1' then
      temp9s <= temp8s;
      temp8s <= temp7s;
      temp7s <= temp6s;
      temp6s <= temp5s;
      temp5s <= temp4s;
      temp4s <= temp3s;
      temp3s <= temp2s;
      temp2s <= temp1s;
      temp1s <= tempnow;
      tempnow <= adc_sync2;
      adc_sync2 <= adc_sync;      -- calibration offset!
    end if;    
  end process tempshiftreg;

  -- purpose : Calculates the median value from the last 10 temp. measurements
  -- type    : combinational
  -- inputs  : temp9s, temp8s, temp7s, temp6s, temp5s, temp4s, temp3s, temp2s,
  -- temp1s, tempnow
  -- outputs : temp_avg
  temp_average_cmb : process (temp9s, temp8s, temp7s, temp6s, temp5s, temp4s, temp3s, temp2s, temp1s, tempnow) is
  begin
    temp_avg <= (temp9s + temp8s + temp7s + temp6s + temp5s + temp4s + temp3s + temp2s + temp1s + tempnow) / 10;
  end process temp_average_cmb;

  -- purpose : Calculates decimal values for human-readable temperature to
  -- display in the 7segs
  -- type    : sequential
  -- inputs  : clk1HZ, reset
  -- outputs : adc0, adc1, adc2
  ff7seg2: process (clk1HZ, reset) is
  begin
    if reset = '0' then
      adc0 <= "0000";
      adc1 <= "0000";
      adc2 <= "0000";            
    elsif clk1HZ'event and clk1HZ = '1' then
      if (fan = '1') then
        -- Vcc = 4.58V
        -- Vref/2 = 300mV, Vref = 600mV, 600mV/256 bits resolution = 2.343 mV
        -- per resolution
        adc2 <= std_logic_vector(to_unsigned(((temp_avg * 2343) / 100000) mod 10, 4));        
        adc1 <= std_logic_vector(to_unsigned(((temp_avg * 2343) / 10000) mod 10, 4));
        adc0 <= std_logic_vector(to_unsigned(((temp_avg * 2343) / 1000) mod 10, 4));
      else
        -- Vcc = 4.42V
        -- Vref/2 = 288mV, Vref = 576mV.  576mV/256 bits resolution = 2.25 mV per resolution
        adc2 <= std_logic_vector(to_unsigned(((temp_avg * 225) / 10000) mod 10, 4));        
        adc1 <= std_logic_vector(to_unsigned(((temp_avg * 225) / 1000) mod 10, 4));
        adc0 <= std_logic_vector(to_unsigned(((temp_avg * 225) / 100) mod 10, 4));
      end if;
    end if;    
  end process ff7seg2;

  -- purpose : Drives the relay to activate the fan to lower temperature
  -- type    : sequential
  -- inputs  : clk1HZ, reset, temp_avg
  fancontrol: process (clk1HZ, reset) is
  begin
    if reset = '0' then
      fan <= '1';
    elsif clk1HZ'event and clk1HZ = '1' then
      if (enable1min = '1') then
        if (cold_mode = '1') then
          if (fan = '1') then
            -- relay off, 25C = 106.7 digital
            -- digital 105 = 24,60C
            if (temp_avg >= 105) then
              fan <= '0';
            else
              fan <= '1';
            end if;
          else
            -- relay on
            -- digital 104 = 23.4 C 
            if (temp_avg >= 104) then
              fan <= '0';
            else
              fan <= '1';
            end if;          
          end if;
        else -- not cold mode!
          if (fan = '1') then
            -- relay off, 25C = 106.7 digital
            -- digital 107 = 25,07C
            if (temp_avg >= 107) then
              fan <= '0';
            else
              fan <= '1';
            end if;
          else
            -- relay on
            -- digital 108 = 24.3 C 
            if (temp_avg >= 108) then
              fan <= '0';
            else
              fan <= '1';
            end if;          
          end if;          
        end if;
      end if;
    end if;
  end process fancontrol;

		 
  -- purpose: Implements the state machine used to control temperature
  -- type   : sequential
  -- inputs : adc_clk, reset
  fsm1: process (adc_clk, reset) is
  begin  -- process fsm1
    if reset = '0' then   -- asynchronous reset (active low)
      current_state <= start_state;
    elsif adc_clk'event and adc_clk = '0' then  -- rising clock edge
      current_state <= next_state;
    end if;
  end process fsm1;

  -- purpose: Implements the combinational logic for fsm
  -- type   : combinational
  -- inputs : current_state, adc_n_intr
  -- outputs: next_state, 
  fsm1comb: process (current_state, adc_n_intr) is
  begin  -- process fsm1comb
    case current_state is
      when start_state =>
        next_state <= begin_conversion_state;
        adc_n_cs <= '1';
        adc_n_rd <= '1';
        adc_n_wr <= '1';
        P_enable <= '0';
      when begin_conversion_state =>
        next_state <= begin_conversion_state2;
        adc_n_cs <= '0';
        adc_n_rd <= '1';
        adc_n_wr <= '0';
        P_enable <= '0';
      when begin_conversion_state2 =>
        next_state <= wait_state;
        adc_n_cs <= '0';
        adc_n_rd <= '1';
        adc_n_wr <= '1';
        P_enable <= '0';
      when wait_state =>
        if adc_n_intr = '0' then          
          next_state <= read_state;
        else
          next_state <= wait_state;
        end if;
        adc_n_cs <= '0';
        adc_n_rd <= '1';
        adc_n_wr <= '1';
        P_enable <= '0';
      when read_state =>
        next_state <= wait_state2;
        adc_n_cs <= '0';
        adc_n_rd <= '0';
        adc_n_wr <= '1';
        P_enable <= '0';
      when wait_state2 =>
        if adc_n_intr = '1' then          
          next_state <= finish_state;
        else
          next_state <= wait_state2;
        end if;
        adc_n_cs <= '0';
        adc_n_rd <= '0';
        adc_n_wr <= '1';
        P_enable <= '0';        
      when finish_state =>
        next_state <= start_state;
        adc_n_cs <= '1';
        adc_n_rd <= '1';
        adc_n_wr <= '1';
        P_enable <= '1';
    end case;    
  end process fsm1comb;
end architecture rtl;

