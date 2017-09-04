//
//  FishPredictor.swift
//  FishScanner
//
//  Created by Németh Bendegúz on 2017. 08. 30..
//  Copyright © 2017. Németh Bendegúz. All rights reserved.
//

import MetalKit

struct FishPredictor {
    
    static func createSourceTexture(from image: UIImage, with ciContext: CIContext, and textureLoader: MTKTextureLoader) throws -> MTLTexture? {
        
        // use CGImage property of UIImage
        var cgImg = image.cgImage
        
        // check to see if cgImg is valid if nil, UIImg is CIImage based and we need to go through that
        // this shouldn't be the case
        if(cgImg == nil){
            // our underlying format was CIImage
            var ciImg = image.ciImage
            if(ciImg == nil){
                // this should never be needed but if for some reason both formats fail, we create a CIImage
                // change UIImage to CIImage
                ciImg = CIImage(image: image)
            }
            // use CIContext to get a CGImage
            cgImg = ciContext.createCGImage(ciImg!, from: ciImg!.extent)
        }
        
        // get a texture from this CGImage
        return try textureLoader.newTexture(with: cgImg!, options: [:])
        
    }
    
    static func runNetwork(_ Net: Inception3Net,with sourceTexture: MTLTexture, and commandQueue: MTLCommandQueue) -> String {
        // encoding command buffers
        let commandBuffer0 = commandQueue.makeCommandBuffer()
        let commandBuffer1 = commandQueue.makeCommandBuffer()
        
        // encode all layers of network on present commandBuffer, pass in the input image MTLTexture
        Net.forward(commandBuffer: commandBuffer0, sourceTexture: sourceTexture, whichNet: .zero)
        
        // commit the commandBuffer and wait for completion on CPU
        commandBuffer0.commit()
        commandBuffer0.waitUntilCompleted()
        
        // prediction for what group
        let firstPrediction = Net.getLabel(whichNet: .zero)
        
        func makeSecondPrediction(with whichNet: Numbers) -> String {
            Net.forward(commandBuffer: commandBuffer1, sourceTexture: sourceTexture, whichNet: whichNet)
            
            commandBuffer1.commit()
            commandBuffer1.waitUntilCompleted()
            
            let label = Net.getLabel(whichNet: whichNet)
            return label
        }
        
        switch firstPrediction {
        case "betta splendens", "carnegiella strigata", "celestichthys margaritatus", "labeo bicolor", "melanochromis cyaneorhabdos", "melanotaenia boesemani", "mikrogeophagus ramirezi", "neolamprologus buescheri kamakonde", "osteoglossum bicirrhosum", "rocio octofasciata":
            return firstPrediction
        case "fekete":
            return makeSecondPrediction(with: .one)
        case "harcsa":
            return makeSecondPrediction(with: .two)
        case "hazmester":
            return makeSecondPrediction(with: .three)
        case "hosszanti":
            return makeSecondPrediction(with: .four)
        case "neon":
            return makeSecondPrediction(with: .five)
        case "oves":
            return makeSecondPrediction(with: .six)
        case "piros":
            return makeSecondPrediction(with: .seven)
        case "pirospotty":
            return makeSecondPrediction(with: .eight)
        case "sarga":
            return makeSecondPrediction(with: .nine)
        case "tetra":
            return makeSecondPrediction(with: .ten)
        default:
            return ""
        }
    }
}






