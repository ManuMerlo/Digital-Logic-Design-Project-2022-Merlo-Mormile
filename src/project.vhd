----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.02.2022 08:39:53
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
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
use ieee.numeric_std.ALL;

entity project_reti_logiche is
   port (  i_clk : in std_logic;
           i_rst : in std_logic;
           i_start : in std_logic;
           i_data : in std_logic_vector(7 downto 0);
           o_address : out std_logic_vector(15 downto 0);
           o_done : out std_logic;
           o_en : out std_logic;
           o_we : out std_logic;
           o_data : out std_logic_vector (7 downto 0)
);
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is 

-- Stati macchina
type state_project is (Reset, Read_Counter, Read_Word, Encoding, Write, Done);
signal current_state: state_project;
signal next_state : state_project := Reset;

-- Stati convoluzione
type state_encoder is (s00,s01,s10,s11);
signal current_state_encoder: state_encoder := s00;
signal next_state_encoder: state_encoder;

-- Segnali da macchina a convoluzione
signal input_encoder : std_logic := '0' ; 
signal enable_encoder : std_logic := '0' ;  
signal reset_encoder : std_logic := '0' ; 

-- Segnali da convoluzione a macchina
signal output_encoder: std_logic_vector ( 1 downto 0) := "00" ;
signal output_encoder_next: std_logic_vector ( 1 downto 0) := "00" ;

 
-- Segnali indirizzi lettura e scrittura memoria
signal address_IN : unsigned(15 downto 0) := "0000000000000000"; -- 0000 in bin 0000 0000 0000 0000
signal address_OUT : unsigned(15 downto 0) := "0000001111101000"; -- 1000 in binario
signal address_IN_next :  unsigned(15 downto 0) := "0000000000000000";
signal address_OUT_next : unsigned(15 downto 0) := "0000001111101000";

-- Contatori
signal counter : unsigned(7 downto 0) := "00000000";
signal counter_next : unsigned(7 downto 0) := "00000000";
signal bits_read: unsigned(3 downto 0):= "0000";
signal bits_read_next: unsigned(3 downto 0):= "0000";
signal bits_saved: unsigned(3 downto 0) := "0000";
signal bits_saved_next: unsigned(3 downto 0) := "0000";

-- Registri input 
signal Reg_IN : std_logic_vector (7 downto 0):= "00000000";
signal Reg_IN_next : std_logic_vector (7 downto 0):= "00000000";

-- Registri Output
signal Reg_OUT: std_logic_vector (7 downto 0):= "00000000";
signal Reg_OUT_next: std_logic_vector (7 downto 0):= "00000000";


begin

-- MACCHINA A STATI PROGETTO
 project_sync: process(i_clk,i_rst) 
   begin
       if (i_rst = '1') then
             -- ricevo segnale di reset
             current_state <= Reset; 
             address_IN <= "0000000000000000";
             address_OUT <= "0000001111101000";
       else if rising_edge(i_clk) then
             -- aggiorno stato macchina e segnali a ogni ciclo di clock
             current_state <= next_state;
             reg_IN <= reg_IN_next;
             reg_OUT <= reg_OUT_next;
             address_IN <= address_IN_next;
             address_OUT <= address_OUT_next;
             counter <= counter_next;
             bits_read <= bits_read_next;
             bits_saved <= bits_saved_next;
           end if;
       end if;
   end process project_sync;

 project_comb : process(current_state,
                        i_start,i_rst,i_data,output_encoder, -- segnali di ingresso alla macchina
                        counter,bits_read,bits_saved, -- contatori
                        address_IN,address_OUT,Reg_IN,Reg_OUT)
       begin
       -- imposto valori di default segnali di uscita (per memoria e per convolutore)
       o_en  <= '0';
       o_we  <= '0';
       o_done <= '0';
       o_data <= "00000000";
       o_address <= "0000000000000000";
       reset_encoder <= '0';
       enable_encoder <= '0';
       input_encoder <= '0';
       -- imposto valori successivi uguali ad attuali ("sovrascritti" in base allo stato attuale della macchina) 
       next_state <= current_state;
       address_IN_next <= address_IN;
       address_OUT_next <= address_OUT;
       reg_IN_next <= reg_IN;
       reg_OUT_next <= reg_OUT;
       counter_next <= counter;
       bits_read_next <= bits_read;
       bits_saved_next <= bits_saved;
       
       case current_state is      
            when Reset    =>    reset_encoder <= '1';
                                if(i_start='1') then -- avvio la macchina leggendo il contatore in posizione 0
                                     o_en <= '1'; 
                                     o_address <= std_logic_vector(address_IN); 
                                     address_IN_next <= address_IN + 1; 
                                     next_state <= Read_Counter;
                                end if;           
            when Read_Counter =>
                                counter_next <= unsigned(i_data); -- leggo contatore
                                o_en <= '1';
                                o_address <= std_logic_vector(address_IN);
                                address_IN_next <= address_IN + 1; 
                                next_state <= Read_Word;

            when Read_Word  =>  if(counter > 0) then -- ho ancora delle parole da codificare
                                     Reg_IN_next <= i_data; -- leggo valore da codificare 
                                     counter_next <= counter - 1;  -- decremento contatore  
                                     next_state <= Encoding;                                  
                                else -- ho finito e porto done a 1
                                     o_done <= '1';
                                     next_state <= Done;
                                end if;

            when Encoding  =>   if(bits_read < 8) then -- ho ancora bit da processare
                                     enable_encoder <= '1'; 
                                     input_encoder <= Reg_IN(7); -- leggo bit
                                     Reg_IN_next <= Reg_IN(6 downto 0) & '0'; -- effettuo left shift del registro
                                     bits_read_next <= bits_read + 1;
                                end if;
                                   
                                if (bits_read > 0) then -- ho letto almeno un bit, salvo i due bit della convoluzione
                                     Reg_OUT_next(7 downto 2) <= Reg_OUT(5 downto 0); -- left shift di due del registro 
                                     Reg_OUT_next(1 downto 0) <=  output_encoder;
                                     bits_saved_next <= bits_saved + 2;
                                end if;
                                  
                                if(bits_saved = 8) then -- controllo se devo stampare byte
                                     o_en <= '1';
                                     o_we <= '1';
                                     o_data <= Reg_OUT; -- copio byte per la stampa
                                     o_address <= std_logic_vector(address_OUT);
                                     address_OUT_next <= address_OUT + 1;
                                     bits_saved_next <= "0010"; -- durante la prima stampa continuo a processare bit
                                     next_state <= Write;
                                end if;
                                                                      
            when Write  =>      if(bits_read < 8) then -- controllo se è primo o secondo byte da stampare 
                                     -- continuo convoluzione durante la stampa
                                     Reg_OUT_next(7 downto 2) <= Reg_OUT(5 downto 0);
                                     Reg_OUT_next(1 downto 0) <= output_encoder;
                                     bits_saved_next <= bits_saved + 2;
                                     -- aggiorno input
                                     enable_encoder <= '1'; 
                                     input_encoder <= Reg_IN(7);
                                     Reg_IN_next <= Reg_IN(6 downto 0) & '0';
                                     bits_read_next <= bits_read + 1;
                                     -- torno in computazione
                                     next_state <= Encoding;
                                else 
                                     -- leggo prossima parola (controllo in read_word il contatore prima della lettura) 
                                     o_en <= '1';
                                     o_address <= std_logic_vector(address_IN);
                                     address_IN_next <= address_IN + 1;
                                     -- resetto valori
                                     bits_read_next <="0000";
                                     bits_saved_next <= "0000";
                                     next_state <= Read_Word;
                                end if;
                                                                                                    
            when Done  =>       if(i_start = '0') then
                                     -- ricevo start a 0, abbasso segnale done e torno in reset
                                     -- reimposto indirizzi a quelli iniziali
                                     address_OUT_next <= "0000001111101000";
                                     address_IN_next <= "0000000000000000";
                                     next_state <= Reset;  
                                else 
                                    o_done <= '1';
                                end if; 
           end case;
     end process  project_comb;
       
-- MACCHINA A STATI CONVOLUZIONE
 encoder_comb : process (current_state_encoder,input_encoder) 
            begin
               case current_state_encoder is
                   when s00 =>
                       if (input_encoder = '0' ) then
                           next_state_encoder <= s00;
                           output_encoder_next <= "00";
                       else 
                           next_state_encoder <= s10;
                           output_encoder_next <= "11";
                       end if;
                   when s01 =>
                       if (input_encoder = '0') then
                           next_state_encoder <=  s00;
                           output_encoder_next <= "11"; 
                       else 
                           next_state_encoder <= s10;
                           output_encoder_next <="00";
                       end if;
                   when s10 =>
                       if (input_encoder='0') then
                           next_state_encoder <= s01;
                           output_encoder_next <="01";
                       else 
                           next_state_encoder <= s11;
                           output_encoder_next <= "10";
                       end if;
                   when s11 =>
                       if (input_encoder ='0') then
                           next_state_encoder <= s01;
                           output_encoder_next <="10";
                       else 
                           next_state_encoder <= s11;
                           output_encoder_next <="01";
                       end if;
                   when others =>
                           next_state_encoder <= current_state_encoder;
                           output_encoder_next <= output_encoder ;
                   end case;
                   
end process encoder_comb;

 encoder_sync:  process (i_clk,reset_encoder,enable_encoder) -- segnali di ingresso al convolutore
       begin
           if (reset_encoder = '1') then
                   current_state_encoder <= s00;
               else 
                   if (rising_edge(i_clk)and(enable_encoder='1')) then -- a ogni ciclo di clock aggiorna output e stato (se abilitato)
                     current_state_encoder <= next_state_encoder;
                     output_encoder <=  output_encoder_next;
                   end if;
           end if;
       end process encoder_sync;
end Behavioral;
