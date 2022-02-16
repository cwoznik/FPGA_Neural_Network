import numpy as np
import math
from os import path
from sklearn.feature_extraction import image
import imageio

import matplotlib.pyplot as plt

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import backend as K
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense
from tensorflow.keras.layers import Flatten
from tensorflow.keras.layers import Dropout
from tensorflow.keras.layers import MaxPooling2D
from tensorflow.keras.layers import BatchNormalization
from tensorflow.keras.utils import to_categorical

physical_devices = tf.config.list_physical_devices('GPU') 
tf.config.experimental.set_memory_growth(physical_devices[0], True)

def convertCSVtoNP(Filepath):
    supportedFileFormats = ["png","jpeg","jpg","bmp"]

    if not path.isfile(Filepath):
        raise ValueError("Path: '{}' is no file!".format(Filepath))

    if not path.splitext(Filepath)[1] in [".txt",".csv"]:
        raise ValueError("Selected fileformat {} is not valid. Only .csv or .txt are allowed!".format(path.splitext(Filepath)[1]))

    with open(Filepath, "r") as f:
        #read all the lines from the file 
        lines = f.readlines()

        #first line only has comments, we ignore it 

        #second line has the image dimensions so we need to read it as integer 
        try: 
            x,y = [(int(x)) for x in lines[1].split()]
        except ValueError:
            raise ValueError("Error reading the image dimensions. Check that there are two integers seperated by whitespace!")

        #create an empty numpy array to store the image data.
        outputArray = np.zeros((x,y,8))

        #drop the first two rows of data
        lines = lines[2:]

        for index, line in enumerate(lines):
            #each line contains the r,g,b information separated by blank spaces  
            try:
                inputValues = [(int(x)) for x in line.split()]
            except ValueError:
                raise ValueError("Error in line {}. Check that there are three integers seperated by whitespace!".format(index+2))

            outputArray[math.floor(index / y),index % y] = np.array(inputValues)

    return outputArray

def loadNetworkModel(Path, MaxValue = 2.0):
    #as we are using an advanced activation function in the original file we have to create it here as well. Otherwise Tensorflow does 
    #not know what function is refferenced 
    def create_relu_advanced(max_value=2.0):        
            def relu_advanced(x):
                return K.relu(x, max_value=K.cast_to_floatx(max_value))
            return relu_advanced

    #create a special softmax function so that we limit the output before applying softmax to -1...1
    #usefull for the calculation inside the neural network with fixedpoint. Otherwise we might oversaturate the output 
    def tanh_softmax(x):
        return K.softmax(K.tanh(x))          
        
    #as we want the second model to feed into the next model we need to change the activation function of the last layer
    model = keras.models.load_model(Path,custom_objects={'relu_advanced':create_relu_advanced(MaxValue),'tanh_softmax':tanh_softmax})

    return model

colors = np.array([(255,255,255),(0,255,0),(0,0,255),(255,255,0),(255,0,0),(255,255,255),(255,255,255),(255,255,255)])

simOutput = convertCSVtoNP(r"C:\Users\Unknown\Documents\Master-Convolution\VHDL\Code\Testbench\out1.txt")
simOutput = simOutput.astype(float) / 2**5

firstModel = loadNetworkModel(r"C:\Users\Unknown\Documents\Master-Convolution\Python\first.h5")
secondModel = loadNetworkModel(r"C:\Users\Unknown\Documents\Master-Convolution\Python\second.h5")


originalImage = imageio.imread(r"C:\Users\Unknown\Documents\Master-Convolution\Python\Faces\test - Kopie.jpg")
firstNetworkInput = image.extract_patches_2d(originalImage[:,:,0],(7,7))

firstModelOutput = firstModel.predict(firstNetworkInput)

print(firstModelOutput.shape)
print(simOutput.shape)

