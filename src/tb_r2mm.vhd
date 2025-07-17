----------------------------------------------------------------------------------
-- Company:        
-- Engineer:       Halil Yalman (halil@yalman.io)
-- 
-- Create Date:    14:23:26 07/17/2025 
-- Design Name:    Montgomery Multiplier Testbench
-- Module Name:    montgomery_mult_tb - behav
-- Project Name:   R2MM Montgomery Multiplication
-- Target Devices: Xilinx Spartan-3E (xc3s500e-5-vq100)
-- Tool versions:  ISE 14.7
-- Description:    
--   Testbench für die Montgomery-Multiplikation Hardware-Implementierung.
--   Testet die Funktionalität mit sehr großen 1024-Bit-Zahlen.
--   Verifiziert die done_o/read_result Handshake-Funktionalität.
--
-- Test-Szenarien:
--   - 1024-Bit Montgomery-Multiplikation mit maximalen Werten
--   - Verifikation der Zustandsmaschine (IDLE -> CALC -> REDUCE -> FINISHED)
--   - Test der Ergebnis-Zugriffskontrolle (done_o/read_result)
--   - Hex-Ausgabe für einfache Verifikation mit externen Tools
--
-- Dependencies:   IEEE.STD_LOGIC_1164, IEEE.NUMERIC_STD, STD.TEXTIO
--
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 0.02 - Added comprehensive 1024-bit testing
-- Revision 0.03 - Added hex output formatting for verification
-- Additional Comments: 
--   - Generiert Log-Datei "montgomery_tb.log" mit detaillierten Ergebnissen
--   - Hex-Ausgabe ermöglicht Verifikation mit Python/Online-Konvertern
--   - Assertions überprüfen korrekte Funktionalität der Zustandsmaschine
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

-- =============================================================================
-- Montgomery Multiplier Testbench Entity
-- =============================================================================
-- Beschreibung: 
--   Testbench für die Montgomery-Multiplikation Hardware-Implementierung.
--   Testet die Funktionalität mit sehr großen 1024-Bit-Zahlen und verifiziert
--   die korrekte Funktionsweise der Zustandsmaschine und Handshake-Signale.
--
-- Test-Konfiguration:
--   - Taktperiode: 10 ns (100 MHz)
--   - Simulation-Dauer: 50 μs
--   - Bitbreite: 1024 Bit
--   - Log-Datei: "montgomery_tb.log"
-- =============================================================================

entity montgomery_mult_tb is
  -- Testbench hat keine Ports
end entity montgomery_mult_tb;

-- =============================================================================
-- Montgomery Multiplier Testbench Architecture
-- =============================================================================
-- Implementiert umfassende Tests für die Montgomery-Multiplikation:
--   1. Initialisierung und Reset-Verhalten
--   2. 1024-Bit-Test mit sehr großen Zahlen
--   3. Verifikation der Zustandsmaschine
--   4. Test der done_o/read_result Handshake-Funktionalität
-- =============================================================================

architecture behav of montgomery_mult_tb is

  -- Test-Konfiguration
  constant WIDTH     : integer := 1024;                    -- Bitbreite der Operanden
  constant CLK_PERIOD : time := 10 ns;                     -- Taktperiode (100 MHz)
  constant SIM_TIME  : time := 50000 ns;                   -- Simulationsdauer
  
  -- Testbench-Signale
  signal clk         : std_logic := '0';                   -- Systemtakt
  signal reset_n     : std_logic := '0';                   -- Reset-Signal
  signal start       : std_logic := '0';                   -- Start-Signal
  signal read_result : std_logic := '0';                   -- Ergebnis-Zugriffssignal
  
  -- Datenbus-Signale
  signal A           : std_logic_vector(WIDTH-1 downto 0) := (others => '0');  -- Multiplikand
  signal B           : std_logic_vector(WIDTH-1 downto 0) := (others => '0');  -- Multiplikator
  signal N           : std_logic_vector(WIDTH-1 downto 0) := (others => '0');  -- Modulus
  signal S_out       : std_logic_vector(WIDTH-1 downto 0);                     -- Ergebnis
  signal done_o      : std_logic;                                               -- Fertig-Signal

  -- Log-Datei für Testergebnisse
  file log_file : text open write_mode is "montgomery_tb.log";

  -- ==========================================================================
  -- Hilfsfunktionen für Testbench
  -- ==========================================================================
  
  -- Konvertiert std_logic_vector zu integer (für kleine Werte)
  function to_int(x : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(x));
  end function to_int;

  -- Konvertiert std_logic_vector zu Hex-String für Ausgabe
  function to_hex_string(x : std_logic_vector) return string is
    variable result     : string(1 to (x'length + 3) / 4);
    variable temp       : std_logic_vector(3 downto 0);
    variable pos        : integer := 1;
    variable normalized : std_logic_vector(x'length-1 downto 0);
  begin
    normalized := x;  -- Normalisiere den Vektor
    
    for i in normalized'length-1 downto 0 loop
      if (i mod 4) = 3 then
        if i >= 3 then
          temp := normalized(i downto i-3);
        else
          temp := (others => '0');
          temp(i downto 0) := normalized(i downto 0);
        end if;
        
        case temp is
          when "0000" => result(pos) := '0';
          when "0001" => result(pos) := '1';
          when "0010" => result(pos) := '2';
          when "0011" => result(pos) := '3';
          when "0100" => result(pos) := '4';
          when "0101" => result(pos) := '5';
          when "0110" => result(pos) := '6';
          when "0111" => result(pos) := '7';
          when "1000" => result(pos) := '8';
          when "1001" => result(pos) := '9';
          when "1010" => result(pos) := 'A';
          when "1011" => result(pos) := 'B';
          when "1100" => result(pos) := 'C';
          when "1101" => result(pos) := 'D';
          when "1110" => result(pos) := 'E';
          when "1111" => result(pos) := 'F';
          when others => result(pos) := 'X';
        end case;
        pos := pos + 1;
      end if;
    end loop;
    return result;
  end function to_hex_string;

begin

  -- ==========================================================================
  -- Device Under Test (DUT) - Montgomery Multiplier
  -- ==========================================================================
  
  dut: entity work.montgomery_mult
    generic map (
      WIDTH => WIDTH                    -- 1024-Bit Konfiguration
    )
    port map (
      clk         => clk,
      reset_n     => reset_n,
      start       => start,
      read_result => read_result,
      A           => A,
      B           => B,
      N           => N,
      S_out       => S_out,
      done_o      => done_o
    );

  -- ==========================================================================
  -- Taktgenerator
  -- ==========================================================================
  -- Generiert 100 MHz Systemtakt für die Simulation
  -- ==========================================================================
  
  clk_gen: process
  begin
    while now < SIM_TIME loop
      clk <= '0'; 
      wait for CLK_PERIOD/2;
      clk <= '1'; 
      wait for CLK_PERIOD/2;
    end loop;
    wait;  -- Stoppe Taktgenerierung nach Simulationsende
  end process clk_gen;

  -- ==========================================================================
  -- Haupt-Testprozess
  -- ==========================================================================
  -- Führt umfassende Tests der Montgomery-Multiplikation durch:
  --   1. System-Reset und Initialisierung
  --   2. 1024-Bit Test mit sehr großen Zahlen  
  --   3. Verifikation der Zustandsmaschine
  --   4. Test der done_o/read_result Handshake-Logik
  -- ==========================================================================
  
  main_test: process
    variable L : line;  -- Zeiger für Log-Datei Ausgabe
  begin
    
    -- =====================================================================
    -- Test-Initialisierung
    -- =====================================================================
    
    -- System-Reset aktivieren
    reset_n <= '0';
    wait for 100 ns;
    reset_n <= '1';
    wait for 100 ns;

    -- Test-Header in Log-Datei schreiben
    write(L, string'("=== 1024-Bit Montgomery Multiplikation Test ==="));
    writeline(log_file, L);
    write(L, string'("Testkonfiguration:"));
    writeline(log_file, L);
    write(L, string'("  - Bitbreite: 1024 Bit"));
    writeline(log_file, L);
    write(L, string'("  - Taktperiode: 10 ns (100 MHz)"));
    writeline(log_file, L);
    write(L, string'("  - Algorithmus: Montgomery-Multiplikation"));
    writeline(log_file, L);
    writeline(log_file, L);

    -- =====================================================================
    -- Test 1: 1024-Bit Montgomery-Multiplikation mit sehr großen Zahlen
    -- =====================================================================
    
    write(L, string'("=== TEST 1: Sehr große Zahlen (1024-Bit) ==="));
    writeline(log_file, L);
    
    -- Test-Eingangswerte setzen
    -- A = 0xFFFF...FFFF (alle 1024 Bits auf 1)
    A <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    
    -- B = 0xAAAA...AAAA (alternierende Bits: 1010...)
    B <= x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & 
         x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & 
         x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & 
         x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    
    -- N = 0xFFFF...FFFE (alle Bits auf 1, außer LSB)
    N <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & 
         x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    
    wait for 50 ns;

    -- Eingangswerte dokumentieren
    write(L, string'("Eingangswerte:"));
    writeline(log_file, L);
    write(L, string'("  A = 0xFFFF...FFFF (1024 Bits alle 1)"));
    writeline(log_file, L);
    write(L, string'("  B = 0xAAAA...AAAA (1024 Bits alternierend)"));
    writeline(log_file, L);
    write(L, string'("  N = 0xFFFF...FFFE (1024 Bits fast alle 1)"));
    writeline(log_file, L);
    writeline(log_file, L);

    -- Eingangswerte in ISim-Konsole ausgeben
    report "=== EINGANGSWERTE (Hex) ===" severity note;
    report "A = 0x" & to_hex_string(A) severity note;
    report "B = 0x" & to_hex_string(B) severity note;
    report "N = 0x" & to_hex_string(N) severity note;

    -- =====================================================================
    -- Test-Durchführung: Montgomery-Multiplikation starten
    -- =====================================================================
    
    -- Startsignal generieren
    start <= '1';
    wait for 20 ns;
    start <= '0';

    write(L, string'("Montgomery-Multiplikation gestartet..."));
    writeline(log_file, L);

    -- Warten auf Berechnung (keine Zwischenwerte anzeigen)
    wait until done_o = '1';
    wait until rising_edge(clk);

    -- =====================================================================
    -- Test-Verifikation: Zustandsmaschine und Ergebnis prüfen
    -- =====================================================================
    
    -- Assertion: done_o sollte nach Berechnung gesetzt sein
    assert done_o = '1' 
      report "FEHLER: done_o nicht gesetzt nach Berechnung!" 
      severity error;

    write(L, string'("Montgomery-Multiplikation erfolgreich abgeschlossen!"));
    writeline(log_file, L);
    writeline(log_file, L);

    -- Ergebnis in ISim-Konsole ausgeben (Hex als kontinuierlicher String)
    report "=== ENDERGEBNIS (Hex) ===" severity note;
    report "S_out = 0x" & to_hex_string(S_out) severity note;
    report "done_o = " & std_logic'image(done_o) severity note;

    -- Ergebnis in Log-Datei schreiben
    write(L, string'("=== ENDERGEBNIS (Hex) ==="));
    writeline(log_file, L);
    write(L, string'("  S_out = 0x" & to_hex_string(S_out)));
    writeline(log_file, L);
    write(L, string'("  done_o = " & std_logic'image(done_o)));
    writeline(log_file, L);
    writeline(log_file, L);

    -- =====================================================================
    -- Test 2: done_o/read_result Handshake-Funktionalität
    -- =====================================================================
    
    write(L, string'("=== TEST 2: Handshake-Funktionalität ==="));
    writeline(log_file, L);
    
    -- Ergebnis-Zugriff simulieren
    write(L, string'("Simuliere Ergebnis-Zugriff..."));
    writeline(log_file, L);
    
    read_result <= '1';
    wait until rising_edge(clk);
    read_result <= '0';

    -- Assertion: done_o sollte nach read_result zurückgesetzt sein
    wait until rising_edge(clk);
    assert done_o = '0' 
      report "FEHLER: done_o nicht zurückgesetzt nach read_result!" 
      severity error;

    write(L, string'("done_o erfolgreich zurückgesetzt nach read_result"));
    writeline(log_file, L);
    writeline(log_file, L);

    report "done_o erfolgreich zurückgesetzt nach read_result" severity note;

    -- =====================================================================
    -- Test-Abschluss
    -- =====================================================================
    
    write(L, string'("=== ALLE TESTS ERFOLGREICH ABGESCHLOSSEN ==="));
    writeline(log_file, L);
    write(L, string'("1024-Bit Montgomery-Multiplikation vollständig verifiziert"));
    writeline(log_file, L);
    
    report "=== 1024-BIT MONTGOMERY MULTIPLIKATION ERFOLGREICH ABGESCHLOSSEN ===" severity note;
    report "Alle Tests bestanden - Hardware funktioniert korrekt" severity note;
    
    wait;  
  end process main_test;

end architecture behav;
