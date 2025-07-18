library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entitaet fuer die Montgomery-Multiplikation
entity montgomery_mult is
    generic (
        WIDTH : integer := 1024  -- Bitbreite der Operanden (z. B. 1024 Bit fuer RSA)
    );
    port (
        -- Takt und Reset
        clk    : in  std_logic;   -- Takt
        reset  : in  std_logic;   -- Reset (aktiv hoch)

        -- Steuerinterface
        enable : in  std_logic;   -- Startsignal: '1' startet die Berechnung (level-gesteuert)
        done   : out std_logic;   -- Signal: Berechnung abgeschlossen (bleibt auf '1' bis enable='0')

        A      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplikand
        B      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplikator
        N      : in  std_logic_vector(WIDTH-1 downto 0);  -- Modulus (muss ungerade sein)
        S      : out std_logic_vector(WIDTH-1 downto 0)   -- Ergebnis: S = (A * B * R⁻¹) mod N
    );
end montgomery_mult;

architecture Behavioral of montgomery_mult is

    -- Register fuer die Hauptberechnung
    signal S_reg : std_logic_vector(WIDTH downto 0);     -- Akkumulator (ein Bit breiter als WIDTH)
    signal counter : integer range 0 to WIDTH;           -- Bit-Zaehler fuer Schleifensteuerung

    -- Eingaberegister fuer stabile Zwischenspeicherung
    signal A_reg : std_logic_vector(WIDTH-1 downto 0);   -- zwischengespeicherter Multiplikand
    signal B_reg : std_logic_vector(WIDTH-1 downto 0);   -- zwischengespeicherter Multiplikator
    signal N_reg : std_logic_vector(WIDTH-1 downto 0);   -- zwischengespeicherter Modulus

    -- Zwischensignale fuer Berechnung
    signal qi : std_logic;                                -- Quotientenbit fuer Montgomery-Reduktion
    signal temp_sum : std_logic_vector(WIDTH+1 downto 0); -- temporaere Summe

    -- Zustandsautomat fuer sequentielle Ausfuehrung
    type state_type is (IDLE, INIT, COMPUTE, FINAL_SUB, FINISHED);
    signal state : state_type;

    -- Flankenerkennung fuer enable (wichtig fuer FPGAs)
    signal enable_prev : std_logic := '0';               -- vorheriger Zustand von enable
    signal enable_edge : std_logic := '0';               -- steigende Flanke von enable

    -- Aenderungserkennung der Eingaben zur automatischen Neuberechnung
    signal A_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal B_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal N_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal inputs_changed : std_logic := '0';

begin
    -- Erkennung einer steigenden Flanke bei enable
    enable_edge <= enable and not enable_prev;

    -- Prueft, ob sich die Eingaben geaendert haben
    inputs_changed <= '1' when (A /= A_prev or B /= B_prev or N /= N_prev) else '0';

    -- Berechnung des qi-Bits fuer Montgomery-Reduktion
    qi <= S_reg(0) xor (A_reg(counter) and B_reg(0));

    -- Temporaere Summe entsprechend dem Algorithmus:
    -- S = (S + A[i]*B + qi*N) / 2  (Division durch 2 = Rechtsshift)
    temp_sum <= std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '1' and qi = '1') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg)) when (A_reg(counter) = '1' and qi = '0') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '0' and qi = '1') else
                '0' & S_reg;  -- Keine Addition noetig

    -- Hauptprozess, reagiert auf Taktflanke und Reset
    process(clk, reset)
    begin
        if reset = '1' then
            -- Ruecksetzen aller Register bei aktivem Reset
            S_reg <= (others => '0');
            counter <= 0;
            done <= '0';
            state <= IDLE;
            A_reg <= (others => '0');
            B_reg <= (others => '0');
            N_reg <= (others => '0');
            enable_prev <= '0';
            A_prev <= (others => '0');
            B_prev <= (others => '0');
            N_prev <= (others => '0');

        elsif rising_edge(clk) then
            -- Flankenerkennung aktualisieren
            enable_prev <= enable;
            A_prev <= A;
            B_prev <= B;
            N_prev <= N;

            -- Zustandsautomat
            case state is
                when IDLE =>
                    done <= '0';
                    if enable = '1' then
                        -- Eingaben uebernehmen
                        A_reg <= A;
                        B_reg <= B;
                        N_reg <= N;
                        state <= INIT;
                    end if;

                when INIT =>
                    -- Akkumulator zuruecksetzen und Zaehler starten
                    S_reg <= (others => '0');
                    counter <= 0;
                    state <= COMPUTE;

                when COMPUTE =>
                    -- Montgomery-Hauptschleife (Schiebe- und Additionslogik)
                    S_reg <= temp_sum(WIDTH+1 downto 1);  -- Division durch 2 (Shift)

                    if counter = WIDTH-1 then
                        state <= FINAL_SUB;
                    else
                        counter <= counter + 1;
                    end if;

                when FINAL_SUB =>
                    -- Finale Korrektur: Subtraktion von N, falls S >= N
                    if unsigned(S_reg(WIDTH-1 downto 0)) >= unsigned(N_reg) then
                        S_reg(WIDTH-1 downto 0) <= std_logic_vector(unsigned(S_reg(WIDTH-1 downto 0)) - unsigned(N_reg));
                    end if;
                    state <= FINISHED;

                when FINISHED =>
                    -- Berechnung abgeschlossen
                    done <= '1';
                    if enable = '0' then
                        state <= IDLE;
                    end if;

                when others =>
                    -- Sicherheits-Zustand bei unerwarteten Werten
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- Ergebniszuweisung: nur die unteren WIDTH Bits
    S <= S_reg(WIDTH-1 downto 0);

end Behavioral;
