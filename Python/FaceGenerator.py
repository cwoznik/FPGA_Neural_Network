#imports 
import numpy as np
import skimage.draw as draw
import math
import matplotlib.pyplot as plt
import random
import imageio


import skvideo
skvideo.setFFmpegPath("C:/ffmpeg/bin")
import skvideo.io

class FaceCreator(object):    
    #initialize the variables 
    def __init__(self, ImageSize, FaceSize = 3, SubareaSize = 7, BlackBorder = False):

        #TODO: Work with even numbers. They currently go out of range!
        #helper function to create subshapes for the faces
        def createSubshapes(SubareaSize):
            #create an empty array for the subshapes 
            shapeArray = np.zeros((5,SubareaSize,SubareaSize),dtype=np.uint8)

            #add the circle
            if BlackBorder:
                rr,cc = draw.circle_perimeter(math.floor(SubareaSize/2.),math.floor(SubareaSize/2.),math.floor(SubareaSize/2.)-1)
            else:
                rr,cc = draw.circle_perimeter(math.floor(SubareaSize/2.),math.floor(SubareaSize/2.),math.floor(SubareaSize/2.))
            shapeArray[0,rr,cc] = 255

            #draw the cross
            if BlackBorder:
                #first line from top left to bottom right
                rr,cc = draw.line(1,1,SubareaSize-2,SubareaSize-2)
                shapeArray[1,rr,cc] = 255
                #draw the second line from top right to bottom left
                rr,cc = draw.line(SubareaSize-2,1,1,SubareaSize-2)    
            else:
                #first line from top left to bottom right
                rr,cc = draw.line(0,0,SubareaSize-1,SubareaSize-1)
                shapeArray[1,rr,cc] = 255
                #draw the second line from top right to bottom left
                rr,cc = draw.line(SubareaSize-1,0,0,SubareaSize-1)
            shapeArray[1,rr,cc] = 255

            #create the half circle open bottom
            circleOffset = math.floor(SubareaSize/3.)
            if BlackBorder:
                #create all indexes for the circle with the radius at the bottom
                rr,cc = draw.circle_perimeter(SubareaSize-circleOffset,math.floor(SubareaSize/2.),math.floor(SubareaSize/2.)-1)
            else:
                rr,cc = draw.circle_perimeter(SubareaSize-circleOffset,math.floor(SubareaSize/2.),math.floor(SubareaSize/2.))
            #get the positions of all indices that are inside
            #the subarea size
            insideImageValues = rr < SubareaSize-circleOffset
            #only select the indices that are inside the subarea size
            cc = cc[insideImageValues]
            rr = rr[insideImageValues]               
            shapeArray[2,rr,cc] = 255

            #create the half circle open top
            if BlackBorder:
                #create all indexes for the circle with the radius at the top
                rr,cc = draw.circle_perimeter(circleOffset-1,math.floor(SubareaSize/2.),math.floor(SubareaSize/2.)-1)
            else:
                rr,cc = draw.circle_perimeter(circleOffset-1,math.floor(SubareaSize/2.),math.floor(SubareaSize/2.))
            #get the positions of all indices that are inside the subarea size
            insideImageValues = rr >= circleOffset
            #only select the indices that are inside the subarea size
            cc = cc[insideImageValues]
            rr = rr[insideImageValues]
            shapeArray[3,rr,cc] = 255

            #create a line in the middle with 1 pxl space 
            if BlackBorder:
                rr,cc = draw.line(2,math.floor(SubareaSize/2.),SubareaSize-3,math.floor(SubareaSize/2.))
            else:
                rr,cc = draw.line(1,math.floor(SubareaSize/2.),SubareaSize-2,math.floor(SubareaSize/2.))
            shapeArray[4,rr,cc] = 255

            return shapeArray

        #create an empty canvas for the painting of the images, As we want to have some space to draw the faces at the border we add some
        #extra space on the outside 
        self._canvas        = np.zeros((ImageSize[0]+6*SubareaSize,ImageSize[1]+6*SubareaSize,3))    

        #create an empty list for the faces
        self._faces         = []
        
        #store the variables 
        self._imageSize     = ImageSize
        self._faceSize      = FaceSize
        self._subareaSize   = SubareaSize
        self._subShapes     = createSubshapes(SubareaSize)

    #creates a numpy array for the face, fills it with the desired type and returns it as record together with the position and velocity 
    def createFace(self, type, x, y, vx, vy):
        faceMap = np.zeros((self._subareaSize*3,self._subareaSize*3),dtype=np.uint8)
        
        #add the nose as it is the same in all versions 
        faceMap[self._subareaSize:2*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[4]

        #normal face 
        if type == 0:
            #add the left eye
            faceMap[:self._subareaSize,:self._subareaSize] = self._subShapes[0]
            #add the right eye
            faceMap[:self._subareaSize,2*self._subareaSize:3*self._subareaSize] = self._subShapes[0]           
            #add the mouth
            faceMap[2*self._subareaSize:3*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[3]
        #sad face
        elif type == 1:
            #add the left eye
            faceMap[:self._subareaSize,:self._subareaSize] = self._subShapes[0]
            #add the right eye
            faceMap[:self._subareaSize,2*self._subareaSize:3*self._subareaSize] = self._subShapes[0]           
            #add the mouth
            faceMap[2*self._subareaSize:3*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[2]
        #winky face 
        elif type == 2:
            #add the left eye
            faceMap[:self._subareaSize,:self._subareaSize] = self._subShapes[3]
            #add the right eye
            faceMap[:self._subareaSize,2*self._subareaSize:3*self._subareaSize] = self._subShapes[0]           
            #add the mouth
            faceMap[2*self._subareaSize:3*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[3]         
        #dead face 
        elif type == 3:
            #add the left eye
            faceMap[:self._subareaSize,:self._subareaSize] = self._subShapes[1]
            #add the right eye
            faceMap[:self._subareaSize,2*self._subareaSize:3*self._subareaSize] = self._subShapes[1]           
            #add the mouth
            faceMap[2*self._subareaSize:3*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[2]
        #random faces
        elif type == 4:
            selectionArray = np.zeros((2,self._subareaSize,self._subareaSize),dtype=np.uint8)
            selectionArray[1] = np.ones((self._subareaSize,self._subareaSize),dtype=np.uint8)

            faceMap = selectionArray[np.random.choice([0,1],size=(3,3),p=[0.8,0.2])].transpose(0,2,1,3).reshape(faceMap.shape) * \
                        self._subShapes[np.random.randint(0,len(self._subShapes),size=(3,3))].transpose(0,2,1,3).reshape(faceMap.shape)

        return {'pixels':faceMap,'x':x,'y':y,'v_x':vx,'v_y':vy}

    def fillCanvasWithRandomImages(self, FaceCount):
        #calculate the maximum speed in pixel/frame for the movement of the faces 
        #60 is choosen because a face needs at least 5s to travel the entire canvas @ 30FPS
        maxSpeed = self._imageSize[0]/300.
        for i in range(FaceCount):
            #get a random face type
            faceType = random.randint(0,4)
            #get a random position 
            x = random.randint(0,self._imageSize[0]-6*self._subareaSize)
            y = random.randint(0,self._imageSize[1]-6*self._subareaSize)
            #get a random velocity in pixels per frame, we have a flaot from 0..1 so we need to convert it from -maxSpeed..maxSpeed
            vx = round(random.random() * 2*maxSpeed - maxSpeed)
            vy = round(random.random() * 2*maxSpeed - maxSpeed)

            #add the face to the list
            self._faces.append(self.createFace(faceType,x,y,vx,vy))

    def updateCanvas(self):
        #clear the canvas of the previous frame 
        canvasShape = self._canvas.shape
        self._canvas = np.zeros(canvasShape)
        #create the offset for the selection
        offset = math.floor(self._subareaSize/2.)+self._subareaSize
        sideOffset = 3*self._subareaSize
        #empty list for faces to be be kept
        keepFaces = []
        #add the individual faces to the canvas
        for face in self._faces:
            #write the current face to the list 
            #should never have an error here. Just in case something goes the position will get written to console
            try:
                self._canvas[face['x']-offset+sideOffset:face['x']+offset+1+sideOffset,face['y']-offset+sideOffset:face['y']+offset+1+sideOffset][face['pixels'] != 0] = 255
            except:
                print(self._canvas.shape,face['x']-offset+sideOffset, face['x']+offset+1+sideOffset, face['y']-offset+sideOffset, face['y']+offset+1+sideOffset)
            #update the position for the next step
            face['x'] += face['v_x']
            face['y'] += face['v_y']

            #calculate the treshold when a face is outside the border
            threshold = math.ceil(self._subareaSize*3/2.)
            #if the face is outside, remove it and add a new one
            if not (face['x'] <= threshold or face['x'] >= canvasShape[0]-threshold-sideOffset or face['y'] <= threshold or face['y'] >= canvasShape[1]-threshold-sideOffset):
                keepFaces.append(face)
            
        facesRemoved = len(self._faces)-len(keepFaces)   
        self._faces = keepFaces
        if facesRemoved > 0:
            self.fillCanvasWithRandomImages(facesRemoved)
        
    def saveCanvasAsFrame(self, Path, Invert):
        self.updateCanvas()
        if Invert:
            imageio.imwrite(Path, 255-self._canvas[3*self._subareaSize:-3*self._subareaSize,3*self._subareaSize:-3*self._subareaSize].astype(np.uint8))
        else:
            imageio.imwrite(Path, self._canvas[3*self._subareaSize:-3*self._subareaSize,3*self._subareaSize:-3*self._subareaSize].astype(np.uint8))

    def createVideo(self, frameCount, Path, NoiseSteps, Inverse):
        #sideoffset of the canvas
        sideOffset = 3*self._subareaSize

        #allocate memory for the videos
        video = np.zeros((frameCount,self._imageSize[0],self._imageSize[1],3),dtype=np.uint8)
        #just for easier acces of the canvas shape
        canvasShape = self._canvas.shape

        for i in range(frameCount):
            #draw a new canvas and update the positions
            self.updateCanvas()
            #take the current canvas and store it into the frame. Ignore the sideoffset
            video[i] = self._canvas[sideOffset:canvasShape[0]-sideOffset,sideOffset:canvasShape[1]-sideOffset]
            #create noise map and values and apply it to the video frame 
            for step in NoiseSteps:
                if step["startframe"] <= i and step["stopframe"] > i:
                    print(i,step["startframe"],step["stopframe"],step["noisePercentage"])
                    #create a boolean map if this pixel gets noise or not
                    noisePaddern    = np.random.choice([0,1], (video[i].shape[0],video[i].shape[1]), p=[1-step["noisePercentage"],step["noisePercentage"]]).astype(bool)
                    #create a map with a magnitude of noise for each pixel
                    noiseValue      = np.random.randint(0,255,size=(video[i].shape[0],video[i].shape[1]))
                    #as the video frame has 3 values (r,g,b) we need to take stack the noise for each of the channels and add that on to the final picture. 
                    #if noise + video > 255 it overflows and thus reduces the brightness in that area.
                    video[i]        += np.stack((noiseValue*noisePaddern,noiseValue*noisePaddern,noiseValue*noisePaddern),axis=2).astype(np.uint8)
           
        #if wanted inverse the video: White Background with black image
        if Inverse:
            video = 255-video

        #export the video
        skvideo.io.vwrite(Path+"\\Faces.mp4",video)

    def exportSubshapesForTraining(self, Count, MixedPictures, MoveRadius, NoisePercentage, Invert, Path):
        
        if not MixedPictures:
            if MoveRadius > 0:
                #calculate the amout of different classes, +2 because we need an empty and invalid class as well 
                countPerShape       = int(Count/(self._subShapes.shape[0]+2)) 
                diffferentShapes    = self._subShapes.shape[0]+2
            else:
                #one extra is needed for background
                countPerShape       = int(Count/(self._subShapes.shape[0]+1)) 
                diffferentShapes    = self._subShapes.shape[0]+1
        else:
            #we have one more
            countPerShape       = int(Count/(self._subShapes.shape[0]+3)) 
            diffferentShapes    = self._subShapes.shape[0]+3
        #empty array for subshapes
        subshapesArray = np.zeros((diffferentShapes*countPerShape,self._subareaSize,self._subareaSize),dtype=np.uint8)
        #create label list
        labels = np.zeros(diffferentShapes*countPerShape,dtype=np.uint8)
        #go through all the shapes 
        for index, shape in enumerate(self._subShapes):
            #set the labels to the current subshape, plus one as we want the background to be class 0
            labels[index*countPerShape:(index+1)*countPerShape] = index+1

            for i in range(countPerShape):
            #if we want to have moved pictures 
                if MoveRadius > 0: 
                    #get random offsets, we need to have the value from 0 to 2xMoveRadius as we can not select a negative value
                    x_offset = random.randint(-MoveRadius,MoveRadius) + MoveRadius
                    y_offset = random.randint(-MoveRadius,MoveRadius) + MoveRadius
                    #empty selection area
                    selectionArea = np.zeros((self._subareaSize+2*MoveRadius,self._subareaSize+2*MoveRadius),dtype=np.uint8)
                    #add the shape in the middle 
                    selectionArea[MoveRadius:self._subareaSize+MoveRadius,MoveRadius:self._subareaSize+MoveRadius] = shape
                    #add the subshape to the list
                    subshapesArray[index*countPerShape+i] = selectionArea[x_offset:x_offset+self._subareaSize,y_offset:y_offset+self._subareaSize].astype(np.uint8)
                else: 
                    #if we do not want to move it, just add the shape
                    subshapesArray[index*countPerShape+i] = shape.astype(np.uint8)

        #add the moved pictures that are outside the allwoed move radius 
        if MoveRadius > 0:
            for i in range(countPerShape*2):
                #create an offset but this time we need to go outside the subarea size
                x_offset = random.randint(MoveRadius+1,math.ceil(self._subareaSize/2)) 
                y_offset = random.randint(MoveRadius+1,math.ceil(self._subareaSize/2))
                #we need have both positive and negative offsets so we multiply it by either -1 or 1 
                direction  = random.choice([0,1])
                x_offset *= random.choice([1,-1]) * direction 
                y_offset *= random.choice([1,-1]) * (1-direction)
                #as we need a positive number to index the array we need to add the left offset
                x_offset += self._subareaSize + (1-direction) * random.randint(-MoveRadius,MoveRadius)
                y_offset += self._subareaSize + direction * random.randint(-MoveRadius,MoveRadius)

                #empty selection area, this time bigger as we want to create invalid pictures and thus have to move it further
                selectionArea = np.zeros((3*self._subareaSize,3*self._subareaSize),dtype=np.uint8)
                #add a random shape in the middle, -1 as len(self._subShapes) is always one higher than the highest index as python is 0 indexed
                selectionArea[self._subareaSize:2*self._subareaSize,self._subareaSize:2*self._subareaSize] = self._subShapes[random.randint(0,len(self._subShapes)-1)]

                #we do not need to add +1, same reason as above
                subshapesArray[len(self._subShapes)*countPerShape+i] = selectionArea[x_offset:x_offset+self._subareaSize,y_offset:y_offset+self._subareaSize].astype(np.uint8)
            #add the class for the moved pictures
            labels[len(self._subShapes)*countPerShape:(len(self._subShapes)+2)*countPerShape] =  len(self._subShapes)+1

        #add the pictures that have multiple shapes in the picture
        if MixedPictures:
            for i in range(countPerShape):
                #create an offset, only until half the size since we want to have parts of multiple shapes inside 
                x_offset = random.randint(MoveRadius+1,math.ceil(self._subareaSize/2.)) 
                y_offset = random.randint(MoveRadius+1,math.ceil(self._subareaSize/2.))
                #we need have both positive and negative offsets so we multiply it by either -1 or 1 
                x_offset *= random.choice([1,-1])
                y_offset *= random.choice([1,-1])
                #as we need a positive number to index the array we need to add the left offset
                x_offset += self._subareaSize
                y_offset += self._subareaSize             

                #create a grid of 3x3 random values to select the shape in the field 
                shapeSelection  = np.random.randint(0, high = len(self._subShapes),size = (3,3), dtype=np.uint8)
                #create the selection grid from the subshapes and the selection. If we just index the subshapes with the 3x3 grid we get an array of dimension
                #(3,3,7,7). In order to get a (21,21) shape we have to reshape it. Before reshaping the transpose is required otherwise reshape creates the wrong
                #grid
                selectionArea   = self._subShapes[shapeSelection].transpose(0,2,1,3).reshape(3*self._subareaSize,3*self._subareaSize)
                #add the selection to the list
                subshapesArray[(len(self._subShapes)+1)*countPerShape+i] = selectionArea[x_offset:x_offset+self._subareaSize,y_offset:y_offset+self._subareaSize].astype(np.uint8)

            #add the class for the mixed pictures
            labels[(len(self._subShapes)+1)*countPerShape:(len(self._subShapes)+2)*countPerShape] =  len(self._subShapes)+2

        #add noise if desired
        if NoisePercentage > 0:
            #create a boolean map if this pixel gets noise or not
            noisePaddern    = np.random.choice([0,1], subshapesArray.shape, p=[1-NoisePercentage,NoisePercentage]).astype(bool)
            #create a map with a magnitude of noise for each pixel
            noiseValue      = np.random.randint(0,255,size=subshapesArray.shape)       
            #as faces do not have 3 components and we do not need it for training we do not have to do the stacking. 
            subshapesArray +=  (noiseValue*noisePaddern).astype(np.uint8)    

        #if we want to invert the image we have to substract it from the max value. So max -> 0 and 0 -> max
        if Invert:
            subshapesArray = 255-subshapesArray.astype(np.uint8)

        #save the images
        with open(Path + '\\' + 'images_'+str(NoisePercentage)+'.npy',"wb") as f :
            np.save(f,subshapesArray)

        #save the labels 
        with open(Path + '\\' + 'labels_'+str(NoisePercentage)+'.npy',"wb") as f :
            np.save(f,labels)

    def exportSubshapesForValidationAsImage(self, Type, OutsideShift, NoisePercentage, Invert, Path):
        #create an empty image 
        validationImg = np.zeros((self._subareaSize+2*OutsideShift,self._subareaSize+2*OutsideShift),dtype=np.uint8)
        #add the subshape to the center if it is a valid selection
        if Type > 0 and Type < len(self._subShapes):
            validationImg[OutsideShift:OutsideShift+self._subareaSize,OutsideShift:OutsideShift+self._subareaSize] = self._subShapes[Type]
            validationImg[OutsideShift+self._subareaSize:OutsideShift+2*self._subareaSize,OutsideShift:OutsideShift+self._subareaSize] = self._subShapes[random.randint(0,4)]
        #if requried add noise
        if NoisePercentage > 0:
            #create a boolean map if this pixel gets noise or not
            noisePaddern    = np.random.choice([0,1], validationImg.shape, p=[1-NoisePercentage,NoisePercentage]).astype(bool)
            #create a map with a magnitude of noise for each pixel
            noiseValue      = np.random.randint(0,255,size=validationImg.shape)       
            #as faces do not have 3 components and we do not need it for training we do not have to do the stacking. 
            validationImg +=  (noiseValue*noisePaddern).astype(np.uint8)    

        #if we want to invert the image we have to substract it from the max value. So max -> 0 and 0 -> max
        if Invert:
            validationImg = 255-validationImg.astype(np.uint8)
            
        imageio.imsave(Path+"\\validationImg.bmp",validationImg)    
   
    def exportSubshapesForValidation(self, Count, OutsideShift, NoisePercentage, Invert, Path):
        #calculate the amout of different classes, +1 because we need an empty class as well 
        countPerShape       = int(Count/(self._subShapes.shape[0]+1)) 
        diffferentShapes    = self._subShapes.shape[0]+1
        #empty list for 
        validationList = np.zeros((countPerShape*diffferentShapes,self._subareaSize+2*OutsideShift,self._subareaSize+2*OutsideShift),dtype=np.uint8)

        for index, shape in enumerate(self._subShapes):
            for i in range(countPerShape):
                validationList[i+index*countPerShape,OutsideShift:OutsideShift+self._subareaSize,OutsideShift:OutsideShift+self._subareaSize] = shape

        #add noise if desired
        if NoisePercentage > 0:
            #create a boolean map if this pixel gets noise or not
            noisePaddern    = np.random.choice([0,1], validationList.shape, p=[1-NoisePercentage,NoisePercentage]).astype(bool)
            #create a map with a magnitude of noise for each pixel
            noiseValue      = np.random.randint(0,255,size=validationList.shape)       
            #as faces do not have 3 components and we do not need it for training we do not have to do the stacking. 
            validationList +=  (noiseValue*noisePaddern).astype(np.uint8)    

        #if we want to invert the image we have to substract it from the max value. So max -> 0 and 0 -> max
        if Invert:
            validationList = 255-validationList.astype(np.uint8)
            
        #save the images
        with open(Path + '\\' + 'validation.npy',"wb") as f :
            np.save(f,validationList)


    def exportFacesForTraining(self, Count, CreateInvalid, MoveRadius, NoisePercentage, Invert, Path):
        #we need plus one as we have empty class as well
        differentClasses = 4 + 1

        if CreateInvalid and MoveRadius > 0:
            differentClasses += 1
        #create an zero initialized array for the labels. We need to make sure that labels and faces have the same length 
        #so we need to also concider differences caused by rounding 
        labels = np.zeros((differentClasses*int(Count/differentClasses),),dtype=np.uint8)
        #the add the background labels 
        labels[:int(Count/differentClasses)] = 0

        faceShape = self._faceSize*self._subareaSize

        #create an empty array to store the faces 
        faces = np.zeros((differentClasses*int(Count/differentClasses),faceShape,faceShape))

        for i in range(4):
            #add 1/5th of the required counts 
            for j in range(int(Count/differentClasses)):

                if MoveRadius > 0: 
                    #create an empty canvas 
                    canvas = np.zeros((3*faceShape,3*faceShape))
                    #we do not care about speed or velocity so we just take the numpy array from the dictionary and place it in the middle of the canvas
                    canvas[faceShape:2*faceShape,faceShape:2*faceShape] = \
                                self.createFace(i,0,0,0,0,)['pixels']

                    #calculate the offset 
                    x_offset = random.randint(-MoveRadius,MoveRadius) + faceShape
                    y_offset = random.randint(-MoveRadius,MoveRadius) + faceShape

                    faces[(i+1) * int(Count/differentClasses) + j] = canvas[x_offset:x_offset+faceShape,y_offset:y_offset+faceShape]
                else: 
                    faces[(i+1) * int(Count/differentClasses) + j] = self.createFace(i,0,0,0,0,)['pixels']

            #now we add the labels for the other classes, +1 as we have 0 as background
            labels[int(Count/differentClasses)*(i+1):int(Count/differentClasses)*(i+2)] = i+1

        if CreateInvalid and MoveRadius > 0:
            for j in range(int(Count/differentClasses)):
                 #create an empty canvas 
                    canvas = np.zeros((3*faceShape,3*faceShape))
                    #we do not care about speed or velocity so we just take the numpy array from the dictionary and place it in the middle of the canvas
                    canvas[faceShape:2*faceShape,faceShape:2*faceShape] = \
                                self.createFace(random.randint(0,3),0,0,0,0,)['pixels']

                    #create an offset but this time we need to go outside the subarea size
                    x_offset = random.randint(MoveRadius+1,self._subareaSize) 
                    y_offset = random.randint(MoveRadius+1,self._subareaSize)
                    #we need have both positive and negative offsets so we multiply it by either -1 or 1 
                    direction  = random.choice([0,1])
                    x_offset *= random.choice([1,-1]) * direction 
                    y_offset *= random.choice([1,-1]) * (1-direction)

                    x_offset += faceShape
                    y_offset += faceShape

                    faces[5 * int(Count/differentClasses) + j] = canvas[x_offset:x_offset+faceShape,y_offset:y_offset+faceShape]


            labels[int(Count/differentClasses)*(5):] = differentClasses-1

        #create noise map and values and apply it to the video frame 
        if NoisePercentage > 0:
            #create a boolean map if this pixel gets noise or not
            noisePaddern    = np.random.choice([0,1], faces.shape, p=[1-NoisePercentage,NoisePercentage]).astype(bool)
            #create a map with a magnitude of noise for each pixel
            noiseValue      = np.random.randint(0,255,size=faces.shape)       
            #as faces do not have 3 components and we do not need it for training we do not have to do the stacking. 
            faces +=  noiseValue*noisePaddern    

        if Invert:
            faces = 255-faces.astype(np.uint8)

        faces = faces.astype(np.uint8)    

        #save the images
        with open(Path + '\\' + 'images_'+str(NoisePercentage)+'.npy',"wb") as f :
            np.save(f,faces)

        #save the labels 
        with open(Path + '\\' + 'labels_'+str(NoisePercentage)+'.npy',"wb") as f :
            np.save(f,labels)

    

def main():
    face = FaceCreator(ImageSize=(720,1280))

    path = "C:\\Users\\Unknown\\Documents\\Master-Convolution\\Python\\Subshapes"
    #face.exportFacesForTraining(10000,True, 1, 0.0,False,path)
    #face.exportFacesForTraining(10000,True, 1, 0.1,False,path)
    #face.exportFacesForTraining(10000,True, 1, 0.2,False,path)
    #face.exportFacesForTraining(10000,True, 1, 0.3,False,path)
    #face.exportSubshapesForTraining(100000,False,1,0,False,path)
    #face.exportSubshapesForTraining(100000,False,1,0.1,False,path)
    #face.exportSubshapesForTraining(100000,False,1,0.2,False,path)
    #face.exportSubshapesForTraining(100000,False,1,0.3,False,path)
    #face.exportSubshapesForValidation(10000,5,0.05,False,path)
    #face.exportSubshapesForValidationAsImage(random.randint(0,5),20,0.02,False,path)

    face.fillCanvasWithRandomImages(50)
    # face.saveCanvasAsFrame(path+"\\test.jpg",False)
    face.createVideo(450,path,[ {"startframe":100,"stopframe":200,"noisePercentage":0.05},{"startframe":200,"stopframe":300,"noisePercentage":0.125}
                                ,{"startframe":300,"stopframe":450,"noisePercentage":0.25}],False)



if __name__ == "__main__":
    main()