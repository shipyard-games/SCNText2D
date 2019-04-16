//
//  GameViewController.swift
//  SCNText2D-macOSTestApp
//
//  Created by Teemu Harju on 10/02/2019.
//

import SceneKit
import QuartzCore

import SCNText2D

class GameViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene()
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = NSColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)

        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = NSColor.black
        
        let text =
        """
        It is a period of civil war.
        Rebel spaceships, striking
        from a hidden base, have won
        their first victory against
        the evil Galactic Empire.

        During the battle, Rebel
        spies managed to steal secret
        plans to the Empire's
        ultimate weapon, the DEATH
        STAR, an armored space
        station with enough power to
        destroy an entire planet.

        Pursued by the Empire's
        sinister agents, Princess
        Leia races home aboard her
        starship, custodian of the
        stolen plans that can save
        her people and restore
        freedom to the galaxy.....
        """
        
        let textGeometry = SCNText2D.create(from: text, withFontNamed: "OpenSans-Regular")

        let node = SCNNode()
        node.eulerAngles.x += -35.0 * (180.0 / .pi)
        
        
        let textNode = SCNNode()
        textNode.geometry = textGeometry
        
        let moveAction = SCNAction.move(by: SCNVector3(x:0, y: 200.0, z: 0.0), duration: 240.0)
        textNode.runAction(moveAction)

        node.addChildNode(textNode)
        
        scene.rootNode.addChildNode(node)
    }
}
