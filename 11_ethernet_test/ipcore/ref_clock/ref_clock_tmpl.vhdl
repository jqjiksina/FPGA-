-- Created by IP Generator (Version 2022.1 build 99559)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT ref_clock
  PORT (
    clkin1 : IN STD_LOGIC;
    pll_lock : OUT STD_LOGIC;
    clkout1 : OUT STD_LOGIC
  );
END COMPONENT;


the_instance_name : ref_clock
  PORT MAP (
    clkin1 => clkin1,
    pll_lock => pll_lock,
    clkout1 => clkout1
  );
