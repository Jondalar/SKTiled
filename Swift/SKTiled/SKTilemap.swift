//
//  SKTilemap.swift
//  SKTilemap
//
//  Created by Michael Fessenden on 3/21/16.
//  Copyright © 2016 Michael Fessenden. All rights reserved.
//

import SpriteKit


public enum TiledColors: String {
    case white  =  "#f7f5ef"
    case grey   =  "#969696"
    case red    =  "#990000"
    case blue   =  "#86b9e3"
    case green  =  "#33cc33"
    case orange =  "#ff9933"
    case debug  =  "#999999"
    
    public var color: SKColor {
        return SKColor(hexString: self.rawValue)
    }
}


// MARK: - Tiled File Properties

/// Tile orientation
public enum TilemapOrientation: String {
    case orthogonal   = "orthogonal"
    case isometric    = "isometric"
    case hexagonal    = "hexagonal"
    case staggered    = "staggered"
}


public enum RenderOrder: String {
    case rightDown  = "right-down"
    case rightUp    = "right-up"
    case leftDown   = "left-down"
    case leftUp     = "left-up"
}


/**
 Tile offset hint for coordinate conversion.
 
 - BottomLeft:  tile aligns at the bottom left corner.
 - TopLeft:     tile aligns at the top left corner.
 - TopRight:    tile aligns at the top right corner.
 - BottomRight: tile aligns at the bottom right corner.
 - Center:      tile aligns at the center.
 */
public enum TileOffset: Int {
    case bottomLeft = 0     // tile's upper left edge.
    case topLeft
    case topRight
    case bottomRight
    case center
}


/* Tilemap data encoding */
public enum TilemapEncoding: String {
    case base64  = "base64"
    case csv     = "csv"
    case xml     = "xml"
}



/// Represents a tile x/y coordinate.
public struct TileCoord {
    /// Tile x-coordinate
    public var x: Int32
    /// Tile y-coordinate
    public var y: Int32
}


/// Cardinal direction
public enum CardinalDirection: Int {
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
    case northWest
}

/**
 Alignment hint used to position the layers within the `SKTilemap` node.

 - BottomLeft:   node bottom left rests at parent zeropoint (0)
 - Center:       node center rests at parent zeropoint (0.5)
 - TopRight:     node top right rests at parent zeropoint. (1)
 */
public enum LayerPosition {
    case bottomLeft
    case center
    case topRight
}

/**
 Hexagonal stagger axis.
 
 - X: axis is along the x-coordinate.
 - Y: axis is along the y-coordinate.
 */
public enum StaggerAxis: String {
    case x  = "x"
    case y  = "y"
}


/**
 Hexagonal stagger index.
 
 - Even: stagger evens.
 - Odd:  stagger odds.
 */
public enum StaggerIndex: String {
    case even  = "even"
    case odd   = "odd"
}


///  Common tile size aliases
public let TileSizeZero  = CGSize(width: 0, height: 0)
public let TileSize8x8   = CGSize(width: 8, height: 8)
public let TileSize16x16 = CGSize(width: 16, height: 16)
public let TileSize32x32 = CGSize(width: 32, height: 32)

    
// MARK: - Tilemap

/**
 The `SKTilemap` class represents a container node which holds layers, tiles (sprites), objects & images.
 
 - size:         tile map size in tiles.
 - tileSize:     tile map tile size in pixels.
 - sizeInPoints: tile map size in points.
 
 Tile data is added via `SKTileset` tile sets.
 */
open class SKTilemap: SKNode, SKTiledObject{
    
    open var filename: String!                                    // tilemap filename
    open var uuid: String = UUID().uuidString                     // unique id
    open var size: CGSize                                         // map size (in tiles)
    open var tileSize: CGSize                                     // tile size (in pixels)
    open var orientation: TilemapOrientation                      // map orientation
    open var renderOrder: RenderOrder = .rightDown                // render order
    
    // hexagonal
    open var hexsidelength: Int = 0                               // hexagonal side length
    open var staggeraxis: StaggerAxis = .y                        // stagger axis
    open var staggerindex: StaggerIndex = .odd                    // stagger index.
    
    // camera overrides
    open var worldScale: CGFloat = 1.0                            // initial world scale
    open var allowZoom: Bool = true                               // allow camera zoom
    open var allowMovement: Bool = true                           // allow camera movement
    open var minZoom: CGFloat = 0.2
    open var maxZoom: CGFloat = 5.0
    
    // current tile sets
    open var tileSets: Set<SKTileset> = []                        // tilesets
    
    // current layers
    private var layers: Set<TiledLayerObject> = []                // layers
    open var layerCount: Int { return self.layers.count }         // layer count attribute
    open var properties: [String: String] = [:]                   // custom properties
    open var zDeltaForLayers: CGFloat = 50                        // z-position range for layers
    open var backgroundColor: SKColor? = nil                      // optional background color (read from the Tiled file)
    open var ignoreBackground: Bool = false                            // ignore Tiled scene background color
    
    
    /** 
    The tile map default base layer, used for displaying the current grid, getting coordinates, etc.
    */
    lazy open var baseLayer: SKTileLayer = {
        let layer = SKTileLayer(layerName: "Base", tileMap: self)
        self.addLayer(layer)
        return layer
    }()
    
    // debugging
    open var gridColor: SKColor = SKColor.black                        // color used to visualize the tile grid
    open var frameColor: SKColor = SKColor.black                       // bounding box color
    open var highlightColor: SKColor = SKColor.green                   // color used to highlight tiles
    
    /// Rendered size of the map in pixels.
    open var sizeInPoints: CGSize {
        switch orientation {
        case .orthogonal:
            return CGSize(width: size.width * tileSize.width, height: size.height * tileSize.height)
        case .isometric:
            let side = width + height
            return CGSize(width: side * tileWidthHalf,  height: side * tileHeightHalf)
        case .hexagonal, .staggered:
            var result = CGSize.zero
            if staggerX == true {
                result = CGSize(width: width * columnWidth + sideOffsetX,
                                height: height * (tileHeight + sideLengthY))
                
                if width > 1 { result.height += rowHeight }
            } else {
                result = CGSize(width: width * (tileWidth + sideLengthX),
                                height: height * rowHeight + sideOffsetY)
                
                if height > 1 { result.width += columnWidth }
            }
            return result
        }
    }
    
    // used to align the layers within the tile map
    open var layerAlignment: LayerPosition = .center {
        didSet {
            layers.forEach({self.positionLayer($0)})
        }
    }
    
    // returns the last GID for all of the tilesets.
    open var lastGID: Int {
        return tileSets.count > 0 ? tileSets.map {$0.lastGID}.max()! : 0
    }    
    
    /// Returns the last GID for all tilesets.
    open var lastIndex: Int {
        return layers.count > 0 ? layers.map {$0.index}.max()! : 0
    }
    
    /// Returns the last (highest) z-position in the map.
    open var lastZPosition: CGFloat {
        return layers.count > 0 ? layers.map {$0.zPosition}.max()! : 0
    }
    
    /// Tile overlap amount. 1 is typically a good value.
    open var tileOverlap: CGFloat = 0.5 {
        didSet {
            guard oldValue != tileOverlap else { return }
            for tileLayer in tileLayers {
                tileLayer.setTileOverlap(tileOverlap)
            }
        }
    }
    
    /// Global property to show/hide all `SKTileObject` objects.
    open var showObjects: Bool = false {
        didSet {
            guard oldValue != showObjects else { return }
            for objectLayer in objectGroups {
                objectLayer.showObjects = showObjects
            }
        }
    }
    
    /// Convenience property to return all tile layers.
    open var tileLayers: [SKTileLayer] {
        return layers.sorted(by: {$0.index < $1.index}).filter({$0 as? SKTileLayer != nil}) as! [SKTileLayer]
    }
    
    /// Convenience property to return all object groups.
    open var objectGroups: [SKObjectGroup] {
        return layers.sorted(by: {$0.index < $1.index}).filter({$0 as? SKObjectGroup != nil}) as! [SKObjectGroup]
    }
    
    /// Convenience property to return all image layers.
    open var imageLayers: [SKImageLayer] {
        return layers.sorted(by: {$0.index < $1.index}).filter({$0 as? SKImageLayer != nil}) as! [SKImageLayer]
    }
    
    // MARK: - Loading
    
    /**
     Load a Tiled tmx file and return a new `SKTilemap` object.
     
     - parameter filename: `String` Tiled file name.
     
     - returns: `SKTilemap?` tilemap object (if file read succeeds).
     */
    open class func load(fromFile filename: String) -> SKTilemap? {
        if let tilemap = SKTilemapParser().load(fromFile: filename) {
            return tilemap
        }
        return nil
    }
    
    // MARK: - Init
    /**
     Initialize with dictionary attributes from xml parser.
     
     - parameter attributes: `Dictionary` attributes dictionary.
     
     - returns: `SKTileMapNode?`
     */
    public init?(attributes: [String: String]) {
        guard let width = attributes["width"] else { return nil }
        guard let height = attributes["height"] else { return nil }
        guard let tilewidth = attributes["tilewidth"] else { return nil }
        guard let tileheight = attributes["tileheight"] else { return nil }
        guard let orient = attributes["orientation"] else { return nil }
        
        // initialize tile size & map size
        tileSize = CGSize(width: CGFloat(Int(tilewidth)!), height: CGFloat(Int(tileheight)!))
        size = CGSize(width: CGFloat(Int(width)!), height: CGFloat(Int(height)!))
        
        // tile orientation
        guard let tileOrientation: TilemapOrientation = TilemapOrientation(rawValue: orient) else {
            fatalError("orientation \"\(orient)\" not supported.")
        }
        
        self.orientation = tileOrientation
        
        // render order
        if let rendorder = attributes["renderorder"] {
            guard let renderorder: RenderOrder = RenderOrder(rawValue: rendorder) else {
                fatalError("orientation \"\(rendorder)\" not supported.")
            }
            self.renderOrder = renderorder
        }
        
        // hex side
        if let hexside = attributes["hexsidelength"] {
            self.hexsidelength = Int(hexside)!
        }
        
        // hex stagger axis
        if let hexStagger = attributes["staggeraxis"] {
            guard let staggerAxis: StaggerAxis = StaggerAxis(rawValue: hexStagger) else {
                fatalError("stagger axis \"\(hexStagger)\" not supported.")
            }
            self.staggeraxis = staggerAxis
        }
        
        // hex stagger index
        if let hexIndex = attributes["staggerindex"] {
            guard let hexindex: StaggerIndex = StaggerIndex(rawValue: hexIndex) else {
                fatalError("stagger index \"\(hexIndex)\" not supported.")
            }
            self.staggerindex = hexindex
        }
        
        // background color
        if let backgroundHexColor = attributes["backgroundcolor"] {
            if !(ignoreBackground == true){
            self.backgroundColor = SKColor(hexString: backgroundHexColor)
        }
        }
        
        super.init()
    }
    
    /**
     Initialize with map size/tile size
     
     - parameter sizeX:     `Int` map width in tiles.
     - parameter sizeY:     `Int` map height in tiles.
     - parameter tileSizeX: `Int` tile width in pixels.
     - parameter tileSizeY: `Int` tile height in pixels.
     
     - returns: `SKTilemap`
     */
    public init(_ sizeX: Int, _ sizeY: Int,
                _ tileSizeX: Int, _ tileSizeY: Int,
                  orientation: TilemapOrientation = .orthogonal) {
        self.size = CGSize(width: CGFloat(sizeX), height: CGFloat(sizeY))
        self.tileSize = CGSize(width: CGFloat(tileSizeX), height: CGFloat(tileSizeY))
        self.orientation = orientation
        super.init()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Tilesets
    
    /**
     Add a tileset to tileset set.
     
     - parameter tileset: `SKTileset` tileset object.
     */
    open func addTileset(_ tileset: SKTileset) {
        tileSets.insert(tileset)
        tileset.tilemap = self
        tileset.parseProperties()
    }
    
    /**
     Returns a named tileset from the tilesets set.
     
     - parameter name: `String` tileset to return.
     
     - returns: `SKTileset?` tileset object.
     */
    open func getTileset(named name: String) -> SKTileset? {
        if let index = tileSets.index( where: { $0.name == name } ) {
            let tileset = tileSets[index]
            return tileset
        }
        return nil
    }

    /**
     Returns an external tileset with a given filename.

     - parameter filename: `String` tileset source file.

     - returns: `SKTileset?`
     */
    open func getTileset(fileNamed filename: String) -> SKTileset? {
        if let index = tileSets.index( where: { $0.filename == filename } ) {
            let tileset = tileSets[index]
            return tileset
        }
        return nil
    }

    
    // MARK: - Layers
    /**
     Returns all layers, sorted by index (first is lowest, last is highest).
     
     - returns: `[TiledLayerObject]` array of layers.
     */
    open func allLayers() -> [TiledLayerObject] {
        return layers.sorted(by: {$0.index < $1.index})
    }
    
    /**
     Returns an array of layer names.
     
     - returns: `[String]` layer names.
     */
    open func layerNames() -> [String] {
        return layers.flatMap { $0.name }
    }
    
    /**
     Add a layer to the layers set. Automatically sets zPosition based on the zDeltaForLayers attributes.
     
     - parameter layer: `TiledLayerObject` layer object.
     */
    open func addLayer(_ layer: TiledLayerObject, parse: Bool = false) {
        // set the layer index
        layer.index = layers.count > 0 ? lastIndex + 1 : 0
        
        layers.insert(layer)
        addChild(layer)
        
        // align the layer to the anchorpoint
        positionLayer(layer)
        layer.zPosition = zDeltaForLayers * CGFloat(layer.index)
        
        // override debugging colors
        layer.gridColor = self.gridColor
        layer.frameColor = self.frameColor
        layer.highlightColor = self.highlightColor
        
        if (parse == true) {
            layer.parseProperties()  // moved this to parser
        }
    }
    
    open func addNewTileLayer(_ named: String) -> SKTileLayer {
        let layer = SKTileLayer(layerName: named, tileMap: self)
        addLayer(layer)
        return layer
    }
    
    /**
     Returns a named tile layer from the layers set.
     
     - parameter name: `String` tile layer name.
     
     - returns: `TiledLayerObject?` layer object.
     */
    open func getLayer(named layerName: String) -> TiledLayerObject? {
        if let index = layers.index( where: { $0.name == layerName } ) {
            let layer = layers[index]
            return layer
        }
        return nil
    }
    
    /**
     Returns a layer matching the given UUID.
     
     - parameter uuid: `String` tile layer UUID.
     
     - returns: `TiledLayerObject?` layer object.
     */
    open func getLayer(withID uuid: String) -> TiledLayerObject? {
        if let index = layers.index( where: { $0.uuid == uuid } ) {
            let layer = layers[index]
            return layer
        }
        return nil
    }
    
    /**
     Returns a layer given the index (0 being the lowest).
     
     - parameter index: `Int` layer index.
     
     - returns: `TiledLayerObject?` layer object.
     */
    open func getLayer(atIndex index: Int) -> TiledLayerObject? {
        if let index = layers.index( where: { $0.index == index } ) {
            let layer = layers[index]
            return layer
        }
        return nil
    }
    
    /**
     Isolate a named layer (hides other layers). Pass `nil`
     to show all layers.
     
     - parameter named: `String` layer name.
     */
    open func isolateLayer(_ named: String?=nil) {
        guard named != nil else {
            layers.forEach {$0.visible = true}
            return
        }
        
        layers.forEach {
            let isHidden: Bool = $0.name == named ? true : false
            $0.visible = isHidden
        }
    }
    
    /**
     Returns a named tile layer if it exists, otherwise, nil.
     
     - parameter named: `String` tile layer name.
     
     - returns: `SKTileLayer?`
     */
    open func tileLayer(named name: String) -> SKTileLayer? {
        if let layerIndex = tileLayers.index( where: { $0.name == name } ) {
            let layer = tileLayers[layerIndex]
            return layer
        }
        return nil
    }
    
    /**
     Returns a tile layer at the given index, otherwise, nil.
     
     - parameter atIndex: `Int` layer index.
     
     - returns: `SKTileLayer?`
     */
    open func tileLayer(atIndex index: Int) -> SKTileLayer? {
        if let layerIndex = tileLayers.index( where: { $0.index == index } ) {
            let layer = tileLayers[layerIndex]
            return layer
        }
        return nil
    }
    
    /**
     Returns a named object group if it exists, otherwise, nil.
     
     - parameter named: `String` tile layer name.
     
     - returns: `SKObjectGroup?`
     */
    open func objectGroup(named name: String) -> SKObjectGroup? {
        if let layerIndex = objectGroups.index( where: { $0.name == name } ) {
            let layer = objectGroups[layerIndex]
            return layer
        }
        return nil
    }
    
    /**
     Returns an object group at the given index, otherwise, nil.
     
     - parameter atIndex: `Int` layer index.
     
     - returns: `SKObjectGroup?`
     */
    open func objectGroup(atIndex index: Int) -> SKObjectGroup? {
        if let layerIndex = objectGroups.index( where: { $0.index == index } ) {
            let layer = objectGroups[layerIndex]
            return layer
        }
        return nil
    }
    
    open func indexOf(_ layer: TiledLayerObject) -> Int {
        return 0
    }
    
    open func indexOf(layedNamed name: String) -> Int {
        return 0
    }
    
    /**
     Position child layers in relation to the anchorpoint.
     
     - parameter layer: `TiledLayerObject` layer.
     */
    fileprivate func positionLayer(_ layer: TiledLayerObject) {
        var layerPos = CGPoint.zero
        switch orientation {
            
        case .orthogonal:
            layerPos.x = -sizeInPoints.width * layerAlignment.anchorPoint.x
            layerPos.y = sizeInPoints.height * layerAlignment.anchorPoint.y
        
            // layer offset
            layerPos.x += layer.offset.x
            layerPos.y -= layer.offset.y
        
        case .isometric:
            // layer offset
            layerPos.x = -sizeInPoints.width * layerAlignment.anchorPoint.x
            layerPos.y = sizeInPoints.height * layerAlignment.anchorPoint.y
            layerPos.x += layer.offset.x
            layerPos.y -= layer.offset.y
            
        case .hexagonal, .staggered:
            layerPos.x = -sizeInPoints.width * layerAlignment.anchorPoint.x
            layerPos.y = sizeInPoints.height * layerAlignment.anchorPoint.y
            
            // layer offset
            layerPos.x += layer.offset.x
            layerPos.y -= layer.offset.y
        }
        
        layer.position = layerPos
    }
    
    /**
     Sort the layers in z based on a starting value (defaults to the current zPosition).
        
     - parameter fromZ: `CGFloat?` optional starting z-positon.
     */
    open func sortLayers(_ fromZ: CGFloat?=nil) {
        let startingZ: CGFloat = (fromZ != nil) ? fromZ! : zPosition
        allLayers().forEach {$0.zPosition = startingZ + (zDeltaForLayers * CGFloat($0.index))}
    }
    
    // MARK: - Tiles
    
    /**
     Return tiles at the given coordinate (all tile layers).
     
     - parameter coord: `TileCoord` coordinate.
     
     - returns: `[SKTile]` array of tiles.
     */
    open func tilesAt(_ coord: TileCoord) -> [SKTile] {
        var result: [SKTile] = []
        for layer in tileLayers {
            if let tile = layer.tileAt(coord){
                result.append(tile)
            }
        }
        return result
    }

    /**
     Return tiles at the given coordinate (all tile layers).
     
     - parameter x: `Int` x-coordinate.
     - parameter y: `Int` - y-coordinate.
     
     - returns: `[SKTile]` array of tiles.
     */
    open func tilesAt(_ x: Int, _ y: Int) -> [SKTile] {
        return tilesAt(TileCoord(x,y))
    }
    
    /**
     Returns a tile at the given coordinate from a layer.
     
     - parameter coord: `TileCoord` tile coordinate.
     - parameter name:  `String?` layer name.
     
     - returns: `SKTile?` tile, or nil.
     */
    open func tileAt(_ coord: TileCoord, inLayer: String?) -> SKTile? {
        if let name = name {
            if let layer = getLayer(named: name) as? SKTileLayer {
                return layer.tileAt(coord)
            }
        }
        return nil
    }
    
    open func tileAt(_ x: Int, _ y: Int, inLayer name: String?) -> SKTile? {
        return tileAt(TileCoord(x,y), inLayer: name)
    }
    
    /**
     Returns tiles with a property of the given type (all tile layers).
     
     - parameter type: `String` type.
     
     - returns: `[SKTile]` array of tiles.
     */
    open func getTiles(ofType type: String) -> [SKTile] {
        var result: [SKTile] = []
        for layer in tileLayers {
            result += layer.getTiles(ofType: type)
        }
        return result
    }
    
    /**
     Returns tiles matching the given gid (all tile layers).
     
     - parameter type: `Int` tile gid.
     
     - returns: `[SKTile]` array of tiles.
     */
    open func getTiles(withID id: Int) -> [SKTile] {
        var result: [SKTile] = []
        for layer in tileLayers {
            result += layer.getTiles(withID: id)
        }
        return result
    }
    
    /**
     Returns tiles with a property of the given type & value (all tile layers).
     
     - parameter named: `String` property name.
     - parameter value: `AnyObject` property value.
     - returns: `[SKTile]` array of tiles.
     */
    open func getTilesWithProperty(_ named: String, _ value: AnyObject) -> [SKTile] {
        var result: [SKTile] = []
        for layer in tileLayers {
            result += layer.getTilesWithProperty(named, value as! String as AnyObject)
        }
        return result
    }
    
    /**
     Return tile data with a property of the given type (all tile layers).
     
     - parameter named: `String` property name.
     - returns: `[SKTile]` array of tiles.
     */
    open func getTileDataWithProperty(_ named: String) -> [SKTilesetData] {
        return tileSets.flatMap { $0.getTileData(withProperty: named)}
    }
    
    /**
     Returns an array of all animated tile objects.
     
     - returns: `[SKTile]` array of tiles.
     */
    open func getAnimatedTiles() -> [SKTile] {
        var result: [SKTile] = []
        enumerateChildNodes(withName: "//*") {
            node, stop in
            if let tile = node as? SKTile {
                if (tile.tileData.isAnimated == true) {
                    result.append(tile)
                }
            }
        }
        return result
    }
    
    /**
     Return the top-most tile at the given coordinate.
     
     - parameter coord: `TileCoord` coordinate.
     
     - returns: `SKTile?` first tile in layers.
     */
    open func firstTileAt(_ coord: TileCoord) -> SKTile? {
        for layer in tileLayers.reversed() {
            if layer.visible == true{
                if let tile = layer.tileAt(coord) {
                    return tile
                }
            }
        }
        return nil
    }
    
    // MARK: - Objects
    
    /**
     Return all of the current tile objects.
     
     - returns: `[SKTileObject]` array of objects.
     */
    open func getObjects() -> [SKTileObject] {
        var result: [SKTileObject] = []
        enumerateChildNodes(withName: "//*") {
            node, stop in
            if let node = node as? SKTileObject {
                result.append(node)
            }
        }
        return result
    }
    
    /**
     Return objects matching a given type.
     
     - parameter type: `String` object name to query.
     
     - returns: `[SKTileObject]` array of objects.
     */
    open func getObjects(ofType type: String) -> [SKTileObject] {
        var result: [SKTileObject] = []
        enumerateChildNodes(withName: "//*") {
            node, stop in
            // do something with node or stop
            if let node = node as? SKTileObject {
                if let objectType = node.type {
                    if objectType == type {
                        result.append(node)
                    }
                }
            }
        }
        return result
    }
    
    /**
     Return objects matching a given name.
     
     - parameter named: `String` object name to query.
     
     - returns: `[SKTileObject]` array of objects.
     */
    open func getObjects(_ named: String) -> [SKTileObject] {
        var result: [SKTileObject] = []
        enumerateChildNodes(withName: "//*") {
            node, stop in
            // do something with node or stop
            if let node = node as? SKTileObject {
                if let objectName = node.name {
                    if objectName == named {
                
                        result.append(node)
                    }
                }
            }
        }
        return result
    }
    
    // MARK: - Data
    /**
     Returns data for a global tile id.
     
     - parameter gid: `Int` global tile id.
     
     - returns: `SKTilesetData` tile data, if it exists.
     */
    open func getTileData(_ gid: Int) -> SKTilesetData? {
        for tileset in tileSets {
            if let tileData = tileset.getTileData(gid) {
                return tileData
            }
        }
        return nil
    }
    
    // MARK: - Coordinates
    
    
    /**
     Returns a converted touch location.
     
     - parameter point: `CGPoint` scene point.
     
     - returns: `CGPoint` converted point in layer coordinate system.
     */
    #if os(iOS)
    open func touchLocation(_ touch: UITouch) -> CGPoint {
        return baseLayer.touchLocation(touch)
    }
    #endif
    
    /**
     Returns a mouse event location in negative-y space.
     
     *Position is in converted space*
    
     - parameter point: `CGPoint` scene point.
     
     - returns: `CGPoint` converted point in layer coordinate system.
     */
    #if os(OSX)
    public func mouseLocation(event: NSEvent) -> CGPoint {
        return baseLayer.mouseLocation(event: event)
    }
    #endif
    
    
    open func positionInMap(point: CGPoint) -> CGPoint {
        return convert(point, to: baseLayer).invertedY
    }
}


// MARK: - Extensions

extension TileCoord: CustomStringConvertible, CustomDebugStringConvertible {
    
    /**
     Initialize coordinate with two integers.
     
     - parameter x: `Int32` x-coordinate.
     - parameter y: `Int32` y-coordinate.
     
     - returns: `TileCoord` coordinate.
     */
    public init(_ x: Int32, _ y: Int32){
        self.x = x
        self.y = y
    }
    
    /**
     Initialize coordinate with two integers.
     
     - parameter x: `Int` x-coordinate.
     - parameter y: `Int` y-coordinate.
     
     - returns: `TileCoord` coordinate.
     */
    public init(_ x: Int, _ y: Int){
        self.init(Int32(x), Int32(y))
    }
    
    /**
     Initialize coordinate with two floats.
    
     - parameter x: `CGFloat` x-coordinate.
     - parameter y: `CGFloat` y-coordinate.
    
     - returns: `TileCoord` coordinate.
     */
    public init(_ x: CGFloat, _ y: CGFloat) {
        self.x = Int32(floor(x))
        self.y = Int32(floor(y))
    }
    
    /**
     Initialize coordinate with a CGPoint.
     
     - parameter point: `CGPoint`
     
     - returns: `TileCoord` coordinate.
     */
    public init(point: CGPoint){
        self.init(point.x, point.y)
    }
    
    /**
     Convert the coordinate values to CGPoint.
     
     - returns: `CGPoint` point.
     */
    public func toPoint() -> CGPoint {
        return CGPoint(x: Int(x), y: Int(y))
    }
    
    /**
     Return the coordinate as a `int2` vector (for GameplayKit).
     
     - returns: `int2` vector.
     */
    public var vec2: int2 {
        return int2(x, y)
    }
    
    public var description: String { return "x: \(Int(x)), y: \(Int(y))" }
    public var debugDescription: String { return description }
}


public extension TilemapOrientation {
    
    /// Hint for aligning tiles within each layer.
    public var alignmentHint: CGPoint {
        switch self {
        case .orthogonal:
            return CGPoint(x: 0.5, y: 0.5)
        case .isometric:
            return CGPoint(x: 0.5, y: 0.5)
        case .hexagonal:
            return CGPoint(x: 0.5, y: 0.5)
        case .staggered:
            return CGPoint(x: 0.5, y: 0.5)
        }
    }
}


extension LayerPosition: CustomStringConvertible {
    
    public var description: String {
        return "\(name): (\(self.anchorPoint.x), \(self.anchorPoint.y))"
}

    public var name: String {
        switch self {
        case .bottomLeft: return "Bottom Left"
        case .center: return "Center"
        case .topRight: return "Top Right"
        }
    }
    
    public var anchorPoint: CGPoint {
        switch self {
        case .bottomLeft: return CGPoint(x: 0, y: 0)
        case .center: return CGPoint(x: 0.5, y: 0.5)
        case .topRight: return CGPoint(x: 1, y: 1)
        }
    }
}



public extension SKTilemap {
    
    // convenience properties
    public var width: CGFloat { return size.width }
    public var height: CGFloat { return size.height }
    public var tileWidth: CGFloat { return tileSize.width }
    public var tileHeight: CGFloat { return tileSize.height }
    
    public var sizeHalved: CGSize { return CGSize(width: size.width / 2, height: size.height / 2)}
    public var tileWidthHalf: CGFloat { return tileWidth / 2 }
    public var tileHeightHalf: CGFloat { return tileHeight / 2 }
    
    // hexagonal/staggered
    public var staggerX: Bool { return (staggeraxis == .x) }
    public var staggerEven: Bool { return staggerindex == .even }
    
    public var sideLengthX: CGFloat { return (staggeraxis == .x) ? CGFloat(hexsidelength) : 0 }
    public var sideLengthY: CGFloat { return (staggeraxis == .y) ? CGFloat(hexsidelength) : 0 }
    
    public var sideOffsetX: CGFloat { return (tileWidth - sideLengthX) / 2 }
    public var sideOffsetY: CGFloat { return (tileHeight - sideLengthY) / 2 }
    
    // coordinate grid values
    public var columnWidth: CGFloat { return sideOffsetX + sideLengthX }
    public var rowHeight: CGFloat { return sideOffsetY + sideLengthY }
    
    // MARK: - Hexagonal / Staggered methods
    /**
     Returns true if the given x-coordinate represents a staggered column.
     
     - parameter x:  `Int` map x-coordinate.
     - returns: `Bool` column should be staggered.
     */
    public func doStaggerX(_ x: Int) -> Bool {
        return staggerX && Bool((x & 1) ^ staggerEven.hashValue)
    }
    
    /**
     Returns true if the given y-coordinate represents a staggered row.
     
     - parameter x:  `Int` map y-coordinate.
     - returns: `Bool` row should be staggered.
     */
    public func doStaggerY(_ y: Int) -> Bool {
        return !staggerX && Bool((y & 1) ^ staggerEven.hashValue)
    }
    
    public func topLeft(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        // pointy-topped
        if (staggerX == false) {
            // y is odd = 1, y is even = 0
            // stagger index hash: Int = 0 (even), 1 (odd)
            if Bool((Int(y) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x, y: y - 1)
            } else {
                return CGPoint(x: x - 1, y: y - 1)
            }
        // flat-topped
        } else {
            if Bool((Int(x) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x - 1, y: y)
            } else {
                return CGPoint(x: x - 1, y: y - 1)
            }
        }
    }
            
    public func topRight(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        if (staggerX == false) {
            if Bool((Int(y) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x + 1, y: y - 1)
            } else {
                return CGPoint(x: x, y: y - 1)
            }
        } else {
            if Bool((Int(x) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x + 1, y: y)
            } else {
                return CGPoint(x: x + 1, y: y - 1)
            }
        }
    }
    
    public func bottomLeft(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        if (staggerX == false) {
            if Bool((Int(y) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x, y: y + 1)
            } else {
                return CGPoint(x: x - 1, y: y + 1)
            }
        } else {
            if Bool((Int(x) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x - 1, y: y + 1)
            } else {
                return CGPoint(x: x - 1, y: y)
            }
        }
    }
    
    public func bottomRight(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        if (staggerX == false) {
            if Bool((Int(y) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x + 1, y: y + 1)
            } else {
                return CGPoint(x: x, y: y + 1)
            }
        } else {
            if Bool((Int(x) & 1) ^ staggerindex.hashValue) {
                return CGPoint(x: x + 1, y: y + 1)
            } else {
                return CGPoint(x: x + 1, y: y)
            }
        }
    }
    
    override open var description: String {
        var tilemapName = "(None)"
        if let name = name {
            tilemapName = "\"\(name)\""
        }
        let renderSizeDesc = "\(sizeInPoints.width.roundTo(1)) x \(sizeInPoints.height.roundTo(1))"
        let sizeDesc = "\(Int(size.width)) x \(Int(size.height))"
        let tileSizeDesc = "\(Int(tileSize.width)) x \(Int(tileSize.height))"
        
        return "Map: \(tilemapName), \(renderSizeDesc): (\(sizeDesc) @ \(tileSizeDesc))"
    }
    
    override open var debugDescription: String { return description }
    
    /// Visualize the current grid & bounds.
    open var debugDraw: Bool {
        get {
            return baseLayer.debugDraw
        } set {
            guard newValue != baseLayer.debugDraw else { return }
            baseLayer.debugDraw = newValue
            baseLayer.showGrid = newValue
            showObjects = newValue
        }
    }
    
    /**
     Prints out all the data it has on the tilemap's layers.
     */
    public func debugLayers() {
        guard (layerCount > 0) else { return }
        let largestName = layerNames().max() { (a, b) -> Bool in a.characters.count < b.characters.count }
        let nameStr = "# Tilemap \"\(name!)\": \(layerCount) Layers:"
        let filled = String(repeating: "-", count: nameStr.characters.count)
        print("\n\(nameStr)\n\(filled)")
        for layer in allLayers() {
            if (layer != baseLayer) {
                let layerName = layer.name!
                let nameString = "\"\(layerName)\""
                print("\(layer.index): \(layer.layerType.stringValue.capitalized.zfill(6, pattern: " ", padLeft: false)) \(nameString.zfill(largestName!.characters.count + 2, pattern: " ", padLeft: false))   pos: \(layer.position.roundTo(1)), size: \(layer.sizeInPoints.roundTo(1)),  offset: \(layer.offset.roundTo(1)), anc: \(layer.anchorPoint.roundTo())")
                
            }
        }
        print("\n")
    }
}
