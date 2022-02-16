import numpy as np
import math
from os import path
import imageio
from datetime import date

def convertCSVtoImage(Filepath, FileFormat):
    supportedFileFormats = ["png","jpeg","jpg","bmp"]

    if not FileFormat in supportedFileFormats:
        raise ValueError("Outputformat {} is not supported! The following are allowed: {}.".format(FileFormat, "".join(supportedFileFormats)))

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
        imageArray = np.zeros((x,y,3), dtype=np.uint8)

        #drop the first two rows of data
        lines = lines[2:]

        for index, line in enumerate(lines):
            #each line contains the r,g,b information separated by blank spaces  
            try:
                r,g,b = [(int(x)) for x in line.split()]
            except ValueError:
                raise ValueError("Error in line {}. Check that there are three integers seperated by whitespace!".format(index+2))

            imageArray[math.floor(index / y),index % y] = np.array((r,g,b))

    outputPath = path.splitext(Filepath)[0]+"."+FileFormat
    imageio.imwrite(outputPath,imageArray)


def convertImageToCsv(Filepath, FileFormat):
    supporteImageFormats = [".png",".jpeg",".jpg",".bmp"]

    if not FileFormat in ["csv","txt"]:
        raise ValueError("Outputformat {} is not supported! The following are allowed: {}.".format(FileFormat, "".join(["csv","txt"])))

    if not path.isfile(Filepath):
        raise ValueError("Path: '{}' is no file!".format(Filepath))

    if not path.splitext(Filepath)[1] in supporteImageFormats:
        raise ValueError("Selected fileformat {} is not valid. The following are allowed: {}.".format(path.splitext(Filepath)[1], " ".join(supporteImageFormats)))

    outputPath = path.splitext(Filepath)[0]+"."+FileFormat

    image = imageio.imread(Filepath)

    with open(outputPath, "w") as f:
        f.write("Created on {}\n".format(date.today()))
        f.write("{} {}\n".format(image.shape[0],image.shape[1]))

        if len(image.shape) == 2:
            for ix, iy in np.ndindex(image.shape):
                f.write("{} {} {}\n".format(image[ix,iy],image[ix,iy],image[ix,iy]))
        elif len(image.shape) == 3:
            for ix, iy in np.ndindex(image.shape[0:2]):
                f.write("{} {} {}\n".format(image[ix,iy,0],image[ix,iy,1],image[ix,iy,2]))


def main():
    #convertImageToCsv(r"C:\Users\Unknown\Documents\Master-Convolution\Python\Faces\test.jpg","txt")
    convertCSVtoImage(r"C:\Users\Unknown\Documents\Master-Convolution\VHDL\Code\Testbench\input.txt","jpg")

if __name__ == "__main__":
    main()