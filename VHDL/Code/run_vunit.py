#VUNIT script to run the testbenches 
from pathlib import Path
from vunit import VUnit

#get the current file path
ROOT = Path(__file__).resolve().parent

#Sources path for DUT
DUT_PATH = ROOT / "Design"

#Sources path for testbench
TEST_PATH = ROOT / "Testbench"

#create Vunit instance
VU = VUnit.from_argv()
VU.enable_location_preprocessing()

#create design library
design_lib = VU.add_library("design_lib")
# add design source files to design_lib
design_lib.add_source_files([DUT_PATH / "*.vhd"])
    
#create testbench library
tb_lib = VU.add_library("tb_lib")
#add testbench source files to tb_lib
tb_lib.add_source_files([TEST_PATH / "*.vhd"])

#============================================================================
#add the generics to the required tests
#============================================================================
# #add it for the rgb_2_grey
testbench_rgb2grey = tb_lib.entity("NNFPGA_rgb2grey_tb")
keys =  dict(inputDataWidth = 8, outputDataWidth = 8)
testbench_rgb2grey.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(inputDataWidth = 8, outputDataWidth = 6)
testbench_rgb2grey.add_config("DownShift",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(inputDataWidth = 6, outputDataWidth = 8)
testbench_rgb2grey.add_config("UpShift",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

#----------------------------------------------------------------------------
#add it for the matrixDelay
testbench_rgb2grey = tb_lib.entity("NNFPGA_matrixDelay_tb")
keys =  dict(n = 4, dataWidth = 4, newLineLength = 100)
testbench_rgb2grey.add_config("Small",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(n = 7, dataWidth = 8, newLineLength = 1280)
testbench_rgb2grey.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

#----------------------------------------------------------------------------
#add it for the multi maxtrix Delay
testbench_rgb2grey = tb_lib.entity("NNFPGA_matrixDelayMultipleInput_tb")
keys =  dict(n = 4, dataWidth = 8, newLineLength = 20)
testbench_rgb2grey.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

#----------------------------------------------------------------------------
#add it for the staticMultiplier
testbench_rgb2grey = tb_lib.entity("NNFPGA_staticMultiplier_tb")
keys =  dict(dataSize = 8, fixedpointPos = 5,multiplicationFactor = 32)
testbench_rgb2grey.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(dataSize = 8, fixedpointPos = 5,multiplicationFactor = -32)
testbench_rgb2grey.add_config("Negative",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(dataSize = 8, fixedpointPos = 3,multiplicationFactor = -8)
testbench_rgb2grey.add_config("Negative_3",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

keys =  dict(dataSize = 8, fixedpointPos = 5,multiplicationFactor = 0)
testbench_rgb2grey.add_config("Zero",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

#----------------------------------------------------------------------------
#add it for the neuronal network

testbench_completeNet = tb_lib.entity("NNFPGA_neuralNetwork_tb_full")
keys =  dict(dataSize = 8, fixedpointPos = 5)
testbench_completeNet.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))

testbench_secondNetwork = tb_lib.entity("NNFPGA_neuralNetwork_tb_secondNetwork")
keys =  dict(dataSize = 8, fixedpointPos = 5)
testbench_secondNetwork.add_config("Standard",generics = dict(generics =", ".join(["%s:%s" % (key, str(keys[key])) for key in keys])))



#run VUNIT
VU.main()