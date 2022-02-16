#imports 
import numpy as np
import glob
import os

from sklearn.feature_extraction import image
import skvideo


skvideo.setFFmpegPath("C:/ffmpeg/bin")
import skvideo.io

from datetime import datetime

#only show Information, Error and Warnings from Tensorflow!
# Do not display all the debug information!
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3' 

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


def loadTrainingData(FolderPath):
    #go through all numpy files in the folder

    for fullPath in glob.glob(FolderPath+r'\*.npy'):
        #get the name of the current file
        fileName = os.path.split(fullPath)[1]

        #load the numpy data
        #ToDo: should catch errors 
        loadedNP = np.load(fullPath)
        #check if it is labels, pictures or not specified 
        if "labels" in fileName: 
            print("Loading file", fileName, "into labels! "+str(len(loadedNP))+" entries found.")
            #try adding the loaded value to the array 
            try:
                y_train = np.concatenate((y_train, loadedNP))
            #it will fail with a NameError if the variable is not exisiting, we we declare it
            except NameError:
                y_train = loadedNP

        elif "images" in fileName: 
            print("Loading file", fileName, "into images! "+str(len(loadedNP))+" entries with shape "+ str((loadedNP.shape[1],loadedNP.shape[2]))+" found.")

            min = np.min(loadedNP)
            max = np.max(loadedNP)

            if not (((min >= 0 and min <= 0.5) or (min >= -1 and min <= -0.95) ) and (max <= 1 and max >= 0.95)):
                #normalize it between 0 and 1
                loadedNP = (loadedNP - min ) / float(max)

            try:
                x_train = np.concatenate((x_train, loadedNP))
            except NameError:
                x_train = loadedNP
    
        else: 
            print("Unknown Numpy filename! ",fileName)

    return (x_train, y_train)

def splitTrainingDataIntoChunks(TraingData, ChunkSize):
    #check if we can slice the training data into thier chunk size
    if (TraingData[0].shape[1] % ChunkSize[0] != 0 or TraingData[0].shape[2] % ChunkSize[1] != 0):
        #if we can not slice it up raise an error 
        raise ValueError()

    #create an empty array for the data in the format 
    chunkArray = np.zeros((int(TraingData[0].shape[1]/ChunkSize[0]),int(trainingData[0].shape[2]/ChunkSize[1]),trainingData[0].shape[0],ChunkSize[0],ChunkSize[1]))

    #randomize the data before splitting. Afterwards it will be more difficult
    rng_state = np.random.get_state()
    np.random.shuffle(TraingData[0])
    np.random.set_state(rng_state)
    np.random.shuffle(TraingData[1])

    for i in range(int(TraingData[0].shape[1]/ChunkSize[0])):
        for j in range(int(TraingData[0].shape[2]/ChunkSize[1])):
            #split out the individual chunks
            chunkArray[i,j] = TraingData[0][:,i*ChunkSize[0]:(i+1)*ChunkSize[0],j*ChunkSize[1]:(j+1)*ChunkSize[1]]

    return (chunkArray,TraingData[1])

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

    print("=============================")
    print(model.layers[-1].activation)
    print("=============================")

    #depending on the input we want to change the activation function
    if model.layers[-1].activation.__name__ == "tanh_softmax" :
        model.layers[-1].activation = keras.activations.tanh
    else:
        model.layers[-1].activation = keras.activations.linear
    #tensorflow requires a recompile. The loss is irrelevant as we do not want to train this model so we do not need the same loss as 
    #during training this model
    model.compile(loss="categorical_crossentropy")
    return model

def buildSecondStageNetwork(TanhSoftmax = True, FirstPooling = True, InputDims = (3,3,7), OutputDims = 5, Layers = [(64,"relu"),(64,"relu")], DropoutPercentage = 0.2, EnableBatchNormalisation = False, maxActivation = 2.,
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

    #create the sequential contrainer
    model = Sequential()
    
    #if we use pooling to reduce the amout of calculations we can enable it here 
    if FirstPooling:
        #apply a 3x3 max pooling first
        model.add(MaxPooling2D((3,3),input_shape=(InputDims[0],InputDims[1],InputDims[2])))
        #add the flattening for the feedforward network
        model.add(Flatten(data_format = "channels_first"))
    else:
        #if no pooling just add the flatten  
        model.add(Flatten(data_format = "channels_first",input_shape=(InputDims[0],InputDims[1],InputDims[2])))
        
    #for the amount of spcified layers, add them after another    
    for layer in Layers:
        #we split the layers  into two different steps. That way we can analyse the output better for the conversion for the fpga conversion
        #so we have linear activation for the layer and add the desired activation function afterwards
        model.add(Dense(layer[0],activation='linear'))

        #currently only relu has the max, the rest is not yet added, later versions will include the other functions
        #layer is a two element touple so the first element specifies the activation function, the second is the amount of neurons
        if (layer[1] == "relu" and maxActivation > 0): 
            model.add(tf.keras.layers.Activation(create_relu_advanced(maxActivation)))
        else:
            model.add(tf.keras.layers.Activation(layer[1]))
            
        #print debug output 
        print("adding Layer with function:"+layer[1]+" and "+str(layer[0])+" neurons. ")

        #to reduce the risk of overfitting we can enable dropout. 
        if (DropoutPercentage != 0.0):
            model.add(Dropout(DropoutPercentage))
        
        #batch normalization can be used, however currently it is not supported for the fpga conversion
        if EnableBatchNormalisation:
            model.add(BatchNormalization())
            
    #add a softmax layer at the end for the classification.         
    model.add(Dense(OutputDims, activation='linear'))

    #for conversion we want to limit the output
    if (TanhSoftmax):
        model.add(tf.keras.layers.Activation(tanh_softmax))
    else:
        model.add(tf.keras.layers.Activation('softmax'))
        
    #compile the model for computing    
    model.compile(optimizer=Optimizer, loss = Loss, metrics=['accuracy'])   

    return model

def applyModelToVideo(VideoPath, Model1, Model2):
    #define a color palette for the video export
    colors = np.array([(255,255,255),(0,255,0),(0,0,255),(255,255,0),(255,0,0),(255,255,255)])

    #read the video into a numpy array, the structure is (framecount, height, width, colordepth)
    videoData = skvideo.io.vread(VideoPath)
    #TODO: load only segments to require less memory! 
    print("Loaded video from ",VideoPath)
    #iterate through all frames
    for frameNumber, frame in enumerate(videoData):
        #we only care about one chanel as the video is greyscale so all three color components are the same 
        frame = frame[:,:,0] 

        #get min and max for normilisation
        min = np.min(frame)
        max = np.max(frame)

        #normalize the frame between 0 and 1
        frame -= min
        frame = frame.astype(np.float64) * 1./float(max)      

        #get the input dimensions of both models 
        firstInputShape     = Model1.get_config()["layers"][0]["config"]["batch_input_shape"]
        secondInputShape    = Model2.get_config()["layers"][0]["config"]["batch_input_shape"]

        #extract the patches from the input
        patches = image.extract_patches_2d(frame,(firstInputShape[1]*secondInputShape[1],firstInputShape[2]*secondInputShape[2]))

        #create an empty array for the output of the first network 
        firstStageOutput = np.zeros((len(patches),secondInputShape[1],secondInputShape[2],secondInputShape[3]))

        #in order to predict the output of the first network we need an array with the shape of (-1,firstInputShape[1],firstInputShape[2])
        #so we need to subset the input. 
        for j in range(secondInputShape[2]):
            for k in range(secondInputShape[3]):
                #create the subset from the patches  
                subSlice = patches[:,j* firstInputShape[1]: (j+1)*firstInputShape[1],k * firstInputShape[2]: (k+1)*firstInputShape[2]]
                #apply the network to the patches
                firstStageOutput[:,:,j,k] = Model1.predict(subSlice ,batch_size=65536)
        #apply the second network to the output of the first network
        finalOutput = Model2.predict(firstStageOutput,batch_size=65536)

        #reshape it, so we get an 2D array again
        finalOutput = np.reshape(finalOutput, (frame.shape[0]-(firstInputShape[1]*secondInputShape[1])+1,frame.shape[1]-(firstInputShape[2]*secondInputShape[2])+1,-1))

        #apply the color of the class that has the highest prediction
        outputImage = colors[np.argmax(finalOutput,axis = 2)]
        #clear the old image data, as the classification is a bit smaller on the edges 
        videoData[frameNumber] = np.stack((np.zeros(frame.shape),np.zeros(frame.shape),np.zeros(frame.shape)),axis=2)
        #save the classification inplace of the cleared image 
        videoData[frameNumber, : outputImage.shape[0], : outputImage.shape[1]] = outputImage
        print(datetime.now(),"Classified frame", frameNumber+1, "out of",videoData.shape[0])

    #write the output video with default settings 
    outputVideo = videoData.astype(np.uint8)
    skvideo.io.vwrite(VideoPath+"_classification.mp4",outputVideo)


trainingData = loadTrainingData("C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\Test")
ogTrainingData = trainingData
trainingData = splitTrainingDataIntoChunks(trainingData,(7,7))
firstModel = loadNetworkModel("C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\first.h5")

firstStageOutput = np.zeros((trainingData[0].shape[2],7,trainingData[0].shape[0],trainingData[0].shape[1]))

#apply the first model to all the input chunks 
for i in range(trainingData[0].shape[0]):
    for j in range(trainingData[0].shape[1]):
        firstStageOutput[:,:,i,j] = firstModel.predict(trainingData[0][i,j])

print(firstStageOutput.shape)

secondStageModel = buildSecondStageNetwork(True, False, InputDims=(7,3,3),OutputDims=6, Layers=[(5,"relu")])

secondStageModel.fit(firstStageOutput, to_categorical(trainingData[1]),epochs = 20, 
                        batch_size = 512, validation_split = 0.1, shuffle = True)
                        
#applyModelToVideo("C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\Test\\Faces.mp4",firstModel,secondStageModel)

#skvideo.io.vwrite("C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\Test\\Faces_invert.mp4", 255-skvideo.io.vread("C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\Test\\Faces.mp4"))

firstModel.summary()
secondStageModel.summary()

firstModel.save("first.h5")
secondStageModel.save("second.h5")