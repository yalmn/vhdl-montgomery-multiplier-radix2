library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity montgomery_mult is
    generic (
        WIDTH : integer := 1024  -- Bit width of operands (default 1024-bit for RSA)
    );
    port (
        -- Clock and Reset
        clk    : in  std_logic;  
        reset  : in  std_logic;  --(active high)
        
        -- Control Interface
        enable : in  std_logic;  -- Start computation when '1' (level-triggered)
        done   : out std_logic;  -- Computation complete flag (stays high until enable='0')
        
        A      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplicand
        B      : in  std_logic_vector(WIDTH-1 downto 0);  -- Multiplier  
        N      : in  std_logic_vector(WIDTH-1 downto 0);  -- Modulus (must be odd)
        S      : out std_logic_vector(WIDTH-1 downto 0)   -- Result: S = (A*B*R^-1) mod N
    );
end montgomery_mult;


architecture Behavioral of montgomery_mult is
    -- Core computation registers
    signal S_reg : std_logic_vector(WIDTH downto 0);     -- Extended accumulator (WIDTH+1 bits)
    signal counter : integer range 0 to WIDTH;           -- Bit index counter (0 to WIDTH-1)
    
    -- Input registers for stable computation
    signal A_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered multiplicand
    signal B_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered multiplier
    signal N_reg : std_logic_vector(WIDTH-1 downto 0);   -- Registered modulus
    
    -- Intermediate calculation signals
    signal qi : std_logic;                                -- Quotient bit for Montgomery reduction
    signal temp_sum : std_logic_vector(WIDTH+1 downto 0); -- Temporary sum for additions
    
    -- State machine for sequential computation
    type state_type is (IDLE, INIT, COMPUTE, FINAL_SUB, FINISHED);
    signal state : state_type;
    
    -- Enable edge detection for reliable start trigger (FPGA optimization)
    signal enable_prev : std_logic := '0';               -- Previous enable state
    signal enable_edge : std_logic := '0';               -- Rising edge detection
    
    -- Input change detection for automatic restart capability
    signal A_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal B_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal N_prev : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal inputs_changed : std_logic := '0';
    
begin
    enable_edge <= enable and not enable_prev;
    
    inputs_changed <= '1' when (A /= A_prev or B /= B_prev or N /= N_prev) else '0';

    qi <= S_reg(0) xor (A_reg(counter) and B_reg(0));
    
    -- S = (S + A[i]*B + qi*N) / 2
    temp_sum <= std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '1' and qi = '1') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & B_reg)) when (A_reg(counter) = '1' and qi = '0') else
                std_logic_vector(unsigned('0' & S_reg) + unsigned('0' & N_reg)) when (A_reg(counter) = '0' and qi = '1') else
                '0' & S_reg;  -- No addition needed

    process(clk, reset)
    begin
        if reset = '1' then
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
            enable_prev <= enable;
            A_prev <= A;
            B_prev <= B;
            N_prev <= N;
            
            case state is
                when IDLE =>
                    done <= '0';
                    if enable = '1' then
                        A_reg <= A;
                        B_reg <= B;
                        N_reg <= N;
                        state <= INIT;
                    end if;
                    
                when INIT =>
                    S_reg <= (others => '0');
                    counter <= 0;
                    state <= COMPUTE;
                    
                when COMPUTE =>
                    -- S = (S + A[i]*B + qi*N) / 2  (division by 2 = right shift)
                    S_reg <= temp_sum(WIDTH+1 downto 1);

                    if counter = WIDTH-1 then
                        state <= FINAL_SUB;
                    else
                        counter <= counter + 1;
                    end if;
                    
                when FINAL_SUB =>
                    -- Final conditional subtraction: if S >= N then S = S - N
                    -- This ensures result is in range [0, N-1]
                    if unsigned(S_reg(WIDTH-1 downto 0)) >= unsigned(N_reg) then
                        S_reg(WIDTH-1 downto 0) <= std_logic_vector(unsigned(S_reg(WIDTH-1 downto 0)) - unsigned(N_reg));
                    end if;
                    state <= FINISHED;
                    
                when FINISHED =>
                    done <= '1';
                    if enable = '0' then
                        state <= IDLE;
                    end if;
                    
                when others =>
                    -- Safety catch for undefined states
                    state <= IDLE;
            end case;
        end if;
    end process;

    S <= S_reg(WIDTH-1 downto 0);

end Behavioral;

