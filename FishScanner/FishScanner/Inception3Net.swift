//
//  Inception3Net.swift
//  FishScanner
//
//  Created by Németh Bendegúz on 2017. 03. 15..
//  Copyright © 2017. Németh Bendegúz. All rights reserved.
//

import Foundation
import UIKit
import MetalKit
import MetalPerformanceShaders
import Accelerate

let textureFormat = MPSImageFeatureChannelFormat.float16

/**
    
    This class has our entire network with all layers from preprocessing to getting the intermediate and final labels as well
 
    [Original Inception_v3 Network Paper](http://arxiv.org/pdf/1512.00567v3.pdf)
 
 */
class Inception3Net{
    
    // we keep the MTLDevice and MTLCommandQueue objects around for ease of use
    var device : MTLDevice!
    var commandQueue : MTLCommandQueue
    
    
    // pre-processing layers and an MPSTemporaryImage for it
    var lanczos : MPSImageLanczosScale!
    var scale : MPSCNNNeuronLinear!
    var preImage : MPSTemporaryImage!
    
    // MPSImages are declared we need srcImage and final softMax output as MPSImages so we can read/write to underlying textures
    // We need one for each final layer
    var srcImage, sftImage, sftImage1, sftImage2, sftImage3, sftImage4, sftImage5, sftImage6, sftImage7, sftImage8, sftImage9, sftImage10 : MPSImage
    
    
    // standard neuron and softmax layers are declared
    var relu : MPSCNNNeuronReLU
    var softmax : MPSCNNSoftMax
    
    
    
    // convolution and fully connected layers
    let conv0, conv1, conv2, conv3, conv4 : SlimMPSCNNConvolution
    let m0t0conv0, m0t1conv0, m0t1conv1, m0t2conv0, m0t2conv1, m0t2conv2, m0t3conv0 : SlimMPSCNNConvolution
    let m1t0conv0, m1t1conv0, m1t1conv1, m1t2conv0, m1t2conv1, m1t2conv2, m1t3conv0 : SlimMPSCNNConvolution
    let m2t0conv0, m2t1conv0, m2t1conv1, m2t2conv0, m2t2conv1, m2t2conv2, m2t3conv0 : SlimMPSCNNConvolution
    let m3t0conv0, m3t1conv0, m3t1conv1, m3t1conv2 : SlimMPSCNNConvolution
    let m4t0conv0, m4t1conv0, m4t1conv1, m4t1conv2, m4t2conv0, m4t2conv1, m4t2conv2, m4t2conv3, m4t2conv4, m4t3conv0 : SlimMPSCNNConvolution
    let m5t0conv0, m5t1conv0, m5t1conv1, m5t1conv2, m5t2conv0, m5t2conv1, m5t2conv2, m5t2conv3, m5t2conv4, m5t3conv0 : SlimMPSCNNConvolution
    let m6t0conv0, m6t1conv0, m6t1conv1, m6t1conv2, m6t2conv0, m6t2conv1, m6t2conv2, m6t2conv3, m6t2conv4, m6t3conv0 : SlimMPSCNNConvolution
    let m7t0conv0, m7t1conv0, m7t1conv1, m7t1conv2, m7t2conv0, m7t2conv1, m7t2conv2, m7t2conv3, m7t2conv4, m7t3conv0 : SlimMPSCNNConvolution
    let m8t0conv0, m8t0conv1, m8t1conv0, m8t1conv1, m8t1conv2, m8t1conv3 : SlimMPSCNNConvolution
    let m9t0conv0, m9t1conv0, m9t1conv1, m9t1conv2, m9t2conv0, m9t2conv1, m9t2conv2, m9t2conv3, m9t3conv0 : SlimMPSCNNConvolution
    let m10t0conv0, m10t1conv0, m10t1conv1, m10t1conv2, m10t2conv0, m10t2conv1, m10t2conv2, m10t2conv3, m10t3conv0 : SlimMPSCNNConvolution
    
    // one fully connected layer for each net in the tree
    let fc0, fc1, fc2, fc3, fc4, fc5, fc6, fc7, fc8, fc9, fc10 : SlimMPSCNNFullyConnected
    
    // pooling layers
    var mPoolinit, mPool3, mPool8, mPool10 : MPSCNNPoolingMax
    let aPool, aPoolLogits : MPSCNNPoolingAverage
    
    
    
    // MPSImageDescriptor for different mixed layer outputs
    let sid   = MPSImageDescriptor(channelFormat: textureFormat, width: 299, height: 299, featureChannels: 3)
    let inid  = MPSImageDescriptor(channelFormat: textureFormat, width: 35 , height: 35 , featureChannels: 192)
    let m0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35 , height: 35 , featureChannels: 256)
    let m1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35 , height: 35 , featureChannels: 288)
    let m2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35 , height: 35 , featureChannels: 288)
    let m3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17 , height: 17 , featureChannels: 768)
    let m4id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17 , height: 17 , featureChannels: 768)
    let m5id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17 , height: 17 , featureChannels: 768)
    let m6id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17 , height: 17 , featureChannels: 768)
    let m7id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17 , height: 17 , featureChannels: 768)
    let m8id  = MPSImageDescriptor(channelFormat: textureFormat, width: 8  , height: 8  , featureChannels: 1280)
    let m9id  = MPSImageDescriptor(channelFormat: textureFormat, width: 8  , height: 8  , featureChannels: 2048)
    let m10id = MPSImageDescriptor(channelFormat: textureFormat, width: 8  , height: 8  , featureChannels: 2048)
    let sftid0 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 20)
    let sftid1 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    let sftid2 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 3)
    let sftid3 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 3)
    let sftid4 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 3)
    let sftid5 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    let sftid6 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    let sftid7 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 4)
    let sftid8 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    let sftid9 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    let sftid10 = MPSImageDescriptor(channelFormat: textureFormat, width: 1  , height: 1  , featureChannels: 2)
    
    /**
         This function encodes all the layers of the network into given commandBuffer,
         it calls subroutines for each piece of the network
         
         - Parameters:
             - inputCommandQueue: Metal CommandQueue we got from the device to be used to do computes in future
         
         - Returns:
            Void
     */
    init(withCommandQueue inputCommandQueue : MTLCommandQueue){
        
        // keep an instance of device and commandQueue around for use
        device = inputCommandQueue.device
        commandQueue = inputCommandQueue
        
        // we will resize the input image to 299x299x3 (input size to inception_v3) size using lanczos
        lanczos = MPSImageLanczosScale(device: device)
        // we will scale pixel values to [-1,1]
        scale = MPSCNNNeuronLinear(device: device!, a: Float(2), b: Float(-1))
        
        // initialize activation layers
        relu = MPSCNNNeuronReLU(device: device!, a: 0)
        softmax = MPSCNNSoftMax(device: device!)
        

        // Initialize each MPSImage from descriptors
        srcImage    = MPSImage(device: device!, imageDescriptor: sid)
        sftImage    = MPSImage(device: device!, imageDescriptor: sftid0)
        sftImage1    = MPSImage(device: device!, imageDescriptor: sftid1)
        sftImage2    = MPSImage(device: device!, imageDescriptor: sftid2)
        sftImage3    = MPSImage(device: device!, imageDescriptor: sftid3)
        sftImage4    = MPSImage(device: device!, imageDescriptor: sftid4)
        sftImage5    = MPSImage(device: device!, imageDescriptor: sftid5)
        sftImage6    = MPSImage(device: device!, imageDescriptor: sftid6)
        sftImage7    = MPSImage(device: device!, imageDescriptor: sftid7)
        sftImage8    = MPSImage(device: device!, imageDescriptor: sftid8)
        sftImage9    = MPSImage(device: device!, imageDescriptor: sftid9)
        sftImage10    = MPSImage(device: device!, imageDescriptor: sftid10)
        
        // define convolution, pooling and fullyConnected layers and initialize them with proper weights
        // this will occur as a 1 time cost during app launch, which is beneficial to us
        conv0 = SlimMPSCNNConvolution(kernelWidth: 3,
                                      kernelHeight: 3,
                                      inputFeatureChannels: 3,
                                      outputFeatureChannels: 32,
                                      neuronFilter: relu,
                                      device: device, 
                                      kernelParamsBinaryName: "conv" ,
                                      padding: false,
                                      strideXY: (2, 2))
        
        conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                      kernelHeight: 3,
                                      inputFeatureChannels: 32,
                                      outputFeatureChannels: 32,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv_1" ,
                                      padding: false)
        
        conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                      kernelHeight: 3,
                                      inputFeatureChannels: 32,
                                      outputFeatureChannels: 64,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv_2")
        
        conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                      kernelHeight: 1,
                                      inputFeatureChannels: 64,
                                      outputFeatureChannels: 80,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv_3",
                                      padding: false)
        
        conv4 = SlimMPSCNNConvolution(kernelWidth: 3,
                                      kernelHeight: 3,
                                      inputFeatureChannels: 80,
                                      outputFeatureChannels: 192,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv_4",
                                      padding: false)
        
        mPoolinit = MPSCNNPoolingMax(device: device!, kernelWidth: 3, kernelHeight: 3, strideInPixelsX: 2, strideInPixelsY: 2)
        mPoolinit.offset = MPSOffset( x: 1, y: 1, z: 0 );
        mPoolinit.edgeMode = MPSImageEdgeMode.clamp
        
        
        //  branch1x1
        m0t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_conv")
        
        //  branch5x5
        m0t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 48,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_conv")
        
        m0t1conv1 = SlimMPSCNNConvolution(kernelWidth: 5,
                                          kernelHeight: 5,
                                          inputFeatureChannels: 48,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_conv_1",
                                          destinationFeatureChannelOffset: 64)
        
        //  branch3x3dbl
        m0t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_1_conv")
        
        m0t2conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 64,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_1_conv_1")
        
        m0t2conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 96,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_1_conv_2",
                                          destinationFeatureChannelOffset: 128)
        
        
        //  branch_pool
        m0t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 32,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_tower_2_conv",
                                          destinationFeatureChannelOffset: 224)
        
        aPool = MPSCNNPoolingAverage(device: device!, kernelWidth: 3, kernelHeight: 3, strideInPixelsX: 1, strideInPixelsY: 1)
        aPool.edgeMode = MPSImageEdgeMode.clamp
        
        //  mixed 1
        //  branch1x1
        m1t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 256,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_conv")
        
        
        //  branch5x5
        m1t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 256,
                                          outputFeatureChannels: 48,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_conv")
        
        
        m1t1conv1 = SlimMPSCNNConvolution(kernelWidth: 5,
                                          kernelHeight: 5,
                                          inputFeatureChannels: 48,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_conv_1",
                                          destinationFeatureChannelOffset: 64)
        
        //  branch3x3dbl
        m1t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 256,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_1_conv")
        
        m1t2conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 64,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_1_conv_1")
        
        m1t2conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 96,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_1_conv_2",
                                          destinationFeatureChannelOffset: 128)
        
        //  branch_pool
        m1t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 256,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_1_tower_2_conv",
                                          destinationFeatureChannelOffset: 224)
        
        
        // mixed 2
        //  branch1x1
        m2t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_conv")
        
        
        //  branch5x5
        m2t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 48,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_conv")
        
        
        m2t1conv1 = SlimMPSCNNConvolution(kernelWidth: 5,
                                          kernelHeight: 5,
                                          inputFeatureChannels: 48,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_conv_1",
                                          destinationFeatureChannelOffset: 64)
        
        //  branch3x3dbl
        m2t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_1_conv")
        
        m2t2conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 64,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_1_conv_1")
        
        m2t2conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 96,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_1_conv_2",
                                          destinationFeatureChannelOffset: 128)
        
        //  branch_pool
        m2t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_2_tower_2_conv",
                                          destinationFeatureChannelOffset: 224)
        
        
        //  mixed 3
        //  branch3x3
        m3t0conv0 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_3_conv",
                                          padding: false,
                                          strideXY: (2,2))
        
        //  branch3x3dbl
        m3t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 288,
                                          outputFeatureChannels: 64,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_3_tower_conv")
        
        m3t1conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 64,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_3_tower_conv_1")
        
        m3t1conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 96,
                                          outputFeatureChannels: 96,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_3_tower_conv_2",
                                          padding: false,
                                          strideXY: (2,2),
                                          destinationFeatureChannelOffset: 384)
        
        //  branch_pool
        mPool3 = MPSCNNPoolingMax(device: device!, kernelWidth: 3, kernelHeight: 3, strideInPixelsX: 2, strideInPixelsY: 2)
        mPool3.offset = MPSOffset( x: 1, y: 1, z: 0 );
        mPool3.edgeMode = MPSImageEdgeMode.clamp
        mPool3.destinationFeatureChannelOffset = 480
        
        
        
        
        //  mixed 4
        //  branch1x1
        m4t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_conv")
        
        //  branch7x7
        m4t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_conv")
        
        
        m4t1conv1 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_conv_1")
        
        
        m4t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_conv_2",
                                          destinationFeatureChannelOffset: 192)
        
        //  branch7x7dbl
        m4t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_1_conv")
        
        m4t2conv1 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_1_conv_1")
        
        m4t2conv2 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_1_conv_2")
        
        m4t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 128,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_1_conv_3")
        
        m4t2conv4 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 128,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_1_conv_4",
                                          destinationFeatureChannelOffset: 384)
        
        //  branch_pool
        m4t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_4_tower_2_conv",
                                          destinationFeatureChannelOffset: 576)
        
        
        //  mixed 5
        //  branch1x1
        m5t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_conv")
        
        //  branch7x7
        m5t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_conv")
        
        
        m5t1conv1 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_conv_1")
        
        
        m5t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_conv_2",
                                          destinationFeatureChannelOffset: 192)
        
        //  branch7x7dbl
        m5t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_1_conv")
        
        m5t2conv1 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_1_conv_1")
        
        m5t2conv2 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_1_conv_2")
        
        m5t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_1_conv_3")
        
        m5t2conv4 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_1_conv_4",
                                          destinationFeatureChannelOffset: 384)
        
        //  branch_pool
        m5t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_5_tower_2_conv",
                                          destinationFeatureChannelOffset: 576)
        
        
        //  mixed 6
        //  branch1x1
        m6t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_conv")
        
        //  branch7x7
        m6t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_conv")
        
        
        m6t1conv1 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_conv_1")
        
        
        m6t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_conv_2",
                                          destinationFeatureChannelOffset: 192)
        
        //  branch7x7dbl
        m6t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_1_conv")
        
        m6t2conv1 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_1_conv_1")
        
        m6t2conv2 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_1_conv_2")
        
        m6t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 160,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_1_conv_3")
        
        m6t2conv4 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 160,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_1_conv_4",
                                          destinationFeatureChannelOffset: 384)
        
        //  branch_pool
        m6t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_6_tower_2_conv",
                                          destinationFeatureChannelOffset: 576)
        
        //  mixed 7
        //  branch1x1
        m7t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_conv")
        
        //  branch7x7
        m7t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_conv")
        
        
        m7t1conv1 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_conv_1")
        
        
        m7t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_conv_2",
                                          destinationFeatureChannelOffset: 192)
        
        //  branch7x7dbl
        m7t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_1_conv")
        
        m7t2conv1 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_1_conv_1")
        
        m7t2conv2 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_1_conv_2")
        
        m7t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_1_conv_3")
        
        m7t2conv4 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_1_conv_4",
                                          destinationFeatureChannelOffset: 384)
        
        //  branch_pool
        m7t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_7_tower_2_conv",
                                          destinationFeatureChannelOffset: 576)
        
        
        //  mixed 8
        //  branch3x3
        m8t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_conv")
        
        m8t0conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 320,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_conv_1",
                                          padding: false,
                                          strideXY: (2,2))
        
        //  branch7x7x3dbl
        m8t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 768,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_1_conv")
        
        
        m8t1conv1 = SlimMPSCNNConvolution(kernelWidth: 7,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_1_conv_1")
        
        m8t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 7,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_1_conv_2")
        
        m8t1conv3 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 192,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_8_tower_1_conv_3",
                                          padding: false,
                                          strideXY: (2,2),
                                          destinationFeatureChannelOffset: 320)
        
        //  branch_pool
        mPool8 = MPSCNNPoolingMax(device: device!, kernelWidth: 3, kernelHeight: 3, strideInPixelsX: 2, strideInPixelsY: 2)
        mPool8.offset = MPSOffset( x: 1, y: 1, z: 0 );
        mPool8.destinationFeatureChannelOffset = 512
        mPool8.edgeMode = MPSImageEdgeMode.clamp
        
        //  mixed 9
        //  branch1x1
        m9t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 1280,
                                          outputFeatureChannels: 320,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_conv")
        
        //  branch5x5
        m9t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 1280,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_conv")
        
        
        m9t1conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 384,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_mixed_conv",
                                          destinationFeatureChannelOffset: 320)
        
        m9t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 384,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_mixed_conv_1",
                                          destinationFeatureChannelOffset: 704)
        
        //  branch3x3
        m9t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 1280,
                                          outputFeatureChannels: 448,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_1_conv")
        
        m9t2conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 448,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_1_conv_1")
        
        m9t2conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 384,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_1_mixed_conv",
                                          destinationFeatureChannelOffset: 1088)
        
        m9t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 3,
                                          inputFeatureChannels: 384,
                                          outputFeatureChannels: 384,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_1_mixed_conv_1",
                                          destinationFeatureChannelOffset: 1472)
        
        //  branch_pool
        m9t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                          kernelHeight: 1,
                                          inputFeatureChannels: 1280,
                                          outputFeatureChannels: 192,
                                          neuronFilter: relu,
                                          device: device,
                                          kernelParamsBinaryName: "mixed_9_tower_2_conv",
                                          destinationFeatureChannelOffset: 1856)
        
        
        
        //  mixed 10
        //  branch1x1
        m10t0conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 2048,
                                           outputFeatureChannels: 320,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_conv")
        
        //  branch5x5
        m10t1conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 2048,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_conv")
        
        
        m10t1conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 384,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_mixed_conv",
                                           destinationFeatureChannelOffset: 320)
        
        m10t1conv2 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 3,
                                           inputFeatureChannels: 384,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_mixed_conv_1",
                                           destinationFeatureChannelOffset: 704)
        
        //  branch3x3
        m10t2conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 2048,
                                           outputFeatureChannels: 448,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_1_conv")
        
        m10t2conv1 = SlimMPSCNNConvolution(kernelWidth: 3,
                                           kernelHeight: 3,
                                           inputFeatureChannels: 448,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_1_conv_1")
        
        m10t2conv2 = SlimMPSCNNConvolution(kernelWidth: 3,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 384,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_1_mixed_conv",
                                           destinationFeatureChannelOffset: 1088)
        
        m10t2conv3 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 3,
                                           inputFeatureChannels: 384,
                                           outputFeatureChannels: 384,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_1_mixed_conv_1",
                                           destinationFeatureChannelOffset: 1472)
        
        //  branch_pool
        m10t3conv0 = SlimMPSCNNConvolution(kernelWidth: 1,
                                           kernelHeight: 1,
                                           inputFeatureChannels: 2048,
                                           outputFeatureChannels: 192,
                                           neuronFilter: relu,
                                           device: device,
                                           kernelParamsBinaryName: "mixed_10_tower_2_conv",
                                           destinationFeatureChannelOffset: 1856)
        
        mPool10 = MPSCNNPoolingMax(device: device, kernelWidth: 3, kernelHeight: 3)
        mPool10.edgeMode = MPSImageEdgeMode.clamp
            
        
    

        
        // logits
        aPoolLogits = MPSCNNPoolingAverage(device: device!, kernelWidth: 8, kernelHeight: 8, strideInPixelsX: 4, strideInPixelsY: 4)
        aPoolLogits.offset = MPSOffset( x: 4, y: 4, z: 0 )
        aPoolLogits.edgeMode = MPSImageEdgeMode.clamp
        
        
        //initialization of every fully connected layer
        fc0 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 20,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops0")
        
        fc1 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops1")
        
        fc2 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 3,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops2")
        
        fc3 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 3,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops3")
    
        fc4 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 3,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops4")
        
        fc5 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops5")
        
        fc6 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops6")
        
        fc7 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 4,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops7")
        
        fc8 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops8")
        
        fc9 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops9")
        
        fc10 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 2048,
                                       outputFeatureChannels: 2,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "final_training_ops10")
        
    }
    
    

    
    /**
        This function encodes all the layers of the network into given commandBuffer, it calls subroutines for each piece of the network
            
        - Parameters:
            - commandBuffer: CommandBuffer to be used for encoding layer kernels and allocating MPSImage on
     
        - Returns:
            Void
     */
    
    // whitchNet decides what branch of the tree we are in
    func forward( commandBuffer: MTLCommandBuffer, sourceTexture : MTLTexture?, whichNet: Numbers){

        // CNN graphs usually work best if we populate MPS's internal texture cache
        // with a couple of large textures, which will then be used to back most or 
        // all of the temporary images here.  The function looks through the image
        // descriptor list and finds some representative large allocation sizes and
        // automatically prepopulates the cache to help make sure they run well. If
        // we do not do this, then the cache is populated in usuage order, which may
        // be suboptimal if the first textures are small.  This is a hint.
        //
        // In this sample code, the aggregate benefit of the use of MPSTemporaryImages
        // is to reduce the area of memory allocated to 1/4 and save about 3 ms of CPU
        // time.
        MPSTemporaryImage.prefetchStorage(with: commandBuffer, imageDescriptorList: [sid, inid, m0id, m1id, m2id, m3id, m4id, m5id, m6id, m7id, m8id, m9id, m10id])
        
        // we use preImage to hold preprocesing intermediate results
        preImage = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sid)
        
        // encode pre-processing layers to change input image to a size 299x299x3 with values in range [-1,1]
        lanczos.encode (commandBuffer: commandBuffer, sourceTexture: sourceTexture!, destinationTexture: preImage.texture)
        scale.encode(commandBuffer: commandBuffer, sourceImage: preImage, destinationImage: srcImage)
        
        // Do initial CNN layers before mixing occurs
        init_layer(commandBuffer: commandBuffer)

        // Do 11 mixing layers
        mixed_0_layer (commandBuffer: commandBuffer)
        mixed_1_layer (commandBuffer: commandBuffer)
        mixed_2_layer (commandBuffer: commandBuffer)
        mixed_3_layer (commandBuffer: commandBuffer)
        mixed_4_layer (commandBuffer: commandBuffer)
        mixed_5_layer (commandBuffer: commandBuffer)
        mixed_6_layer (commandBuffer: commandBuffer)
        mixed_7_layer (commandBuffer: commandBuffer)
        mixed_8_layer (commandBuffer: commandBuffer)
        mixed_9_layer (commandBuffer: commandBuffer)
        mixed_10_layer(commandBuffer: commandBuffer)
        
        // decide whitch final layer to use
        // find the final result from the mixing layers
        switch whichNet {
        case .zero:
            logits_layer0(commandBuffer: commandBuffer)
        case .one:
            logits_layer1(commandBuffer: commandBuffer)
        case .two:
            logits_layer2(commandBuffer: commandBuffer)
        case .three:
            logits_layer3(commandBuffer: commandBuffer)
        case .four:
            logits_layer4(commandBuffer: commandBuffer)
        case .five:
            logits_layer5(commandBuffer: commandBuffer)
        case .six:
            logits_layer6(commandBuffer: commandBuffer)
        case .seven:
            logits_layer7(commandBuffer: commandBuffer)
        case .eight:
            logits_layer8(commandBuffer: commandBuffer)
        case .nine:
            logits_layer9(commandBuffer: commandBuffer)
        case .ten:
            logits_layer10(commandBuffer: commandBuffer)
        }
    }

    
    // MPSImageDescriptor for init layers
    let c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 149, height: 149, featureChannels: 32)
    let c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 147, height: 147, featureChannels: 32)
    let c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 147, height: 147, featureChannels: 64)
    let p1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 73 , height: 73 , featureChannels: 64)
    let c3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 73 , height: 73 , featureChannels: 80)
    let c4id  = MPSImageDescriptor(channelFormat: textureFormat, width: 71 , height: 71 , featureChannels: 192)
    
    var c0Image, c1Image, c2Image, p1Image, c3Image, c4Image, initImage : MPSTemporaryImage!
    
    func init_layer(commandBuffer: MTLCommandBuffer){

        // These images are only needed in this layer and will not be read by the CPU or 
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: c0id)
        c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: c1id)
        c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: c2id)
        p1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: p1id)
        c3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: c3id)
        c4Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: c4id)
        initImage   = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: inid)

        
        // encode layers to metal commandBuffer
        conv0.encode  (commandBuffer: commandBuffer, sourceImage: srcImage  , destinationImage: c0Image)
        conv1.encode  (commandBuffer: commandBuffer, sourceImage: c0Image   , destinationImage: c1Image)
        conv2.encode  (commandBuffer: commandBuffer, sourceImage: c1Image   , destinationImage: c2Image)
        mPoolinit.encode  (commandBuffer: commandBuffer, sourceImage: c2Image   , destinationImage: p1Image)
        conv3.encode  (commandBuffer: commandBuffer, sourceImage: p1Image   , destinationImage: c3Image)
        conv4.encode  (commandBuffer: commandBuffer, sourceImage: c3Image   , destinationImage: c4Image)
        mPoolinit.encode  (commandBuffer: commandBuffer, sourceImage: c4Image   , destinationImage: initImage)

    }
    
    // MPSImageDescriptor for mixed0 layers
    //  branch5x5
    let m0t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 48)
    //  branch3x3dbl
    let m0t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 64)
    let m0t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 96)
    //  branch_pool
    let m0t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 192)
    
    var m0t1c0Image, m0t2c0Image, m0t2c1Image, m0t3p0Image, image0 : MPSTemporaryImage!
    
    func mixed_0_layer( commandBuffer: MTLCommandBuffer){
        
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        //  branch5x5
        m0t1c0Image     = MPSTemporaryImage(commandBuffer:  commandBuffer, imageDescriptor: m0t1c0id)
        //  branch3x3dbl
        m0t2c0Image     = MPSTemporaryImage(commandBuffer:  commandBuffer, imageDescriptor: m0t2c0id)
        m0t2c1Image     = MPSTemporaryImage(commandBuffer:  commandBuffer, imageDescriptor: m0t2c1id)
        //  branch_pool
        m0t3p0Image     = MPSTemporaryImage(commandBuffer:  commandBuffer, imageDescriptor: m0t3p0id)
        image0          = MPSTemporaryImage(commandBuffer:  commandBuffer, imageDescriptor: m0id)
        
 
        // MPS must be able to understand with reasonably precise timing the lifetime of the 
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit 
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter 
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages. 
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        initImage.readCount = 4

        // encode layers to metal commandBuffer
        //  branch1x1
        m0t0conv0.encode  (commandBuffer:  commandBuffer, sourceImage: initImage,      destinationImage: image0)
        //  branch5x5
        m0t1conv0.encode  (commandBuffer:  commandBuffer, sourceImage: initImage,      destinationImage: m0t1c0Image)
        m0t1conv1.encode  (commandBuffer:  commandBuffer, sourceImage: m0t1c0Image,    destinationImage: image0)
        //  branch3x3dbl
        m0t2conv0.encode  (commandBuffer:  commandBuffer, sourceImage: initImage,      destinationImage: m0t2c0Image)
        m0t2conv1.encode  (commandBuffer:  commandBuffer, sourceImage: m0t2c0Image,    destinationImage: m0t2c1Image)
        m0t2conv2.encode  (commandBuffer:  commandBuffer, sourceImage: m0t2c1Image,    destinationImage: image0)
        //  branch_pool
        aPool.encode      (commandBuffer:  commandBuffer, sourceImage: initImage,      destinationImage: m0t3p0Image)
        m0t3conv0.encode  (commandBuffer:  commandBuffer, sourceImage: m0t3p0Image,    destinationImage: image0)
    }
    
    
    
    // MPSImageDescriptor for mixed1 layers
    //  branch5x5
    let m1t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 48)
    //  branch3x3dbl
    let m1t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 64)
    let m1t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 96)
    //  branch_pool
    let m1t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 256)
    
    var m1t1c0Image, m1t2c0Image, m1t2c1Image, m1t3p0Image, image1 : MPSTemporaryImage!
    
    func mixed_1_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        //  branch5x5
        m1t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m1t1c0id)
        //  branch3x3dbl
        m1t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m1t2c0id)
        m1t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m1t2c1id)
        //  branch_pool
        m1t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m1t3p0id)
        image1          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m1id)
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image0.readCount = 4
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m1t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image0    , destinationImage: image1)
        //  branch5x5
        m1t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image0    , destinationImage: m1t1c0Image)
        m1t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m1t1c0Image, destinationImage: image1)
        //  branch3x3dbl
        m1t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image0    , destinationImage: m1t2c0Image)
        m1t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m1t2c0Image, destinationImage: m1t2c1Image)
        m1t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m1t2c1Image, destinationImage: image1)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image0    , destinationImage: m1t3p0Image)
        m1t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m1t3p0Image, destinationImage: image1)

    }
    
    
    
    
    // MPSImageDescriptor for mixed2 layers
    //  branch5x5
    let m2t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 48)
    //  branch3x3dbl
    let m2t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 64)
    let m2t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 96)
    //  branch_pool
    let m2t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 288)
    
    var m2t1c0Image, m2t2c0Image, m2t2c1Image, m2t3p0Image, image2 : MPSTemporaryImage!
    
    func mixed_2_layer(commandBuffer: MTLCommandBuffer) {
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        //  branch5x5
        m2t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m2t1c0id)
        //  branch3x3dbl
        m2t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m2t2c0id)
        m2t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m2t2c1id)
        //  branch_pool
        m2t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m2t3p0id)
        image2          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m2id)
        
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        
        image1.readCount = 4
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m2t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image1    , destinationImage: image2)
        //  branch5x5
        m2t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image1    , destinationImage: m2t1c0Image)
        m2t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m2t1c0Image, destinationImage: image2)
        //  branch3x3dbl
        m2t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image1    , destinationImage: m2t2c0Image)
        m2t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m2t2c0Image, destinationImage: m2t2c1Image)
        m2t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m2t2c1Image, destinationImage: image2)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image1    , destinationImage: m2t3p0Image)
        m2t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m2t3p0Image, destinationImage: image2)

    }
    
    
    
    
    // MPSImageDescriptor for mixed3 layers
    //  branch3x3dbl
    let m3t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 64)
    let m3t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 35, height: 35, featureChannels: 96)
    
    var m3t1c0Image, m3t1c1Image, image3 : MPSTemporaryImage!
    
    func mixed_3_layer(commandBuffer: MTLCommandBuffer) {
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        //  branch3x3dbl
        m3t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m3t1c0id)
        m3t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m3t1c1id)
        image3          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m3id)
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage three times, not once. So we must set the readCount to
        // three to make sure that the contents stay valid until the last time it is used.
        image2.readCount = 3
        
        
        // encode layers to metal commandBuffer
        //  branch3x3
        m3t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image2    , destinationImage: image3)
        //  branch3x3dbl
        m3t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image2    , destinationImage: m3t1c0Image)
        m3t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m3t1c0Image, destinationImage: m3t1c1Image)
        m3t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m3t1c1Image, destinationImage: image3)
        //  branch_pool
        mPool3.encode      (commandBuffer: commandBuffer, sourceImage: image2    , destinationImage: image3)

    }
    
    
    
    
    // MPSImageDescriptor for mixed4 layers
    //  branch7x7
    let m4t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    let m4t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    //  branch7x7dbl
    let m4t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    let m4t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    let m4t2c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    let m4t2c3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 128)
    //  branch_pool
    let m4t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 768)
    
    var m4t1c0Image, m4t1c1Image, m4t2c0Image, m4t2c1Image, m4t2c2Image, m4t2c3Image, m4t3p0Image, image4 : MPSTemporaryImage!
    
    func mixed_4_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        //  branch7x7
        m4t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t1c0id)
        m4t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t1c1id)
        //  branch7x7dbl
        m4t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t2c0id)
        m4t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t2c1id)
        m4t2c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t2c2id)
        m4t2c3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t2c3id)
        //  branch_pool
        m4t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4t3p0id)
        image4          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m4id)

        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image3.readCount = 4
        
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        
        m4t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image3    , destinationImage: image4)
        //  branch7x7
        m4t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image3    , destinationImage: m4t1c0Image)
        m4t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m4t1c0Image, destinationImage: m4t1c1Image)
        m4t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m4t1c1Image, destinationImage: image4)
        //  branch7x7dbl
        m4t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image3    , destinationImage: m4t2c0Image)
        m4t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m4t2c0Image, destinationImage: m4t2c1Image)
        m4t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m4t2c1Image, destinationImage: m4t2c2Image)
        m4t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m4t2c2Image, destinationImage: m4t2c3Image)
        m4t2conv4.encode  (commandBuffer: commandBuffer, sourceImage: m4t2c3Image, destinationImage: image4)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image3    , destinationImage: m4t3p0Image)
        m4t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m4t3p0Image, destinationImage: image4)

    }
    
    
    
    
    // MPSImageDescriptor for mixed5 layers
    //  branch5x5
    let m5t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m5t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    //  branch3x3
    let m5t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m5t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m5t2c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m5t2c3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    //  branch_pool
    let m5t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 768)
    
    var m5t1c0Image, m5t1c1Image, m5t2c0Image, m5t2c1Image, m5t2c2Image, m5t2c3Image, m5t3p0Image, image5 : MPSTemporaryImage!
    
    func mixed_5_layer(commandBuffer: MTLCommandBuffer) {
        
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        //  branch5x5
        m5t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t1c0id)
        m5t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t1c1id)
        //  branch3x3
        m5t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t2c0id)
        m5t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t2c1id)
        m5t2c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t2c2id)
        m5t2c3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t2c3id)
        //  branch_pool
        m5t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5t3p0id)
        image5          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m5id)
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image4.readCount = 4
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m5t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image4    , destinationImage: image5)
        //  branch5x5
        m5t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image4    , destinationImage: m5t1c0Image)
        m5t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m5t1c0Image, destinationImage: m5t1c1Image)
        m5t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m5t1c1Image, destinationImage: image5)
        //  branch3x3
        m5t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image4    , destinationImage: m5t2c0Image)
        m5t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m5t2c0Image, destinationImage: m5t2c1Image)
        m5t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m5t2c1Image, destinationImage: m5t2c2Image)
        m5t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m5t2c2Image, destinationImage: m5t2c3Image)
        m5t2conv4.encode  (commandBuffer: commandBuffer, sourceImage: m5t2c3Image, destinationImage: image5)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image4    , destinationImage: m5t3p0Image)
        m5t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m5t3p0Image, destinationImage: image5)
     
    }
    
    
    
    // MPSImageDescriptor for mixed6 layers
    //  branch5x5
    let m6t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m6t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    //  branch3x3
    let m6t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m6t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m6t2c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    let m6t2c3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 160)
    //  branch_pool
    let m6t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 768)
    
    var m6t1c0Image, m6t1c1Image, m6t2c0Image, m6t2c1Image, m6t2c2Image, m6t2c3Image, m6t3p0Image, image6 : MPSTemporaryImage!
    
    func mixed_6_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        //  branch5x5
        m6t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t1c0id)
        m6t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t1c1id)
        //  branch3x3
        m6t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t2c0id)
        m6t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t2c1id)
        m6t2c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t2c2id)
        m6t2c3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t2c3id)
        //  branch_pool
        m6t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6t3p0id)
        image6          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m6id)
        
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image5.readCount = 4
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m6t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image5    , destinationImage: image6)
        //  branch5x5
        m6t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image5    , destinationImage: m6t1c0Image)
        m6t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m6t1c0Image, destinationImage: m6t1c1Image)
        m6t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m6t1c1Image, destinationImage: image6)
        //  branch3x3
        m6t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image5    , destinationImage: m6t2c0Image)
        m6t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m6t2c0Image, destinationImage: m6t2c1Image)
        m6t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m6t2c1Image, destinationImage: m6t2c2Image)
        m6t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m6t2c2Image, destinationImage: m6t2c3Image)
        m6t2conv4.encode  (commandBuffer: commandBuffer, sourceImage: m6t2c3Image, destinationImage: image6)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image5    , destinationImage: m6t3p0Image)
        m6t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m6t3p0Image, destinationImage: image6)
        
    }
    
    
    
    // MPSImageDescriptor for mixed7 layers
    //  branch5x5
    let m7t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m7t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    //  branch3x3
    let m7t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m7t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m7t2c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m7t2c3id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    //  branch_pool
    let m7t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 768)
    
    var m7t1c0Image, m7t1c1Image, m7t2c0Image, m7t2c1Image, m7t2c2Image, m7t2c3Image, m7t3p0Image, image7 : MPSTemporaryImage!
    
    func mixed_7_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately

        //  branch5x5
        m7t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t1c0id)
        m7t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t1c1id)
        //  branch3x3
        m7t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t2c0id)
        m7t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t2c1id)
        m7t2c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t2c2id)
        m7t2c3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t2c3id)
        //  branch_pool
        m7t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7t3p0id)
        image7          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m7id)
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image6.readCount = 4
        
        
        // encode layers to metal commandBuffer
        // branch1x1
        m7t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image6    , destinationImage: image7)
        //  branch5x5
        m7t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image6    , destinationImage: m7t1c0Image)
        m7t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m7t1c0Image, destinationImage: m7t1c1Image)
        m7t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m7t1c1Image, destinationImage: image7)
        //  branch3x3
        m7t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image6    , destinationImage: m7t2c0Image)
        m7t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m7t2c0Image, destinationImage: m7t2c1Image)
        m7t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m7t2c1Image, destinationImage: m7t2c2Image)
        m7t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m7t2c2Image, destinationImage: m7t2c3Image)
        m7t2conv4.encode  (commandBuffer: commandBuffer, sourceImage: m7t2c3Image, destinationImage: image7)
        //  branch_pool
        aPool.encode     (commandBuffer: commandBuffer, sourceImage: image6    , destinationImage: m7t3p0Image)
        m7t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m7t3p0Image, destinationImage: image7)

    }
    
    
    
    // MPSImageDescriptor for mixed8 layers
    //  branch3x3
    let m8t0c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    //  branch7x7x3dbl
    let m8t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m8t1c1id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    let m8t1c2id  = MPSImageDescriptor(channelFormat: textureFormat, width: 17, height: 17, featureChannels: 192)
    
    var m8t0c0Image, m8t1c0Image, m8t1c1Image, m8t1c2Image, image8 : MPSTemporaryImage!

    func mixed_8_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately

        //  branch3x3
        m8t0c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m8t0c0id)
        //  branch7x7x3dbl
        m8t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m8t1c0id)
        m8t1c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m8t1c1id)
        m8t1c2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m8t1c2id)
        image8          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m8id)

        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage three times, not once. So we must set the readCount to
        // three to make sure that the contents stay valid until the last time it is used.
        image7.readCount = 3
        
        
        
        // encode layers to metal commandBuffer
        //  branch3x3
        m8t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image7    , destinationImage: m8t0c0Image)
        m8t0conv1.encode  (commandBuffer: commandBuffer, sourceImage: m8t0c0Image, destinationImage: image8)
        //  branch7x7x3dbl
        m8t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image7    , destinationImage: m8t1c0Image)
        m8t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m8t1c0Image, destinationImage: m8t1c1Image)
        m8t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m8t1c1Image, destinationImage: m8t1c2Image)
        m8t1conv3.encode  (commandBuffer: commandBuffer, sourceImage: m8t1c2Image, destinationImage: image8)
        //  branch_pool
        mPool8.encode      (commandBuffer: commandBuffer, sourceImage: image7    , destinationImage: image8)
        
    }
    
    
    
    // MPSImageDescriptor for mixed9 layers
    //  branch3x3
    let m9t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 384)
    //  branch3x3dbl
    let m9t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 448)
    let m9t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 384)
    //  branch_pool
    let m9t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 1280)
    
    var m9t1c0Image, m9t2c0Image, m9t2c1Image, m9t3p0Image, image9 : MPSTemporaryImage!
    
    func mixed_9_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately

        //  branch5x5
        m9t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m9t1c0id)
        //  branch3x3
        m9t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m9t2c0id)
        m9t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m9t2c1id)
        //  branch_pool
        m9t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m9t3p0id)
        image9          = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m9id)
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image8.readCount = 4
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m9t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image8    , destinationImage: image9)
        //  branch5x5
        m9t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image8    , destinationImage: m9t1c0Image)
        m9t1c0Image.readCount = 2
        m9t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m9t1c0Image, destinationImage: image9)
        m9t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m9t1c0Image, destinationImage: image9)
        //  branch3x3
        m9t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image8    , destinationImage: m9t2c0Image)
        m9t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m9t2c0Image, destinationImage: m9t2c1Image)
        m9t2c1Image.readCount = 2
        m9t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m9t2c1Image, destinationImage: image9)
        m9t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m9t2c1Image, destinationImage: image9)
        //  branch_pool
        aPool.encode      (commandBuffer: commandBuffer, sourceImage: image8    , destinationImage: m9t3p0Image)
        m9t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m9t3p0Image, destinationImage: image9)
        
    }
    
    
    
    // MPSImageDescriptor for mixed10 layers
    //  branch3x3
    let m10t1c0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 384)
    //  branch3x3dbl
    let m10t2c0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 448)
    let m10t2c1id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 384)
    //  branch_pool
    let m10t3p0id  = MPSImageDescriptor(channelFormat: textureFormat, width:  8, height:  8, featureChannels: 2048)
    
    var m10t1c0Image, m10t2c0Image, m10t2c1Image, m10t3p0Image, image10 : MPSTemporaryImage!
    
    func mixed_10_layer(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        //  branch5x5
        m10t1c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m10t1c0id)
        //  branch3x3
        m10t2c0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m10t2c0id)
        m10t2c1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m10t2c1id)
        //  branch_pool
        m10t3p0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m10t3p0id)
        image10           = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: m10id)
        
        
        // MPS must be able to understand with reasonably precise timing the lifetime of the
        // MPSTemporaryImage in the command buffer. The pixel storage for the MPSTemporaryImage
        // is not allocated until it is first used (or the .texture property is invoked) and
        // the storage is promptly returned for reuse after last use.  Since ARC can be a bit
        // tardy about releasing the object, the MPSTemporaryImage makes use of a read counter
        // to track its lifetime. The read counter tells MPS how many times the MPSTemporaryImage
        // will be read (by a MPS -encode method) before its backing store can be reclaimed for
        // reuse.  By default, the read count is 1, meaning that the contents of the MPSTemporaryImage
        // are written to the image any number of times (but typically once, since more would be
        // wasteful), then read once. After it is read once, the -encode call will automatically
        // return the storage for use by other MPSTemporaryImages.
        //
        // In the case, the layer reads initImage four times, not once. So we must set the readCount to
        // four to make sure that the contents stay valid until the last time it is used.
        image9.readCount = 4
        
        
        
        // encode layers to metal commandBuffer
        //  branch1x1
        m10t0conv0.encode  (commandBuffer: commandBuffer, sourceImage: image9     , destinationImage: image10)
        //  branch5x5
        m10t1conv0.encode  (commandBuffer: commandBuffer, sourceImage: image9     , destinationImage: m10t1c0Image)
        m10t1c0Image.readCount = 2
        m10t1conv1.encode  (commandBuffer: commandBuffer, sourceImage: m10t1c0Image, destinationImage: image10)
        m10t1conv2.encode  (commandBuffer: commandBuffer, sourceImage: m10t1c0Image, destinationImage: image10)
        //  branch3x3
        m10t2conv0.encode  (commandBuffer: commandBuffer, sourceImage: image9     , destinationImage: m10t2c0Image)
        m10t2conv1.encode  (commandBuffer: commandBuffer, sourceImage: m10t2c0Image, destinationImage: m10t2c1Image)
        m10t2c1Image.readCount = 2
        m10t2conv2.encode  (commandBuffer: commandBuffer, sourceImage: m10t2c1Image, destinationImage: image10)
        m10t2conv3.encode  (commandBuffer: commandBuffer, sourceImage: m10t2c1Image, destinationImage: image10)
        //  branch_pool
        mPool10.encode       (commandBuffer: commandBuffer, sourceImage: image9     , destinationImage: m10t3p0Image)
        m10t3conv0.encode  (commandBuffer: commandBuffer, sourceImage: m10t3p0Image, destinationImage: image10)
        
    }
    
    
    
    // MPSImageDescriptor for final logits generating layers
    let fp0id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp0Image, fc0Image : MPSTemporaryImage!
    
    func logits_layer0(commandBuffer: MTLCommandBuffer){
        // These images are only needed in this layer and will not be read by the CPU or
        // outside of the command bufer, so we can allocate them as MPSTemporaryImages and
        // save the CPU cost and memory size of allocating reserved storage for them.
        //
        // These objects can not be reused outside of the command buffer, which is why
        // we did not make them in the init(withDevice:commandQueue:) call.
        //
        // Temporary images are designed to be efficiently created as needed, used a few times
        // and thrown away almost immediately
        
        
        fp0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp0id)
        fc0Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid0)

        
        // encode layers to metal commandBuffer
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp0Image)
        fc0.encode    (commandBuffer: commandBuffer, sourceImage: fp0Image, destinationImage: fc0Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc0Image, destinationImage: sftImage)
        
    }

    let fp1id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp1Image, fc1Image : MPSTemporaryImage!
    
    func logits_layer1(commandBuffer: MTLCommandBuffer){
        
        fp1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp1id)
        fc1Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid1)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp1Image)
        fc1.encode    (commandBuffer: commandBuffer, sourceImage: fp1Image, destinationImage: fc1Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc1Image, destinationImage: sftImage1)
        
    }
    
    let fp2id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp2Image, fc2Image : MPSTemporaryImage!
    
    func logits_layer2(commandBuffer: MTLCommandBuffer){
        
        fp2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp2id)
        fc2Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid2)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp2Image)
        fc2.encode    (commandBuffer: commandBuffer, sourceImage: fp2Image, destinationImage: fc2Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc2Image, destinationImage: sftImage2)
        
    }
    
    let fp3id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp3Image, fc3Image : MPSTemporaryImage!
    
    func logits_layer3(commandBuffer: MTLCommandBuffer){
        
        fp3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp3id)
        fc3Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid3)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp3Image)
        fc3.encode    (commandBuffer: commandBuffer, sourceImage: fp3Image, destinationImage: fc3Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc3Image, destinationImage: sftImage3)
        
    }
    
    let fp4id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp4Image, fc4Image : MPSTemporaryImage!
    
    func logits_layer4(commandBuffer: MTLCommandBuffer){
        
        fp4Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp1id)
        fc4Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid4)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp4Image)
        fc4.encode    (commandBuffer: commandBuffer, sourceImage: fp4Image, destinationImage: fc4Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc4Image, destinationImage: sftImage4)
        
    }
    
    let fp5id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp5Image, fc5Image : MPSTemporaryImage!
    
    func logits_layer5(commandBuffer: MTLCommandBuffer){
        
        fp5Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp5id)
        fc5Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid5)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp5Image)
        fc5.encode    (commandBuffer: commandBuffer, sourceImage: fp5Image, destinationImage: fc5Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc5Image, destinationImage: sftImage5)
        
    }
    
    let fp6id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp6Image, fc6Image : MPSTemporaryImage!
    
    func logits_layer6(commandBuffer: MTLCommandBuffer){
        
        fp6Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp6id)
        fc6Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid6)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp6Image)
        fc6.encode    (commandBuffer: commandBuffer, sourceImage: fp6Image, destinationImage: fc6Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc6Image, destinationImage: sftImage6)
        
    }

    let fp7id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp7Image, fc7Image : MPSTemporaryImage!
    
    func logits_layer7(commandBuffer: MTLCommandBuffer){
        
        fp7Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp7id)
        fc7Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid7)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp7Image)
        fc7.encode    (commandBuffer: commandBuffer, sourceImage: fp7Image, destinationImage: fc7Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc7Image, destinationImage: sftImage7)
        
    }
    
    let fp8id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp8Image, fc8Image : MPSTemporaryImage!
    
    func logits_layer8(commandBuffer: MTLCommandBuffer){
        
        fp8Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp8id)
        fc8Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid8)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp8Image)
        fc8.encode    (commandBuffer: commandBuffer, sourceImage: fp8Image, destinationImage: fc8Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc8Image, destinationImage: sftImage8)
        
    }
    
    let fp9id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp9Image, fc9Image : MPSTemporaryImage!
    
    func logits_layer9(commandBuffer: MTLCommandBuffer){
        
        fp9Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp9id)
        fc9Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid9)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp9Image)
        fc9.encode    (commandBuffer: commandBuffer, sourceImage: fp9Image, destinationImage: fc9Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc9Image, destinationImage: sftImage9)
        
    }

    let fp10id = MPSImageDescriptor(channelFormat: textureFormat, width: 1, height: 1, featureChannels: 2048)
    
    var fp10Image, fc10Image : MPSTemporaryImage!
    
    func logits_layer10(commandBuffer: MTLCommandBuffer){
        
        fp10Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: fp10id)
        fc10Image     = MPSTemporaryImage(commandBuffer: commandBuffer, imageDescriptor: sftid10)
        
        aPoolLogits.encode  (commandBuffer: commandBuffer, sourceImage: image10,  destinationImage: fp10Image)
        fc10.encode    (commandBuffer: commandBuffer, sourceImage: fp10Image, destinationImage: fc10Image)
        softmax.encode(commandBuffer: commandBuffer, sourceImage: fc10Image, destinationImage: sftImage10)
        
    }

    /**
         This function reads the output probabilities from sftImage to CPU, sorts them and gets the label with the top probability
     
         - Returns:
            A string
     */
    
    // whitchNet decides what branch of the tree we are in
    func getLabel(whichNet: Numbers)->String{
        //sftImage = fc0Image
        // gather measurements of MPSImage to use to get out probabilities
        
        var sftImage: MPSImage
        
        switch whichNet {
        case .zero:
            sftImage = self.sftImage
        case .one:
            sftImage = self.sftImage1
        case .two:
            sftImage = self.sftImage2
        case .three:
            sftImage = self.sftImage3
        case .four:
            sftImage = self.sftImage4
        case .five:
            sftImage = self.sftImage5
        case .six:
            sftImage = self.sftImage6
        case .seven:
            sftImage = self.sftImage7
        case .eight:
            sftImage = self.sftImage8
        case .nine:
            sftImage = self.sftImage9
        case .ten:
            sftImage = self.sftImage10
        }
        
        let width = sftImage.width
        let height = sftImage.height
        let numSlices = (sftImage.featureChannels + 3)/4;
        let count = sftImage.texture.width*sftImage.texture.height*sftImage.featureChannels
        let channelsPerSlice = 4 // textures are in RGBA format
        
        var output = [UInt16](repeating: 3 , count: count)
        var outputF = [Float](repeating: 0.6 , count: count)
        
        // get probabilities of each label in UIn16 array we use this to contain float16s
        for i in 0..<numSlices {
            sftImage.texture.getBytes(&(output[height*width*channelsPerSlice*i]),
                                      bytesPerRow: MemoryLayout<UInt16>.size*width*channelsPerSlice,
                                      bytesPerImage: 0,
                                      from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                                      size: MTLSize(width: width, height: height, depth: 1)),
                                      mipmapLevel: 0,
                                      slice: i)
        }
        
        // use VImage to convert Float16 to Float32 so we can use them
        var fullResultVImagebuf = vImage_Buffer(data: &outputF, height: 1, width: UInt(count), rowBytes: count*4)
        var halfResultVImagebuf = vImage_Buffer(data: &output, height: 1, width: UInt(count), rowBytes: count*2)
        
        if(vImageConvert_Planar16FtoPlanarF(&halfResultVImagebuf, &fullResultVImagebuf, 0) != kvImageNoError){
            print("Error in vImage")
        }
        
        // copy output probabilities into an array of touples of (probability, index)
        var indexedProbabilities = [(Float, Int)]()
        for i in 0..<outputF.count{
            indexedProbabilities.append((outputF[i], i))
        }
        
        // sort the touple array to have top guesses in the front
        indexedProbabilities.sort { (a: (prob: Float, _: Int), b: (prob: Float, _: Int)) -> Bool in
            return a.prob > b.prob
        }
        
        // get top valid guess
        let (_, index) = indexedProbabilities[0]
        var returnString = ""
        
        switch whichNet {
        case .zero:
            returnString = labels0[index]
        case .one:
            returnString = labels1[index]
        case .two:
            returnString = labels2[index]
        case .three:
            returnString = labels3[index]
        case .four:
            returnString = labels4[index]
        case .five:
            returnString = labels5[index]
        case .six:
            returnString = labels6[index]
        case .seven:
            returnString = labels7[index]
        case .eight:
            returnString = labels8[index]
        case .nine:
            returnString = labels9[index]
        case .ten:
            returnString = labels10[index]
        }
        
        returnString = returnString.replacingOccurrences(of: "_", with: " ")
        
        return returnString
        
    }
    
    //class labels
    let labels0 = [
                FishSpecies.betta_splendens.rawValue,
                FishSpecies.carnegiella_strigata.rawValue,
                FishSpecies.celestichthys_margaritatus.rawValue,
                "fekete",
                "harcsa",
                "hazmester",
                "hosszanti",
                FishSpecies.labeo_bicolor.rawValue,
                FishSpecies.melanochromis_cyaneorhabdos.rawValue,
                FishSpecies.melanotaenia_boesemani.rawValue,
                FishSpecies.mikrogeophagus_ramirezi.rawValue,
                FishSpecies.neolamprologus_buescheri_kamakonde.rawValue,
                "neon",
                FishSpecies.osteoglossum_bicirrhosum.rawValue,
                "oves",
                "piros",
                "pirospotty",
                FishSpecies.rocio_octofasciata.rawValue,
                "sarga",
                "tetra"]
    
    let labels1 = [
                FishSpecies.apteronotus_albifrons.rawValue,
                FishSpecies.poecilia_sphenops.rawValue]
    
    let labels2 = [
                FishSpecies.ctenopoma_acutirostre.rawValue,
                FishSpecies.hoplosternum_thoracatum.rawValue,
                FishSpecies.synodontis_petricola.rawValue]
    
    let labels3 = [
                FishSpecies.corydoras_aeneus.rawValue,
                FishSpecies.corydoras_duplicareus.rawValue,
                FishSpecies.corydoras_paleatus.rawValue]
    
    let labels4 = [
                FishSpecies.crossocheilus_oblongus.rawValue,
                FishSpecies.hyphessobrycon_herbertaxelrodi.rawValue,
                FishSpecies.tanichthys_albonubes.rawValue]
    
    let labels5 = [
                FishSpecies.paracheirodon_axelrodi.rawValue,
                FishSpecies.paracheirodon_innesi.rawValue]
    
    let labels6 = [
                FishSpecies.chromobotia_macracanthus.rawValue,
                FishSpecies.puntigrus_tetrazona.rawValue]
    
    let labels7 = [
                FishSpecies.goldfish.rawValue,
                FishSpecies.hyphessobrycon_amandae.rawValue,
                FishSpecies.pethia_conchonius.rawValue,
                FishSpecies.xiphophorus_helleri.rawValue]
    
    let labels8 = [
                FishSpecies.hyphessobrycon_pulchripinnis.rawValue,
                FishSpecies.petitella_georgiae.rawValue]
    
    let labels9 = [
                FishSpecies.labidochromis_caeruleus.rawValue,
                FishSpecies.tropheus_ikola.rawValue]

    let labels10 = [
                FishSpecies.gymnocorymbus_ternetzi.rawValue,
                FishSpecies.hyphessobrycon_megalopterus.rawValue]
    
}
