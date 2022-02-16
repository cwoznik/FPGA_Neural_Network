import argparse

import numpy as np

from datetime import date

from tensorflow import keras
from tensorflow.keras import backend as K

def getModelInformation(Path, MavValue=2.0):
    def create_relu_advanced(max_value=2.0):        
                def relu_advanced(x):
                    return K.relu(x, max_value=K.cast_to_floatx(max_value))
                return relu_advanced


    #create a special softmax function so that we limit the output before applying softmax to -1...1
    #usefull for the calculation inside the neural network with fixedpoint. Otherwise we might oversaturate the output 
    def tanh_softmax(x):
        return K.softmax(K.tanh(x))
                    
            
    model = keras.models.load_model(Path,custom_objects={'relu_advanced':create_relu_advanced(MavValue),'tanh_softmax':tanh_softmax})

    for x in model.get_config()["layers"]:
        print(x)

    return (model.get_weights(), model.get_config())

def generateNetworkFile(Path, Name, Weights, Information, OutputType = "VHDL", DataWidth = 8, FixedpointPos = 5):
    supportedAct        = ["linear", "relu_advanced", "sigmoid", "tanh_softmax", "tanh", "softmax"]
    supportedOutputType = ["VHDL","NNET"]
    fixedpointModel     = []
    layerInformation    = []

    weightsCount = 0

    if not OutputType in supportedOutputType:
        raise ValueError("The outputtype {} is not supported!".format(OutputType))

    if len(Weights[1].shape) != 1:                                                      # test if we have bias values in the network
        raise ValueError("Network does not contain bias neurons! This type is not supported")

    for x in Information["layers"]:                                                     # extract the necessary information 
        if x['class_name'] == 'Activation':
            activationFunction = x['config']['activation']
            if activationFunction in supportedAct:
                activationFunctionIndex = supportedAct.index(activationFunction)
                layerInformation.append({"activation": activationFunctionIndex, "inputCount":0, "neuronCount":0 }) #store the information in a list of dictionaries 
            else: 
                raise ValueError("Activationfunction "+activationFunction+" is not supported!")

    if int(len(Weights)/2) != len(layerInformation):                                    #test if we have an equal amount of layers and activation functions
        raise RuntimeError("Got "+str(len(layerInformation))+" acitvationfunctions but "+str(int(len(Weights)/2))+" layers!")

    for i in range(int(len(Weights)/2)):
        layerInformation[i]["inputCount"] = Weights[2*i].shape[0]
        layerInformation[i]["neuronCount"] = Weights[2*i].shape[1]	

        currentLayer = np.vstack((Weights[2*i],Weights[2*i+1]))                         # the network stores the model in ((weights)(bias)) format. So we need to assign the bias weight to the end
        currentLayer *= 2**FixedpointPos                                                # now we have to convert the floting point number into a fixed point number
        currentLayer = np.round(currentLayer).astype(int)
        currentLayer = np.clip(currentLayer, -2**(DataWidth-1),2**(DataWidth-1)-1)      # make sure that we do not excede the range we have specified 

        weightsCount += currentLayer.shape[0] * currentLayer.shape[1]

        fixedpointModel.append(currentLayer)

    if OutputType == "VHDL":
        #write the vhdl file 
        if Path == "": 
            completePath = "NNFFPGA_Network_{}_statics.vhd".format(Name)
        else: 
            completePath ="{}\\NNFFPGA_Network_{}_statics.vhd".format(Path, Name)
        with open(completePath,"w") as f: 
            f.write("-- NNFFPGA_Network_{}_statics.vhd\n".format(Name))
            f.write("-- This is an automatically generated file containing the constants for the neural network\n")
            f.write("-- The constants are generated form a Keras Network Object via the Network-2-FPGA.py script\n")

            f.write("\n")
            f.write("-- Autor: Christian Woznik\n-- E-Mail: christian.woznik@posteo.de\n")
            f.write("-- This file war created on {}".format(date.today()))

            f.write("\n")
            f.write("library IEEE;\nuse IEEE.STD_LOGIC_1164.all;\nuse IEEE.NUMERIC_STD.all;\n\n")
            f.write("library work;\nuse work.NNFPGA_pkg.all;\nuse work.NNFPGA_statics.all;\n\n") 

            f.write("package NNFFPGA_Network_{}_statics is\n".format(Name))

            f.write("\t-- Layer Informations\n")
            f.write("\tconstant c_network{}LayerInformation : t_networkInformation(0 to {}) := (\n".format(Name, len(layerInformation)-1))
            for index, layer in enumerate(layerInformation):
                f.write("\t\t\t{} => (activationFunction => {}, inputCount => {}, neuronCount =>{})".format(index, layer["activation"],layer["inputCount"],layer["neuronCount"]))
                if index != len(layerInformation)-1:
                    f.write(",\n")
                else:
                    f.write(");\n")

            f.write("\n\n\t-- Weights Array\n")
            f.write("\tconstant c_network{}Weights : t_variableSizeIntegerArray(0 to {}) := (\n".format(Name, weightsCount-1))
            count = 0
            for index, weights in enumerate(fixedpointModel):
                f.write("\t\t\t--Layer {}\n".format(index+1))

                for i in range(weights.shape[1]):
                    f.write("\t\t\t--Neuron {}\n".format(i+1))
                    for j in range(weights.shape[0]):
                        f.write("\t\t\t{} => {}".format(count ,weights[j,i]))

                        if count != weightsCount-1:
                            f.write(",\n")
                        else:
                            f.write(");\n")
                        count += 1
                

            f.write("end package NNFFPGA_Network_{}_statics;\n".format(Name))

    else:
        # output for vivado via the importer functions 
        # can not be used with Quartus as it is a piece of shit and does not support standard language concepts 
        # specifically it ignores TextIO during synthesis so you can not import any generic values from external sources 
        
        with open(Path, "w") as f:
            f.write("# Information for the VHDL Code to import the network weights\n")
            f.write("# Created: {}\n".format(date.today()))
            f.write("{layerCount}\n".format(layerCount = len(layerInformation)))
            f.write("{weightsCount}\n".format(weightsCount = weightsCount))

            for layer in layerInformation:
                f.write("{activation} {inputCnt} {neuronCnt}\n".format(activation = layer["activation"], inputCnt = layer["inputCount"], neuronCnt = layer["neuronCount"] ))

            for index, weights in enumerate(fixedpointModel):
                f.write("# Layer {}\n".format(index+1))

                for i in range(weights.shape[1]):
                    f.write("# Neuron {}\n".format(i+1))
                    for j in range(weights.shape[0]):
                        f.write("{}\n".format(weights[j,i]))
    

def main():
    parser = argparse.ArgumentParser(description="Creates and trains a feedforward neural network using Tensorflow. Can apply the trained network to a picture and output the result.")
    parser.add_argument("Modelfile", type=str, help = "path for the model file", default="")
    parser.add_argument("Outputpath", type=str, help = "path for the vhdl output", default= "")
    parser.add_argument("Modelname", type=str, help = "name for vhdl instance", default = "")
    parser.add_argument("-Datawidth", type=int, help = "datawidth for the output. Default = 8",default=8)
    parser.add_argument("-FixedpointPos", type=int, help = "fixedpoint position for the ouput. Default = 5", default=5)

    #run parser
    args = parser.parse_args()

    #get the parsed variables
    modelfile           = args.Modelfile
    outputpath          = args.Outputpath
    modelname           = args.Modelname
    datawidth           = args.Datawidth
    fixedpointPos       = args.FixedpointPos
    
    weights, information = getModelInformation(modelfile)
    generateNetworkFile(outputpath,modelname,weights, information,"VHDL",datawidth,fixedpointPos)

if __name__ == "__main__":
    main()