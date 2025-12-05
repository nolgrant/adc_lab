----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/08/2022 03:02:20 PM
-- Design Name: 
-- Module Name: AD9467_Interfacetop_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity AD9467_INTERFACE is
  Port ( 
    PSINCDEC : in std_logic;
    PSEN : in std_logic;
    PSCLK : in std_logic;
    PSDONE : out std_logic;
    Unshifted_clk : out std_logic;
    ADCCLK : out std_logic;
    ADC_DATA : out std_logic_vector (15 downto 0);
    -- LVDS signals from AD9467
    Din_p : in std_logic_vector (7 downto 0);
    Din_n : in std_logic_vector (7 downto 0);
    CLK_p : in std_logic;
    CLK_N : in std_logic
  );
end AD9467_INTERFACE;

architecture Behavioral of AD9467_INTERFACE is

component clk_wiz_0
     port (
         clk_out1 : out std_logic;
         clk_out2 : out std_logic;        
         psclk : in std_logic;
         psen : in std_logic;
         psincdec : in std_logic;
         psdone : out std_logic;
         clk_in1_p : in std_logic;
         clk_in1_n : in std_logic
         );
end component;

signal O, Q1, Q2 : std_logic_vector (7 downto 0); 
signal shifted_clk : std_logic;
--signal ADC_DATA1, ADC_DATA2 :  std_logic_vector (15 downto 0);

begin

-- IBUFDS (input buffer diffrential signal) 
-- Read all 8 input differential signals  Din_p(7:0) & Din_n(7:0)
-- Output a vector of single ended signal O(7:0)
gen_IBUFDS : for i in 0 to 7 generate
IBUFDS_inst : IBUFDS
    generic map(
      DIFF_TERM => FALSE, --Differential Termination
      IBUF_LOW_PWR => TRUE, --Low power (TRUE) vs. performance (FALSE) setting referenced I/O standards
      IOSTANDARD=> "LVDS_25")
    port map(
      O=> O(i), -- buffer output
      I=> Din_p(i), --Diff_p buffer input
      IB => Din_n(i)); --Diff_n buffer input
end generate;
      
 -- CLK Wizard
 -- read in differential clock and output 2 clocks
 --   1: single-ended version of input clock (for debug) 
 --   2: shifted single-ended signal 
 clk_wiz_inst : clk_wiz_0
      port map(
          clk_out1 => shifted_clk,  --shifted clk
          clk_out2 => Unshifted_clk,  --unshifted clk for debug only      
          psclk => PSCLK,
          psen => PSEN,
          psincdec => PSINCDEC,     --17.9ps per psen
          psdone => PSDONE,
          clk_in1_p => CLK_p, --clk from the adc
          clk_in1_n => CLK_n  --clk from the adc
          );
ADCCLK <= shifted_clk;  

-- IDDR (input dual data rate) 
-- Reads 8 single ended DDR signals O(7:0)
-- convert to 16 single ended "normal" signals Q1(7:0) and Q2(7:0)  
gen_IDDR: for i in 0 to 7 generate    
 IDDR_inst : IDDR
    generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",--"OPPOSITE_EDGE" "SAME_EDGE", "SAME_EDGE_PIPELINED"
      INIT_Q1 => '0', --initial value of Q1 : '0' or '1'
      INIT_Q2 => '0', --initial value of Q2 : '0' or '1'
      SRTYPE => "SYNC") -- set/reset type : "SYNC" or "ASYNC"
    port map (
      Q1 => Q1(i), -- 1-bit output for positive edge of clock
      Q2 => Q2(i), -- 1-bit output for negative edge of clock
      C => shifted_clk, -- 1-bit clock input
      CE => '1', -- 1-bit clock enable input (in this situation always enabled)
      D => O(i), -- 1-bit DDR data input
      R => '0', -- 1-bit reset (no reason to ever reset in this used case)
      S => '0' -- 1-bit set (no reason to ever "set" in this use case)
      );
 end generate;    
 
--  |---------- from AD9467 User Guide ----------|------------- in FPGA -------------|
--  pin   name        rising edge   falling edge  DS            DDR       SE (50/50 shot)
--  19    D1-/D0-     D1            D0 (LSB)      Din_n(0)      O(0)      D0  =  Q1(0)  OR  Q2(0)
--  20    D1+/D0+     D1            D0 (LSB)      Din_p(0)                D1  =  Q2(0)  OR  Q1(0)
--  21    D3-/D2-     D3            D2            Din_n(1)      O(1)      D2  =  Q1(1)  OR  Q2(1)
--  22    D3+/D2+     D3            D2            Din_p(1)                D3  =  Q2(1)  OR  Q1(1)
--  23    D5-/D4-     D5            D4            Din_n(2)      O(2)      D4  =  Q1(2)  OR  Q2(2)
--  24    D5+/D4+     D5            D4            Din_p(2)                D5  =  Q2(2)  OR  Q1(2)
--  25    D7-/D6-     D7            D6            Din_n(3)      O(3)      D6  =  Q1(3)  OR  Q2(3)
--  26    D7+/D6+     D7            D6            Din_p(3)                D7  =  Q2(3)  OR  Q1(3)
--  29    D9-/D8-     D9            D8            Din_n(4)      O(4)      D8  =  Q1(4)  OR  Q2(4)
--  30    D9+/D8+     D9            D8            Din_p(4)                D9  =  Q2(4)  OR  Q1(4)
--  31    D11-/D10-   D11           D10           Din_n(5)      O(5)      D10 =  Q1(5)  OR  Q2(5)
--  32    D11+/D10+   D11           D10           Din_p(5)                D11 =  Q2(5)  OR  Q1(5)
--  33    D13-/D12-   D13           D12           Din_n(6)      O(6)      D12 =  Q1(6)  OR  Q2(6)
--  34    D13+/D12+   D13           D12           Din_p(6)                D13 =  Q2(6)  OR  Q1(6)
--  35    D15-/D14-   D15 (MSB)     D14           Din_n(7)      O(7)      D14 =  Q1(7)  OR  Q2(7)
--  36    D15+/D14+   D15 (MSB)     D14           Din_p(7)                D15 =  Q2(7)  OR  Q1(7)

---- option 1
--ADC_DATA <= (not Q2(7)) & Q1(7) &
--                 Q2(6)  & Q1(6) &
--                 Q2(5)  & Q1(5) &
--                 Q2(4)  & Q1(4) &
--                 Q2(3)  & Q1(3) &
--                 Q2(2)  & Q1(2) &
--                 Q2(1)  & Q1(1) &
--                 Q2(0)  & Q1(0);
                 
-- option 2 - empirically found to be correct
ADC_DATA <= (not Q1(7)) & Q2(7) &
                 Q1(6)  & Q2(6) &
                 Q1(5)  & Q2(5) &
                 Q1(4)  & Q2(4) &
                 Q1(3)  & Q2(3) &
                 Q1(2)  & Q2(2) &
                 Q1(1)  & Q2(1) &
                 Q1(0)  & Q2(0);


end Behavioral;