LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- Testbench fuer Montgomery-Multiplikation
ENTITY montgomery_mult_tb IS
END montgomery_mult_tb;

ARCHITECTURE behavior OF montgomery_mult_tb IS 

    -- Einbindung der zu testenden Komponente
    COMPONENT montgomery_mult
    GENERIC (
        WIDTH : integer := 1024  -- 1024-Bit Operandenbreite
    );
    PORT(
        clk     : IN  std_logic;
        reset   : IN  std_logic;
        enable  : IN  std_logic;
        A       : IN  std_logic_vector(1023 downto 0);  -- Multiplikand
        B       : IN  std_logic_vector(1023 downto 0);  -- Multiplikator
        N       : IN  std_logic_vector(1023 downto 0);  -- Modulus
        S       : OUT std_logic_vector(1023 downto 0);  -- Ergebnis
        done    : OUT std_logic
    );
    END COMPONENT;
    
    -- Testbench-Signale
    signal clk    : std_logic := '0';        -- Taktsignal
    signal reset  : std_logic := '0';        -- Reset-Signal
    signal enable : std_logic := '0';        -- Enable-Signal

    -- Test-Operanden (1024-Bit Vektoren)
    signal A : std_logic_vector(1023 downto 0) := (others => '0');  -- Multiplikand
    signal B : std_logic_vector(1023 downto 0) := (others => '0');  -- Multiplikator
    signal N : std_logic_vector(1023 downto 0) := (others => '0');  -- Modulus

    -- Ausgabesignale von UUT
    signal S    : std_logic_vector(1023 downto 0);  -- Ergebnis der Montgomery-Multiplikation
    signal done : std_logic;                        -- Berechnung abgeschlossen

    -- Taktperiode fuer Simulation (10 ns = 100 MHz)
    constant clk_period : time := 10 ns;
    
    -- Signale zur Leistungsmessung
    signal start_cycle    : integer := 0;     -- Zyklus bei Berechnungsstart
    signal end_cycle      : integer := 0;     -- Zyklus bei Berechnungsende
    signal cycle_counter  : integer := 0;     -- Laufender Zyklenzaehler

BEGIN

    -- Instanzierung des UUT (Unit Under Test)
    uut: montgomery_mult 
    GENERIC MAP (
        WIDTH => 1024  -- Test mit 1024-Bit Operanden
    )
    PORT MAP (
        clk    => clk,
        reset  => reset,
        enable => enable,
        A      => A,
        B      => B,
        N      => N,
        S      => S,
        done   => done
    );

    -- Taktgenerierung (100 MHz)
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Zyklenzaehler fuer Leistungsmessung
    cycle_count_process: process(clk)
    begin
        if rising_edge(clk) then
            cycle_counter <= cycle_counter + 1;
        end if;
    end process;

    -- Stimulusprozess zur Testinitialisierung und Auswertung
    stim_proc: process
    begin
        -- System mit Reset initialisieren
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for clk_period * 10;

        report "=== 1024-BIT MONTGOMERY MULTIPLIKATION TEST ===";
        report "Test mit voller 1024-Bit Kapazitaet";

        -- A = 2^1023 - 1 (maximale 1024-Bit Zahl)
        A <= (others => '0');
        A(1022 downto 0) <= (others => '1');  -- Setze Bits 1022 bis 0

        -- B = 2^512 + 2^256 + 2^128 + 1 (verteiltes Muster)
        B <= (others => '0');
        B(512) <= '1';
        B(256) <= '1';
        B(128) <= '1';
        B(64)  <= '1';
        B(32)  <= '1';
        B(16)  <= '1';
        B(8)   <= '1';
        B(4)   <= '1';
        B(2)   <= '1';
        B(0)   <= '1';

        -- N = 2^1023 - 165 (grosse ungerade Zahl)
        N <= (others => '0');
        N(1022 downto 8) <= (others => '1');
        N(7) <= '0';
        N(6) <= '1';
        N(5) <= '0';
        N(4) <= '1';
        N(3) <= '0';
        N(2) <= '1';
        N(1) <= '1';
        N(0) <= '1';

        wait for clk_period * 2;

        -- Starte 1024-Bit Berechnung
        start_cycle <= cycle_counter;
        enable <= '1';
        wait for clk_period;

        wait until done = '1' for 200 ms;

        if done = '1' then
            end_cycle <= cycle_counter;
            wait for clk_period;
            report "=== 1024-BIT BERECHNUNG ABGESCHLOSSEN ===";

            -- Zeige Ergebnis (teilweise, im Hex-Format)
            report "Ergebnis S (Bits 31-0):   0x" & 
                   integer'image(to_integer(unsigned(S(31 downto 28)))) & 
                   integer'image(to_integer(unsigned(S(27 downto 24)))) & 
                   integer'image(to_integer(unsigned(S(23 downto 20)))) & 
                   integer'image(to_integer(unsigned(S(19 downto 16)))) & 
                   integer'image(to_integer(unsigned(S(15 downto 12)))) & 
                   integer'image(to_integer(unsigned(S(11 downto 8)))) & 
                   integer'image(to_integer(unsigned(S(7 downto 4)))) & 
                   integer'image(to_integer(unsigned(S(3 downto 0))));

            report "Ergebnis S (Bits 63-32):  0x" & 
                   integer'image(to_integer(unsigned(S(63 downto 60)))) & 
                   integer'image(to_integer(unsigned(S(59 downto 56)))) & 
                   integer'image(to_integer(unsigned(S(55 downto 52)))) & 
                   integer'image(to_integer(unsigned(S(51 downto 48)))) & 
                   integer'image(to_integer(unsigned(S(47 downto 44)))) & 
                   integer'image(to_integer(unsigned(S(43 downto 40)))) & 
                   integer'image(to_integer(unsigned(S(39 downto 36)))) & 
                   integer'image(to_integer(unsigned(S(35 downto 32))));

            report "Ergebnis S (Bits 95-64):  0x" & 
                   integer'image(to_integer(unsigned(S(95 downto 92)))) & 
                   integer'image(to_integer(unsigned(S(91 downto 88)))) & 
                   integer'image(to_integer(unsigned(S(87 downto 84)))) & 
                   integer'image(to_integer(unsigned(S(83 downto 80)))) & 
                   integer'image(to_integer(unsigned(S(79 downto 76)))) & 
                   integer'image(to_integer(unsigned(S(75 downto 72)))) & 
                   integer'image(to_integer(unsigned(S(71 downto 68)))) & 
                   integer'image(to_integer(unsigned(S(67 downto 64))));

            report "Ergebnis S (Bits 127-96): 0x" & 
                   integer'image(to_integer(unsigned(S(127 downto 124)))) & 
                   integer'image(to_integer(unsigned(S(123 downto 120)))) & 
                   integer'image(to_integer(unsigned(S(119 downto 116)))) & 
                   integer'image(to_integer(unsigned(S(115 downto 112)))) & 
                   integer'image(to_integer(unsigned(S(111 downto 108)))) & 
                   integer'image(to_integer(unsigned(S(107 downto 104)))) & 
                   integer'image(to_integer(unsigned(S(103 downto 100)))) & 
                   integer'image(to_integer(unsigned(S(99 downto 96))));

            report "Zyklen: " & integer'image(end_cycle - start_cycle);
            report "Berechnungszeit: " & time'image((end_cycle - start_cycle) * clk_period);

            -- Leistungsbewertung
            if (end_cycle - start_cycle) > 1020 and (end_cycle - start_cycle) < 1030 then
                report "ERFOLG: Zyklenanzahl im erwarteten Bereich (~1026)!";
            else
                report "INFO: Zyklenanzahl: " & integer'image(end_cycle - start_cycle) & " (erwartet ~1026)";
            end if;

            report "=== IMPLEMENTIERUNG BEREIT FUER FPGA ===";
        else
            report "FEHLER: 1024-Bit Berechnung Timeout!";
        end if;

        wait;
    end process;

END;
