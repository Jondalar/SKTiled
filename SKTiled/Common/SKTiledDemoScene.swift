//
//  SKTiledDemoScene.swift
//  SKTiled
//
//  Created by Michael Fessenden on 3/21/16.
//  Copyright (c) 2016 Michael Fessenden. All rights reserved.
//


import SpriteKit


public class SKTiledDemoScene: SKTiledScene {
    
    open var uiScale: CGFloat = 1
    public var debugMode: Bool = false
    
    // ui controls
    public var resetButton: ButtonNode!
    public var drawButton:  ButtonNode!
    public var nextButton:  ButtonNode!
    
    // debugging labels
    public var tilemapInformation: SKLabelNode!
    public var tileInformation: SKLabelNode!
    public var propertiesInformation: SKLabelNode!
    
    /// global information label font size.
    private let labelFontSize: CGFloat = 11
    
    override public func didMove(to view: SKView) {
        super.didMove(to: view)
        
        #if os(OSX)
        // add mouse tracking for OSX
        let options = [NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeAlways] as NSTrackingAreaOptions
        let trackingArea = NSTrackingArea(rect: view.frame, options: options, owner: self, userInfo: nil)
        view.addTrackingArea(trackingArea)
        #endif
        
        // setup demo UI
        setupDemoUI()
        setupDebuggingLabels()
        updateHud()
    }
    
    // MARK: - Setup
    /**
     Set up interface elements for this demo.
     */
    open func setupDemoUI() {
        guard let view = self.view else { return }

        // set up camera overlay UI
        let lastZPosition: CGFloat = (tilemap != nil) ? tilemap.lastZPosition * 10 : 5000

        if (resetButton == nil){
            resetButton = ButtonNode(defaultImage: "reset-button-norm", highlightImage: "reset-button-pressed", action: {
                if let cameraNode = self.cameraNode {
                    cameraNode.resetCamera()
                }
            })
            cameraNode.addChild(resetButton)
            // position towards the bottom of the scene
            resetButton.position.x -= (view.bounds.size.width / 7)
            resetButton.position.y -= (view.bounds.size.height / 2.25)
            resetButton.zPosition = lastZPosition
        }
        
        if (drawButton == nil){
            drawButton = ButtonNode(defaultImage: "draw-button-norm", highlightImage: "draw-button-pressed", action: {
                guard let tilemap = self.tilemap else { return }
                let debugState = !tilemap.debugDraw
                tilemap.debugDraw = debugState
                
                if (debugState == true){
                    tilemap.debugLayers()
                }
            })
            
            cameraNode.addChild(drawButton)
            // position towards the bottom of the scene
            drawButton.position.y -= (view.bounds.size.height / 2.25)
            drawButton.zPosition = lastZPosition
        }
        
        if (nextButton == nil){
            nextButton = ButtonNode(defaultImage: "next-button-norm", highlightImage: "next-button-pressed", action: {
                self.loadNextScene()
            })
            cameraNode.addChild(nextButton)
            // position towards the bottom of the scene
            nextButton.position.x += (view.bounds.size.width / 7)
            nextButton.position.y -= (view.bounds.size.height / 2.25)
            nextButton.zPosition = lastZPosition
        }
    }
    
    /**
     Setup debugging labels.
     */
    public func setupDebuggingLabels() {
        guard let view = self.view else { return }
        guard let cameraNode = cameraNode else { return }
        
        var tilemapInfoY: CGFloat = 0.77
        var tileInfoY: CGFloat = 0.81
        var propertiesInfoY: CGFloat = 0.85
        
        #if os(iOS)
        tilemapInfoY = 1.0 - tilemapInfoY
        tileInfoY = 1.0 - tileInfoY
        propertiesInfoY = 1.0 - propertiesInfoY
        #endif
        
        if (tilemapInformation == nil){
            // setup tilemap label
            tilemapInformation = SKLabelNode(fontNamed: "Courier")
            tilemapInformation.fontSize = labelFontSize
            tilemapInformation.text = "Tilemap:"
            cameraNode.addChild(tilemapInformation)
        }
        
        if (tileInformation == nil){
            // setup tile information label
            tileInformation = SKLabelNode(fontNamed: "Courier")
            tileInformation.fontSize = labelFontSize
            tileInformation.text = "Tile:"
            cameraNode.addChild(tileInformation)
        }
        
        if (propertiesInformation == nil){
            // setup tile information label
            propertiesInformation = SKLabelNode(fontNamed: "Courier")
            propertiesInformation.fontSize = labelFontSize
            cameraNode.addChild(propertiesInformation)
        }
        
        tilemapInformation.posByCanvas(x: 0.5, y: tilemapInfoY)
        
        tileInformation.isHidden = true
        tileInformation.posByCanvas(x: 0.5, y: tileInfoY)
        
        propertiesInformation.isHidden = false
        propertiesInformation.posByCanvas(x: 0.5, y: propertiesInfoY)
    }
    
    /**
     Add a tile shape to a layer at the given coordinate.
     
     - parameter layer:     `TiledLayerObject` layer object.
     - parameter x:         `Int` x-coordinate.
     - parameter y:         `Int` y-coordinate.
     - parameter duration:  `TimeInterval` tile life.
     */
    func addTileAt(layer: TiledLayerObject, _ x: Int, _ y: Int, duration: TimeInterval=0) -> DebugTileShape {
        // validate the coordinate
        let validCoord = layer.isValid(x, y)
        let tileColor: SKColor = (validCoord == true) ? tilemap.highlightColor : TiledColors.red.color
        
        let lastZosition = tilemap.lastZPosition + (tilemap.zDeltaForLayers * 2)
        
        // add debug tile shape
        let tile = DebugTileShape(layer: layer, tileColor: tileColor)
        tile.zPosition = lastZosition
        tile.position = layer.pointForCoordinate(x, y)
        layer.addChild(tile)
        if (duration > 0) {
            let fadeAction = SKAction.fadeAlpha(to: 0, duration: duration)
            tile.run(fadeAction, completion: {
                tile.removeFromParent()
            })
        }
        return tile
    }
    
    /**
     Call back to the GameViewController to load the next scene.
     */
    open func loadNextScene() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "loadNextScene"), object: nil)
    }
    

    override open func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        var dynamicScale = size.width / 400
        let remainder = dynamicScale.truncatingRemainder(dividingBy: 2)
        dynamicScale = dynamicScale - remainder
        uiScale = dynamicScale >= 1 ? dynamicScale : 1
    
        updateHud()
        
        #if os(OSX)
        if let view = self.view {
            let options = [NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeAlways] as NSTrackingAreaOptions
            // clear out old tracking areas
            for oldTrackingArea in view.trackingAreas {
                view.removeTrackingArea(oldTrackingArea)
            }
            
            let trackingArea = NSTrackingArea(rect: view.frame, options: options, owner: self, userInfo: nil)
            view.addTrackingArea(trackingArea)
        }
        #endif
    }
    
    private func buttonNodes() -> [ButtonNode] {
        var buttons: [ButtonNode] = []
        enumerateChildNodes(withName: "//*", using: {node, _ in
            if let button = node as? ButtonNode {
                if button.isHidden == false {
                    buttons.append(button)
                }
            }
        })
        return buttons
    }
    
    open func isValidPosition(point: CGPoint) -> Bool {
        let nodesUnderCursor = nodes(at: point)
        for node in nodesUnderCursor {
            if let _ = node as? ButtonNode {
                return false
            }
        }
        return true
    }


    /**
     Update HUD elements when the view size changes.
     */
    private func updateHud(){
        guard let view = self.view else { return }
        
        let lastZPosition: CGFloat = (tilemap != nil) ? tilemap.lastZPosition * 10 : 5000
        
        let viewSize = view.bounds.size
        let buttonYPos: CGFloat = -(size.height * 0.4)

        let buttons = buttonNodes()
        buttons.forEach {$0.setScale(uiScale)}
        buttons.forEach {$0.zPosition = lastZPosition * 2}
        
        var tilemapInfoY: CGFloat = 0.77
        var tileInfoY: CGFloat = 0.81
        var propertiesInfoY: CGFloat = 0.85
        
        #if os(iOS)
        tilemapInfoY = 1.0 - tilemapInfoY
        tileInfoY = 1.0 - tileInfoY
        propertiesInfoY = 1.0 - propertiesInfoY
        #endif
        
        let buttonWidths = buttons.map { $0.size.width }
        let maxWidth = buttonWidths.reduce(0, {$0 + $1})
        let spacing = (viewSize.width - maxWidth) / CGFloat(buttons.count + 1)
        
        var current = spacing + (buttonWidths[0] / 2)
        for button in buttons {
            let buttonScenePos = CGPoint(x: current - (viewSize.width / 2), y: buttonYPos)
            button.position = buttonScenePos
            button.zPosition = lastZPosition
            current += spacing + button.size.width
        }
        
        let dynamicFontSize = labelFontSize * (size.width / 600)

        // Update information labels
        if let tilemapInformation = tilemapInformation {
            tilemapInformation.fontSize = dynamicFontSize
            tilemapInformation.zPosition = lastZPosition
            tilemapInformation.posByCanvas(x: 0.5, y: tilemapInfoY)
            tilemapInformation.text = tilemap?.description
        }
        
        if let tileInformation = tileInformation {
            tileInformation.fontSize = dynamicFontSize
            tileInformation.zPosition = lastZPosition
            tileInformation.posByCanvas(x: 0.5, y: tileInfoY)
        }
        
        if let propertiesInformation = propertiesInformation {
            propertiesInformation.fontSize = dynamicFontSize
            propertiesInformation.zPosition = lastZPosition
            propertiesInformation.posByCanvas(x: 0.5, y: propertiesInfoY)
        }
    }
}


public extension SKNode {
    
    /**
     Position the node by a percentage of the view size.
    */
    public func posByCanvas(x: CGFloat, y: CGFloat) {
        guard let scene = scene else { return }
        guard let view = scene.view else { return }
        self.position = scene.convertPoint(fromView: (CGPoint(x: CGFloat(view.bounds.size.width * x), y: CGFloat(view.bounds.size.height * (1.0 - y)))))
    }
}


#if os(iOS) || os(tvOS)
// Touch-based event handling
extension SKTiledDemoScene {
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tilemap = tilemap else { return }
        let baseLayer = tilemap.baseLayer
        
        for touch in touches {
            
            // make sure there are no UI objects under the mouse
            let scenePosition = touch.location(in: self)
            if !isValidPosition(point: scenePosition) { return }
            
            // get the position in the baseLayer
            let positionInLayer = baseLayer.touchLocation(touch)
            let coord = baseLayer.coordinateAtTouchLocation(touch)
            // add a tile shape to the base layer where the user has clicked
            
            // highlight the current coordinate
            let _ = addTileAt(layer: baseLayer, Int(coord.x), Int(coord.y), duration: 5)
            
            // update the tile information label
            var coordStr = "Tile: \(coord.coordDescription), \(positionInLayer.roundTo())"
            tileInformation.isHidden = false
            tileInformation.text = coordStr
            
            // tile properties output
            propertiesInformation.text = ""
            if let tile = tilemap.firstTileAt(coord) {
                var tileInfoString = "Tile id: \(tile.tileData.id)"
                
                if tile.tileData.propertiesString != "" {
                    tileInfoString += ": \(tile.tileData.propertiesString)"
                    propertiesInformation.text = tileInfoString
                }
            }
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // do something here
        }
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // do something here
        }
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // do something here
        }
    }
}
#endif


#if os(OSX)
// Mouse-based event handling
extension SKTiledDemoScene {
        
    override open func mouseDown(with event: NSEvent) {
        guard let tilemap = tilemap else { return }
        guard let cameraNode = cameraNode else { return }
        cameraNode.mouseDown(with: event)
        
        let baseLayer = tilemap.baseLayer
        
        // make sure there are no UI objects under the mouse
        let scenePosition = event.location(in: self)
        if !isValidPosition(point: scenePosition) { return }
        
        // get the position in the baseLayer
        let positionInLayer = baseLayer.mouseLocation(event: event)
        let coord = baseLayer.coordinateAtMouseEvent(event: event)
        
        // highlight the current coordinate
        let _ = addTileAt(layer: baseLayer, Int(coord.x), Int(coord.y), duration: 5)

        // update the tile information label
        let coordStr = "Tile: \(coord.coordDescription), \(positionInLayer.roundTo())"
        tileInformation.isHidden = false
        tileInformation.text = coordStr
        
        // tile properties output
        propertiesInformation.text = ""
        if let tile = tilemap.firstTileAt(coord) {
            var tileInfoString = "Tile id: \(tile.tileData.id)"
            
            if tile.tileData.propertiesString != "" {
                tileInfoString += ": \(tile.tileData.propertiesString)"
                propertiesInformation.text = tileInfoString
            }
        }
    }
    
    override open func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        updateTrackingViews()
        
        guard let tilemap = tilemap else { return }
        let baseLayer = tilemap.baseLayer
        
        // make sure there are no UI objects under the mouse
        let scenePosition = event.location(in: self)
        if !isValidPosition(point: scenePosition) { return }
        
        // get the position in the baseLayer (inverted)
        let positionInLayer = baseLayer.mouseLocation(event: event)
        let coord = baseLayer.screenToTileCoords(positionInLayer)
        
        tileInformation?.isHidden = false
        tileInformation?.text = "Tile: \(coord.coordDescription), \(positionInLayer.roundTo())"
        
        // highlight the current coordinate
        let _ = addTileAt(layer: baseLayer, Int(coord.x), Int(coord.y), duration: 0.05)
        
        // tile properties output
        propertiesInformation.text = ""
        if let tile = tilemap.firstTileAt(coord) {
            var tileInfoString = "Tile id: \(tile.tileData.id)"
            
            if tile.tileData.propertiesString != "" {
                tileInfoString += ": \(tile.tileData.propertiesString)"
                propertiesInformation.text = tileInfoString
            }
        }
    }
    
    override open func mouseDragged(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        cameraNode.scenePositionChanged(event)
    }
    
    override open func mouseUp(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        cameraNode.mouseUp(with: event)
    }
    
    override open func scrollWheel(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        cameraNode.scrollWheel(with: event)
    }
    
    override open func keyDown(with event: NSEvent) {
        guard let cameraNode = cameraNode else { return }
        if event.keyCode == 0x00 || event.keyCode == 0x52 || event.keyCode == 0x1D {
            if let tilemap = tilemap {
                cameraNode.resetCamera(toScale: tilemap.worldScale)
            } else {
                cameraNode.resetCamera()
            }
        }
    }
    
    /**
     Remove old tracking views and add the current.
    */
    open func updateTrackingViews(){
        if let view = self.view {
            let options = [NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeAlways] as NSTrackingAreaOptions
            // clear out old tracking areas
            for oldTrackingArea in view.trackingAreas {
                view.removeTrackingArea(oldTrackingArea)
            }
            
            let trackingArea = NSTrackingArea(rect: view.frame, options: options, owner: self, userInfo: nil)
            view.addTrackingArea(trackingArea)
        }
    }
}
#endif


