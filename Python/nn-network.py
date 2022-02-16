#script to create a feedforward neural network using tensorflow and keras 
#imports training data or a given model and can apply the model to either a image or video sequence
#during training you can specifiy the given network topolgy
#exports the model weights if required to be further processed for FPGA usage 
#Author: Christian Woznik
#email: christian.woznik@posteo.de

#TODO: Need to automatically adjust the networks input to the color depth of the training data


import imageio
import numpy as np
import glob
import os
import argparse
import re
import math
import random

#only show Information, Error and Warnings from Tensorflow!
# Do not display all the debug information!
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3' 

import matplotlib.pyplot as plt

import time
from datetime import datetime

from sklearn.feature_extraction import image
from sklearn.metrics import multilabel_confusion_matrix
from sklearn.metrics import confusion_matrix
import skvideo

skvideo.setFFmpegPath("C:/ffmpeg/bin")
import skvideo.io

class NeuralNetworkObject(object):
    #inititalize the variables
    def __init__(self):   
        #delay the import of Tensorflow 
        #although this is not strictly following PEP8, it improves the user experience
        #loading this ontop of the file causes a long delay and thus is frustrating to the user if the cli input has to be corrected
        #global is required otherwise the inport is just inside the __init__ scope

        #importing required tensorflow libs 
        global tf
        import tensorflow as tf
        global keras
        from tensorflow import keras
        global K
        from tensorflow.keras import backend as K
        global Sequential
        from tensorflow.keras.models import Sequential
        global Dense
        from tensorflow.keras.layers import Dense
        global Flatten
        from tensorflow.keras.layers import Flatten
        global Dropout
        from tensorflow.keras.layers import Dropout
        global Conv2D
        from tensorflow.keras.layers import Conv2D
        global MaxPooling2D
        from tensorflow.keras.layers import MaxPooling2D
        global BatchNormalization
        from tensorflow.keras.layers import BatchNormalization
        global to_categorical
        from tensorflow.keras.utils import to_categorical



        physical_devices = tf.config.list_physical_devices('GPU') 
        tf.config.experimental.set_memory_growth(physical_devices[0], True)
 
        #in case we want to visiualise the network output, we define a color palette 
        self._colors = np.array([(0,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,0),(0,255,255),(255,0,255),
                    (0,0,0),(0,0,0),(178,34,34),(255,255,255)])
        
         

    #generates the keras / TF model for training 
    def generateNetwork(self, TanHSoftmax = True, FirstPooling = True, Layers = [(64,"relu"),(64,"relu")], DropoutPercentage = 0.2, EnableBatchNormalisation = False, maxActivation = 2.,
                        Optimizer = "adam", Loss = "categorical_crossentropy"):
        #in order to simulate the behaviour of the FPGA we need to limit the maximum. If left normally we increase the error
        #also we need to return a function to pass on and thus we have the function incaspulated
        def create_relu_advanced(max_value=2.0):        
            def relu_advanced(x):
                return K.relu(x, max_value=K.cast_to_floatx(max_value))
            return relu_advanced

        #create a special softmax function so that we limit the output before applying softmax to -1...1
        #usefull for the calculation inside the neural network with fixedpoint. Otherwise we might oversaturate the output 
        def tanh_softmax(x):
            return K.softmax(K.tanh(x))
        
        print(TanHSoftmax)

        #create the sequential contrainer
        self._model = Sequential()
        
        #if we use pooling to reduce the amout of calculations we can enable it here 
        if FirstPooling:
            #apply a 3x3 max pooling first
            self._model.add(MaxPooling2D((3,3),input_shape=(self._x_train[0].shape[0],self._x_train[0].shape[0])))
            #add the flattening for the feedforward network
            self._model.add(Flatten())
        else:
            #if no pooling just add the flatten  
            self._model.add(Flatten(input_shape=(self._x_train[0].shape[0],self._x_train[0].shape[0])))
            
        #for the amount of spcified layers, add them after another    
        for layer in Layers:
            #we split the layers  into two different steps. That way we can analyse the output better for the conversion for the fpga conversion
            #so we have linear activation for the layer and add the desired activation function afterwards
            self._model.add(Dense(layer[0],activation='linear'))

            #currently only relu has the max, the rest is not yet added, later versions will include the other functions
            #layer is a two element touple so the first element specifies the activation function, the second is the amount of neurons
            if (layer[1] == "relu" and maxActivation > 0): 
                self._model.add(tf.keras.layers.Activation(create_relu_advanced(maxActivation)))
            else:
                self._model.add(tf.keras.layers.Activation(layer[1]))
                
            #print debug output 
            print("adding Layer with function:"+layer[1]+" and "+str(layer[0])+" neurons. ")

            #to reduce the risk of overfitting we can enable dropout. 
            if (DropoutPercentage != 0.0):
                self._model.add(Dropout(DropoutPercentage))
            
            #batch normalization can be used, however currently it is not supported for the fpga conversion
            if EnableBatchNormalisation:
                self._model.add(BatchNormalization())

        #add a softmax layer at the end for the classification.         
        self._model.add(Dense(to_categorical(self._y_train).shape[1], activation='linear'))        
        if TanHSoftmax:
            self._model.add(tf.keras.layers.Activation(tanh_softmax))
        else:
            self._model.add(tf.keras.layers.Activation('softmax'))
            
        #compile the model for computing    
        self._model.compile(optimizer=Optimizer, loss = Loss, metrics=['accuracy'])   

    #train the network             
    def trainNetwork(self, Epochs = 5, BatchSize = 100):
        min = np.min(self._x_train)
        max = np.max(self._x_train)

        #test if the data is already normalized
        if ((min >= 0 and min <= 0.5) or (min >= -1 and min <= -0.95) ) and (max <= 1 and max >= 0.95):
            x_normalized = self._x_train.reshape((-1,self._imageDims,self._imageDims,3))
        else: 
            #otherwise normalize it between 0 and 1
            x_normalized = (self._x_train.reshape((-1,self._imageDims,self._imageDims)) - min ) / float(max)

        #randomize the training data
        rng_state = np.random.get_state()
        np.random.shuffle(x_normalized)
        np.random.set_state(rng_state)
        np.random.shuffle(self._y_train)

        trainValSplit = int(len(self._y_train)*0.7)

        xTrain  = x_normalized[trainValSplit:]
        xVal    = x_normalized[:trainValSplit]

        yTrain  = self._y_train[trainValSplit:]
        yVal    = self._y_train[:trainValSplit]

        #train the model 
        self._model.fit(xTrain, to_categorical(yTrain),epochs = Epochs, 
                        batch_size = BatchSize, validation_split = 0.1, shuffle = True)

        #print the confusion matrix at the end
        print(multilabel_confusion_matrix(yVal,np.argmax(self._model.predict(xVal,batch_size=4096), axis=-1)))
        print("------")
        print(confusion_matrix(yVal,np.argmax(self._model.predict(xVal,batch_size=4096), axis=-1)))
        plt.imshow(confusion_matrix(yVal,np.argmax(self._model.predict(xVal,batch_size=4096), axis=-1)))
        plt.show()

        print(self._model.summary())

    def loadTrainingData(self, FolderPath):
        #go through all numpy files in the folder

        for fullPath in glob.glob(FolderPath+r'\*.npy'):
            #get the name of the current file
            fileName = os.path.split(fullPath)[1]

            #load the numpy data
            #ToDo: should catch errors 
            loadedNP = np.load(fullPath)
            #check if it is labels, pictures or not specified 
            if "labels" in fileName: 
                print("Loading file", fileName, "into labels!")
                try:
                    self._y_train = np.concatenate((self._y_train, loadedNP))
                except AttributeError:
                    self._y_train = loadedNP
            elif "images" in fileName: 
                print("Loading file", fileName, "into images!")
                try:
                    self._x_train = np.concatenate((self._x_train, loadedNP))
                except AttributeError:
                    self._x_train = loadedNP
                    self._imageDims = loadedNP.shape[1]
            else: 
                print("Unknown Numpy filename! ",fileName)

    #save the model with optimizer, etc. 
    def saveNetworkModel(self, Path):
        self._model.save(Path+"model.h5")

    #load the full model 
    def loadNetworkModel(self, Path):
        self._model = keras.models.load_model(Path+"model.h5")

    #only save the weights, we need it for the conversion 
    def saveModelWeights(self, Path):
        self._model.save_weights(Path+"weights.npy")

    def applyModeltoNumpyArray(self, Array):
        #get min and max for normilisation
        min = np.min(Array)
        max = np.max(Array)

        Array -= min
        Array = Array.astype(np.float64) * 1./float(max) 

        #create an empty array for the network output to be appended to 
        networkOutput = np.array([],dtype=np.uint8)

        if Array.shape[0] > 10 * self._imageDims:
            imageHeight = math.ceil(Array.shape[0] / 10.)
            for i in range (10):
                if (i == 0):
                    patches = image.extract_patches_2d(Array[i*imageHeight:(i+1)*imageHeight],(self._imageDims,self._imageDims))
                else:
                    patches = image.extract_patches_2d(Array[i*imageHeight-math.ceil(self._imageDims)+1:(i+1)*imageHeight],(self._imageDims,self._imageDims))
                
                #classifcation
                networkOutput = np.concatenate((networkOutput,np.argmax(self._model.predict(patches,batch_size=4096), axis=-1).astype(np.uint8)))
        else: 
            patches = image.extract_patches_2d(Array,(self._imageDims,self._imageDims))        
            networkOutput = np.argmax(self._model.predict(patches,batch_size=4096), axis=-1).astype(np.uint8)

        

        #as we got the output as a list we need to rearrange the picture in the correct resolution
        networkOutput = np.reshape(networkOutput, (Array.shape[0]-self._imageDims+1,-1))

        #we just have classes before. Now we need to map the classes to our color palette. 
        outputImage = self._colors[networkOutput]

        return outputImage.astype(np.uint8)

    #load a picture, read it, apply the network and then output the networks result
    def applyModelToPicture(self, PicturePath):
        #import the image as an numpy object 
        pic = imageio.imread(PicturePath)
        outputImage = self.applyModeltoNumpyArray(pic[:,:,0])

        #save the output image
        imageio.imsave(PicturePath+"_classification.bmp",outputImage)

    def applyModelToVideo(self, VideoPath):
        #read the video into a numpy array, the structure is (framecount, height, width, colordepth)
        videoData = skvideo.io.vread(VideoPath)
        #TODO: load only segments to require less memory! 
        print("Loaded video from ",VideoPath)
        #iterate through all frames
        for frameNumber, frame in enumerate(videoData):
            #apply the network to the individual frame
            outputImage = self.applyModeltoNumpyArray(frame[:,:,0])
            #clear the old image data, as the classification is a bit smaller on the edges 
            videoData[frameNumber] = np.zeros(frame.shape)
            #save the classification inplace of the cleared image 
            videoData[frameNumber, : outputImage.shape[0], : outputImage.shape[1]] = outputImage
            print(datetime.now(),"Classified frame", frameNumber+1, "out of",videoData.shape[0])

        #write the output video 
        outputVideo = videoData.astype(np.uint8)
        skvideo.io.vwrite(VideoPath+"_classification.mp4",outputVideo)

#function for the parser to parse the activation function
def parseLayerString(arg):
    #list for the supported activation functions 
    acceptedActivationFunctions = ["relu", "sigmoid", "linear","tanh","selu","elu","exponential"]

    layerList = []

    #using regex to seperate all the brackets into a list 
    splitLayerString = re.findall("\((.*?)\)", arg) 

    #go through all the entries and see if they are properly formated 
    for entry in splitLayerString:
        #the entries are still strings, so we need to split them, afterwards we have them inside a list 
        seperatedEntry = entry.split(',')

        #the first entry should be a integer indicating the amount of neurons in that layer, so we test if we can
        #convert it into integer. If not we exit and show an error 
        try: 
            neuronCount = int(seperatedEntry[0])
        except ValueError:
            raise argparse.ArgumentTypeError("can not convert "+ seperatedEntry[0] + " to integer!. You might have reversed the neuron count and activation function")

        #the conversion does not check for negative values so we neeed to check it 
        if neuronCount < 0: 
            raise argparse.ArgumentTypeError("neuron count must be a positive number! " + str(neuronCount)  + " is not allowed!")

        #now we need to check if the activation function is correct 
        if not seperatedEntry[1] in acceptedActivationFunctions:
            raise argparse.ArgumentTypeError("the specified activationfunction "+ seperatedEntry[1]+ " is not accepted. Please check your entry.")
            

        #if we reach here the conversion to int and the check of the activation function were succsessfull. Add the entry to the list
        layerList.append((neuronCount, seperatedEntry[1]))

    #if we can not parse anything return error 
    if len(layerList) == 0:  
        raise argparse.ArgumentTypeError("no valid layers found! Please check your entry.")
    else:
        return layerList

#function to sanity check the range the user inputs for float ranges 
def floatRangeTest(minVal, maxVal):
    #create the actual function
    #as we want to reuse the function and are not able to hand over parameters in argparse we need to use a function
    #to create the desired function. 
    def rangeTest(arg):
        try:
            val = float(arg)
        except ValueError:
            raise argparse.ArgumentTypeError(arg + " is not a floating point number!")
        
        if (val < min) or (val > max):
            raise argparse.ArgumentError(arg + " is out of range! Min: " + str(minVal) + ", Max: " + str(maxVal) +"! Please check the range")

        return val
    return rangeTest



def main():       
    #create parser for cli
    parser = argparse.ArgumentParser(description="Creates and trains a feedforward neural network using Tensorflow. Can apply the trained network to a picture and output the result.")

    parser.add_argument("inPath", type=str, help = "folder path for the trainingdata or the model file")
    parser.add_argument("-lastTanhSoftmax", action="store_true",help="if set the last layer will have a tanh softmax activation function for classification. If not set normal softmax is applied", default=False)
    parser.add_argument("-loadModel",action='store_true', help="if not set .npy files will be loaded and the model trained, if set the model in the inPath is loaded", default=False)
    parser.add_argument("-layers", type = parseLayerString, help = "specifies the networks structure. Uses the following structrue: (Neurons, ActiavationFunction),(Neurons, ActivationFunction,....\n"+
                                                        "Default: (10,relu),(10,relu) gives two hidden layers with 10 neurons each. ",default="(10,relu),(10,relu)")
    parser.add_argument("-maximumActivation", type=floatRangeTest(-1.,50.), help = "maximum output of the acication function. -1 disables it. Default: 2.0", default= 2.0)
    parser.add_argument("-firstPooling", action='store_true', help = "apply a 3x3 max pooling prior to the network.", default= False)
    parser.add_argument("-dropoutPercentage", type=floatRangeTest(0.,1.), help = "dropout percentage used during training. Range from 0 to 1.0. Default: 0.2", default= 0.2)
    parser.add_argument("-batchNormalisation", action='store_true', help = "enable batch normalisation between each layer", default= False)   
    parser.add_argument("-testImagePath",type=str, help="if specified the network will be applied to the image and the result saved.",default="")
    parser.add_argument("-testVideoPath",type=str, help="if specified the network will be applied to the video and the result saved.",default="")
    parser.add_argument("-weightsPath",type=str, help="if specified the networks weights will be saved to the folder",default="") 
    parser.add_argument("-modelOutputPath",type=str, help="if specified the network will be saved to the folder", default="")

    #run parser
    args = parser.parse_args()

    #get the parsed variables
    inPath              = args.inPath
    lastTanhSoftmax     = args.lastTanhSoftmax
    loadModel           = args.loadModel
    layers              = args.layers
    maximumActivation   = args.maximumActivation
    firstPooling        = args.firstPooling
    dropoutPercentage   = args.dropoutPercentage
    batchNormalisation  = args.batchNormalisation
    testImagePath       = args.testImagePath
    testVideoPath       = args.testVideoPath
    weightsPath         = args.weightsPath
    modelOutputPath     = args.modelOutputPath

    #sanitycheck the inputs

    #create the output dir if it does not already exists
    if (weightsPath != ""):
        if not os.path.exists(weightsPath):
            os.makedirs(weightsPath)

    if not os.path.exists(inPath):
        print("Error: Input Path", inPath, "doesnt exist!. Exiting")
        return

    if testImagePath != "":
        if not os.path.exists(testImagePath):
            print("Error: Testimage ", testImagePath, "doesnt exist!. Exiting")
            return

    if testVideoPath != "":
        if not os.path.exists(testVideoPath):
            print("Error: Testimage ", testVideoPath, "doesnt exist!. Exiting")
            return           

    if modelOutputPath != "":
        if not os.path.exists(modelOutputPath):
            print("Error: Testimage ", modelOutputPath, "doesnt exist!. Exiting")
            return       

    #instatitate network object
    nnObject = NeuralNetworkObject()
    if not loadModel:
        nnObject.loadTrainingData(inPath)
        nnObject.generateNetwork(lastTanhSoftmax,firstPooling,layers,dropoutPercentage,batchNormalisation,maximumActivation)
        nnObject.trainNetwork(Epochs=15)
    else:
        nnObject.loadNetworkModel(inPath)

    if testImagePath != "":
        nnObject.applyModelToPicture(testImagePath)

    if testVideoPath != "":
        nnObject.applyModelToVideo(testVideoPath)    

    if weightsPath != "":
        nnObject.saveModelWeights(weightsPath)

    if modelOutputPath != "":
        nnObject.saveNetworkModel(modelOutputPath)

if __name__ == "__main__":
    main()