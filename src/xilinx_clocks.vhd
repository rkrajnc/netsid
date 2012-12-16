library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library UNISIM;
use UNISIM.Vcomponents.all;

entity NetSID_CLOCKS is
  port (
    I_CLK				: in  std_logic;
    I_RESET			: in  std_logic;
    --
    O_CLK_1M		: out std_logic;
    O_CLK_4M		: out std_logic;
    O_CLK_32M		: out std_logic;
    O_RESET			: out std_logic
    );
end;

architecture RTL of NetSID_CLOCKS is

  signal clk_in_ibuf							: std_logic := '0';
  signal clk0_dcm_op							: std_logic := '0';
  signal clkfx_dcm_op							: std_logic := '0';
  signal clk0_dcm_bufg						: std_logic := '0';
  signal clkfx_out_bufg						: std_logic := '0';
  signal dcm_locked								: std_logic := '0';
  signal delay_count							: std_logic_vector(7 downto 0) := (others => '0');
  signal div_cnt									: std_logic_vector(4 downto 0) := (others => '0');
	signal baud_count								: integer range 0 to 127 :=0;

  attribute DLL_FREQUENCY_MODE    : string;
  attribute DUTY_CYCLE_CORRECTION : string;
  attribute CLKOUT_PHASE_SHIFT    : string;
  attribute PHASE_SHIFT           : integer;
  attribute CLKFX_MULTIPLY        : integer;
  attribute CLKFX_DIVIDE          : integer;
  attribute CLKDV_DIVIDE          : real;
  attribute STARTUP_WAIT          : string;
  attribute CLKIN_PERIOD          : real;

  function str2bool (str : string) return boolean is
  begin
    if (str = "TRUE") or (str = "true") then
      return TRUE;
    else
      return FALSE;
    end if;
  end str2bool;

begin
  IBUFG0 : IBUFG port map (I=> I_CLK,        O => clk_in_ibuf);
  BUFG0  : BUFG  port map (I=> clk0_dcm_op,  O => clk0_dcm_bufg);
  BUFG1  : BUFG  port map (I=> clkfx_dcm_op, O => clkfx_out_bufg);
  O_CLK_1M   <= div_cnt(4); 		-- 50 duty, input clk / 32 = 1Mhz
  O_CLK_4M   <= div_cnt(2); 		-- 50 duty, input clk / 32 = 1Mhz
  O_CLK_32M  <= clk0_dcm_bufg;	-- buffered copy of input 32Mhz clock

	-- DCM not really used but available here in case you want special clocks
  dcma   : if true generate
    attribute DLL_FREQUENCY_MODE    of dcm_inst : label is "LOW";
    attribute DUTY_CYCLE_CORRECTION of dcm_inst : label is "TRUE";
    attribute CLKOUT_PHASE_SHIFT    of dcm_inst : label is "NONE";
    attribute PHASE_SHIFT           of dcm_inst : label is 0;
    attribute CLKFX_MULTIPLY        of dcm_inst : label is 2;		-- 1 to 32
    attribute CLKFX_DIVIDE          of dcm_inst : label is 1; 	-- 1 to 32
    attribute CLKDV_DIVIDE          of dcm_inst : label is 2.0; -- 1 to 16, also 1.5 to 7.5
    attribute STARTUP_WAIT          of dcm_inst : label is "FALSE";
    attribute CLKIN_PERIOD          of dcm_inst : label is 31.25;
    --
    begin
    dcm_inst : DCM
    -- pragma translate_off
      generic map (
        DLL_FREQUENCY_MODE    => dcm_inst'DLL_FREQUENCY_MODE,
        DUTY_CYCLE_CORRECTION => str2bool(dcm_inst'DUTY_CYCLE_CORRECTION),
        CLKOUT_PHASE_SHIFT    => dcm_inst'CLKOUT_PHASE_SHIFT,
        PHASE_SHIFT           => dcm_inst'PHASE_SHIFT,
        CLKFX_MULTIPLY        => dcm_inst'CLKFX_MULTIPLY,
        CLKFX_DIVIDE          => dcm_inst'CLKFX_DIVIDE,
        CLKDV_DIVIDE          => dcm_inst'CLKDV_DIVIDE,
        STARTUP_WAIT          => str2bool(dcm_inst'STARTUP_WAIT),
        CLKIN_PERIOD          => dcm_inst'CLKIN_PERIOD
       )
    -- pragma translate_on
      port map (
        CLKIN    => clk_in_ibuf,
        CLKFB    => clk0_dcm_bufg,
        DSSEN    => '0',
        PSINCDEC => '0',
        PSEN     => '0',
        PSCLK    => '0',
        RST      => I_RESET,
        CLK0     => clk0_dcm_op,
        CLK90    => open,
        CLK180   => open,
        CLK270   => open,
        CLK2X    => open,
        CLK2X180 => open,
        CLKDV    => open,
        CLKFX    => clkfx_dcm_op,
        CLKFX180 => open,
        LOCKED   => dcm_locked,
        PSDONE   => open
       );
  end generate;

  reset_delay : process(I_RESET, clk0_dcm_bufg)
  begin
    if (I_RESET = '1') then
      delay_count <= x"00"; -- longer delay for cpu
      O_RESET <= '1';
    elsif rising_edge(clk0_dcm_bufg) then
      if (delay_count(7 downto 0) = (x"FF")) then
        O_RESET <= '0';
      else
        delay_count <= delay_count + "1";
        O_RESET <= '1';
      end if;
    end if;
  end process;

  p_clk_div : process(I_RESET, clk0_dcm_bufg)
  begin
    if (I_RESET = '1') then
      div_cnt <= (others => '0');
    elsif rising_edge(clk0_dcm_bufg) then
      div_cnt <= div_cnt - 1;
    end if;
  end process;

end RTL;
