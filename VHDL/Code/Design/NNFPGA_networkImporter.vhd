-- NNFPGA_networkImporter
--
-- imports the network weights and information from a text file
-- can not be used with Intel Qartus Prime as TextIO is disabled during synthesis
-- should be used for Xilinx Vivado
--
-- (c) Christian Woznik
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library std;
use std.textio.all;

use work.NNFPGA_pkg.all;

package NNFPGA_networkImporter is 
    impure function importLayerCount(Path : string) return integer; 
    impure function importWeightsCount (Path : string) return integer;
    impure function importNetworkInformation (Path : string) return t_networkInformation;
	impure function importNetworkWeights (Path : string) return t_variableSizeIntegerArray;
end package NNFPGA_networkImporter;


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library std;
use std.textio.all;

use work.NNFPGA_pkg.all;

package body NNFPGA_networkImporter is
    impure function importLayerCount (Path : string) return integer is 
        file layerFile	                : text;
        variable l              		: line;
        variable layerFileStatus   	    : file_open_status;

        variable layerCount           : integer := 0;
    begin
        file_open(layerFileStatus, layerFile, Path, read_mode);

        if layerFileStatus = open_ok then
            readline(layerFile, l);           -- skip line 1 with comment
            readline(layerFile, l);           -- skip line 2 with date
            
            readline(layerFile, l);           -- read line 3 with the layer count
            read(l, layerCount);

            file_close(layerFile);

            return layerCount;
        else 
            return 0;        
        end if;
    end; 


    impure function importWeightsCount (Path : string) return integer is 
        file weightsFile	            : text;
        variable l              		: line;
        variable weightsFileStatus   	: file_open_status;

        variable weightsCount           : integer := 0;
    begin
        file_open(weightsFileStatus, weightsFile, Path, read_mode);

        if weightsFileStatus = open_ok then
            readline(weightsFile, l);           -- skip line 1 with comment
            readline(weightsFile, l);           -- skip line 2 with date

            readline(weightsFile, l);           -- read line 3 with the layer count

            readLine(weightsFile, l);           -- read line 4 with the count of weights
            read(l, weightsCount);

            file_close(weightsFile);

            return weightsCount;
        else 
            return 0;
        end if;
    end; 

    --imports the network informaton from the file
    impure function importNetworkInformation (Path : string) return t_networkInformation is 
        constant layerCount             : integer := importLayerCount(Path);              --we need a constant for the variable declaration so we need to read it beforehand
        variable networkInformation     : t_networkInformation(0 to layerCount-1);  
        variable layerInformation       : t_layerInformation;

        file layerFile	                : text;
        variable l              		: line;
        variable layerFileStatus    	: file_open_status;

        variable activationFunction 	: integer := 0;
		variable inputCount			    : integer := 0;
		variable neuronCount			: integer := 0; 

        variable i                      : integer := 0;
    begin
        file_open(layerFileStatus, layerFile, Path, read_mode);
        
        if layerFileStatus = open_ok then
            readline(layerFile, l);           -- skip line 1 with comment
            readline(layerFile, l);           -- skip line 2 with date

            readline(layerFile, l);           -- skip line 3 with the layer count

            readLine(layerFile, l);           -- skip line 4 with the weights count
            
            
            for i in 0 to layerCount-1 loop       -- read the layer information
                readline(layerFile, l);       
                read(l, activationFunction);
                read(l, inputCount);
                read(l, neuronCount);

                layerInformation.activationFunction := activationFunction;
                layerInformation.inputCount         := inputCount;
                layerInformation.neuronCount        := neuronCount;

                networkInformation(i)               := layerInformation;
            end loop;

            file_close(layerFile);

            return networkInformation;
        end if;

    end function importNetworkInformation;

    --imports the networks weight from the file
    impure function importNetworkWeights (Path : string) return t_variableSizeIntegerArray is 
        constant weightsCount           : integer := importWeightsCount(Path);              --we need a constant for the variable declaration so we need to read it beforehand
        variable weights                : t_variableSizeIntegerArray(0 to weightsCount-1);  

        file weightsFile	            : text;
        variable l              		: line;
        variable weightsFileStatus   	: file_open_status;

        variable layerCount             : integer := 0;
        variable weight                 : integer := 0;

        variable i                      : integer := 0;
    begin
        file_open(weightsFileStatus, weightsFile, Path, read_mode);

        if weightsFileStatus = open_ok then
            readline(weightsFile, l);           -- skip line 1 with comment
            readline(weightsFile, l);           -- skip line 2 with date

            readline(weightsFile, l);           -- read line 3 with the layer count
            read(l, layerCount);                -- extract the layer count

            readLine(weightsFile, l);           -- skip line 4 with the count of weights
            
            
            for i in 0 to layerCount-1 loop       -- skip the layer information
                readline(weightsFile, l);       
            end loop;

            i := 0;

            while not endfile(weightsFile) loop --read the rest of the file containing the weights 
                readline(weightsFile, l);
                if l'length > 0 then            --skip empty lines 
                    if l.all(1) /= '#' then     --skip comments
                        read(l, weight);                                
                        weights(i)  := weight;
                        i := i + 1;
                    end if;
                end if;
            end loop;

            file_close(weightsFile);

            return weights;
        end if;

    end function importNetworkWeights;

end package body NNFPGA_networkImporter;