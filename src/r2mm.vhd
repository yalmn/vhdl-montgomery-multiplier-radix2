----------------------------------------------------------------------------------
-- Company:        
-- Engineer:       Halil Yalman (halil@yalman.io)
-- 
-- Create Date:    14:17:44 07/17/2025 
-- Design Name:    Montgomery Multiplier
-- Module Name:    montgomery_mult - rtl 
-- Project Name:   R2MM Montgomery Multiplication
-- Target Devices: Xilinx Spartan-3E (xc3s500e-5-vq100)
-- Tool versions:  ISE 14.7
-- Description:    
--   Hardware-Implementation der Montgomery-Multiplikation für Kryptographie-Anwendungen.
--   Berechnet: S = (A * B * R^-1) mod N, wobei R = 2^WIDTH
--   Unterstützt konfigurierbare Bitbreiten bis 1024 Bit.
--
-- Dependencies:   IEEE.STD_LOGIC_1164, IEEE.NUMERIC_STD
--
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 0.02 - Added read_result functionality for result access control
-- Additional Comments: 
--   - Implementiert den Standard-Montgomery-Algorithmus in Hardware
--   - Zustandsmaschine: IDLE -> CALC -> REDUCE -> FINISHED
--   - done_o Signal wird nach erfolgreicher Berechnung gesetzt
--   - read_result Signal resettet done_o nach Ergebnis-Zugriff
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================================
-- Montgomery Multiplier Entity
-- =============================================================================
-- Beschreibung: 
--   Hardware-Implementierung der Montgomery-Multiplikation für große Zahlen.
--   Berechnet (A * B * R^-1) mod N mit R = 2^WIDTH.
--
-- Generics:
--   WIDTH : Bitbreite der Operanden (Standard: 1024 Bit)
--
-- Ports:
--   clk         : Systemtakt
--   reset_n     : Asynchroner Reset (aktiv low)
--   start       : Startsignal für neue Berechnung
--   read_result : Signal für Ergebnis-Zugriff (setzt done_o zurück)
--   A, B, N     : Eingangswerte für Montgomery-Multiplikation
--   S_out       : Berechnetes Ergebnis
--   done_o      : Fertig-Signal (wird nach Berechnung gesetzt)
-- =============================================================================

entity montgomery_mult is
  generic (
    WIDTH : integer := 1024    -- Bitbreite der Operanden (Standard: 1024 Bit)
  );
  port (
    -- Steuerungssignale
    clk         : in  std_logic;                          -- Systemtakt
    reset_n     : in  std_logic;                          -- Asynchroner Reset (aktiv low)
    start       : in  std_logic;                          -- Startsignal für neue Berechnung
    read_result : in  std_logic;                          -- Ergebnis-Zugriffssignal
    
    -- Dateneingänge
    A           : in  std_logic_vector(WIDTH-1 downto 0); -- Multiplikand
    B           : in  std_logic_vector(WIDTH-1 downto 0); -- Multiplikator
    N           : in  std_logic_vector(WIDTH-1 downto 0); -- Modulus
    
    -- Datenausgänge
    S_out       : out std_logic_vector(WIDTH-1 downto 0); -- Berechnetes Ergebnis
    done_o      : out std_logic                           -- Fertig-Signal
  );
end entity montgomery_mult;

-- =============================================================================
-- Montgomery Multiplier Architecture
-- =============================================================================
-- Implementierung des Montgomery-Algorithmus:
--   1. IDLE:     Warten auf Startsignal
--   2. CALC:     WIDTH Iterationen des Montgomery-Algorithmus
--   3. REDUCE:   Finale Modulo-Reduktion falls S >= N
--   4. FINISHED: Ergebnis bereit, warten auf read_result
-- =============================================================================

architecture rtl of montgomery_mult is
  
  -- Zustandsmaschine für Montgomery-Algorithmus
  type state_type is (IDLE, CALC, REDUCE, FINISHED);
  signal state : state_type := IDLE;

  -- Interne Register für Operanden und Zwischenergebnisse
  signal A_reg    : unsigned(WIDTH-1 downto 0) := (others => '0');  -- Multiplikand-Register
  signal B_reg    : unsigned(WIDTH-1 downto 0) := (others => '0');  -- Multiplikator-Register
  signal N_reg    : unsigned(WIDTH-1 downto 0) := (others => '0');  -- Modulus-Register
  signal S_reg    : unsigned(WIDTH-1 downto 0) := (others => '0');  -- Ergebnis-Register
  
  -- Steuerungsregister
  signal counter  : integer range 0 to WIDTH := 0;                  -- Iterations-Zähler
  signal qi       : std_logic := '0';                               -- Montgomery-Quotient
  signal done_reg : std_logic := '0';                               -- Internes done-Signal

begin
  
  -- Ausgangssignale
  S_out  <= std_logic_vector(S_reg);
  done_o <= done_reg;

  -- ==========================================================================
  -- Montgomery Multiplier Main Process
  -- ==========================================================================
  -- Implementiert den Montgomery-Algorithmus als Zustandsmaschine:
  --   S = (A * B * R^-1) mod N, wobei R = 2^WIDTH
  -- ==========================================================================
  
  montgomery_proc: process(clk, reset_n)
    -- Lokale Variablen für Montgomery-Iteration
    variable y_var : unsigned(WIDTH-1 downto 0);  -- Bedingte Addition von B
    variable z_var : unsigned(WIDTH-1 downto 0);  -- Bedingte Addition von N
    variable t_var : unsigned(WIDTH downto 0);    -- Zwischenergebnis (um 1 Bit erweitert)
  begin
    
    -- Asynchroner Reset
    if reset_n = '0' then
      state    <= IDLE;
      S_reg    <= (others => '0');
      counter  <= 0;
      done_reg <= '0';
      A_reg    <= (others => '0');
      B_reg    <= (others => '0');
      N_reg    <= (others => '0');
      qi       <= '0';

    elsif rising_edge(clk) then
      
      case state is

        -- =====================================================================
        -- IDLE: Warten auf Startsignal
        -- =====================================================================
        when IDLE =>
          done_reg <= '0';                          -- done-Signal zurücksetzen
          
          if start = '1' then
            -- Eingangswerte in interne Register übernehmen
            A_reg   <= unsigned(A);
            B_reg   <= unsigned(B);
            N_reg   <= unsigned(N);
            S_reg   <= (others => '0');             -- Ergebnis-Register initialisieren
            counter <= 0;                           -- Iterations-Zähler zurücksetzen
            state   <= CALC;                        -- Übergang zu Berechnungsphase
          end if;

        -- =====================================================================
        -- CALC: Montgomery-Iterationen (WIDTH Durchläufe)
        -- =====================================================================
        when CALC =>
          -- Bedingte Addition von B basierend auf LSB von A
          if A_reg(0) = '1' then 
            y_var := B_reg; 
          else 
            y_var := (others => '0'); 
          end if;
          
          -- Montgomery-Quotient berechnen: qi = S[0] XOR (A[0] AND B[0])
          qi <= S_reg(0) xor (A_reg(0) and B_reg(0));
          
          -- Bedingte Addition von N basierend auf Montgomery-Quotient
          if qi = '1' then 
            z_var := N_reg; 
          else 
            z_var := (others => '0'); 
          end if;
          
          -- Montgomery-Schritt: t = S + y + z
          t_var := ('0' & S_reg) + y_var + z_var;
          
          -- Rechtsshift um 1 Bit: S = t / 2
          S_reg <= t_var(WIDTH downto 1);
          
          -- Rechtsshift von A um 1 Bit
          A_reg <= '0' & A_reg(WIDTH-1 downto 1);
          
          -- Iterations-Zähler incrementieren
          counter <= counter + 1;
          
          -- Nach WIDTH Iterationen zur Reduktionsphase
          if counter = WIDTH-1 then
            state <= REDUCE;
          end if;

        -- =====================================================================
        -- REDUCE: Finale Modulo-Reduktion
        -- =====================================================================
        when REDUCE =>
          -- Falls S >= N, dann S = S - N
          if S_reg >= N_reg then
            S_reg <= S_reg - N_reg;
          end if;
          state <= FINISHED;

        -- =====================================================================
        -- FINISHED: Ergebnis bereit, warten auf Zugriff
        -- =====================================================================
        when FINISHED =>
          done_reg <= '1';                          -- Fertig-Signal setzen
          
          -- Ergebnis-Zugriff: done-Signal zurücksetzen und zu IDLE
          if read_result = '1' then
            done_reg <= '0';
            state    <= IDLE;
          end if;

      end case;
    end if;
  end process montgomery_proc;
  
end architecture rtl;
