import SwiftUI
import SceneKit
import SpriteKit
import AVFoundation
import AppKit

// Renders a 3D iPhone model (USDZ/SCN) with the device screen as a separate geometry.
// The screen material is dynamically updated to show an AVPlayer (video) or NSImage.
struct Device3DPreview: NSViewRepresentable {
    // Input media
    var player: AVPlayer?
    var image: NSImage?

    // Model resource names (without extension). Tries USDZ first, then GLB/SCN if available.
    var modelBaseName: String = "Frames/iphone_16_black_frame" // e.g., in bundle as Frames/iphone_16_black_frame.usdz

    // Name of the node/material that represents the screen (fuzzy match used as fallback)
    var screenNodeName: String = "screen"

    // View settings
    var backgroundColor: NSColor = .clear
    var allowsCameraControl: Bool = true
    var debugLogHierarchy: Bool = true

    // Reports whether a screen node could be mapped in the 3D model
    var onMappingStatus: ((Bool) -> Void)? = nil

    // Optional overlay screen rect (percent-based) used to synthesize a screen plane
    // when the USDZ model does not contain a distinct screen mesh.
    var overlayScreenRect: ScreenRect = .init(x: 6.5, y: 3.0, w: 87.0, h: 94.0)

    // MARK: - NSViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        // Honor requested background color across view, layer and scene
        scnView.backgroundColor = backgroundColor
        scnView.wantsLayer = true
        scnView.layer?.backgroundColor = backgroundColor.cgColor
        scnView.allowsCameraControl = allowsCameraControl
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        let scene = buildScene()
        scene.background.contents = backgroundColor
        scnView.scene = scene
        scnView.autoenablesDefaultLighting = false
        scnView.rendersContinuously = true
        scnView.preferredFramesPerSecond = 60
        #if DEBUG
        scnView.debugOptions = [.showBoundingBoxes]
        #endif

        // Use our camera as pointOfView
        if let cam = scene.rootNode.childNode(withName: "MainCamera", recursively: true) {
            scnView.pointOfView = cam
        }

        // Frame camera around primary node if available, else whole scene
        frameCamera(for: scnView)

        // Attach gestures for additional control
        attachGestures(to: scnView, coordinator: context.coordinator)
        context.coordinator.bind(view: scnView)

        // Initial material update
        updateScreenMaterial(in: scnView.scene, with: player, image: image)

        if debugLogHierarchy {
            if let scene = scnView.scene {
                print("\n—— Device3DPreview: Node Hierarchy ———————————————")
                dumpNodeTree(scene.rootNode, indent: "")
                print("————————————————————————————————————————\n")
                // Highlight likely candidates
                highlightCandidateScreenNodes(in: scene.rootNode)
            }
        }

        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Update media mapping on changes
        updateScreenMaterial(in: nsView.scene, with: player, image: image)
        // Keep background in sync if toggled
        nsView.backgroundColor = backgroundColor
        nsView.layer?.backgroundColor = backgroundColor.cgColor
        nsView.scene?.background.contents = backgroundColor
    }

    // MARK: - Scene Construction
    private func buildScene() -> SCNScene {
        let scene = loadSceneFromBundle()

        // Remove common backdrop/stage meshes that ship inside some USDZs
        removeLikelyBackdropNodes(in: scene.rootNode)

        // Camera
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 35
        camera.usesOrthographicProjection = false
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        camera.zNear = 0.01
        camera.zFar = 2000
        cameraNode.camera = camera
        cameraNode.name = "MainCamera"
        cameraNode.position = SCNVector3(0, 0.05, 1.0)
        cameraNode.look(at: SCNVector3(0, 0.03, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        // Ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 800
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Key directional light
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 2000
        keyLight.castsShadow = true
        keyLight.shadowMode = .deferred
        keyLight.shadowRadius = 8
        keyLight.shadowColor = NSColor(white: 0, alpha: 0.4)
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(0.5, 0.8, 0.8)
        keyLightNode.eulerAngles = SCNVector3(-SCNFloat.pi/3, SCNFloat.pi/6, 0)
        scene.rootNode.addChildNode(keyLightNode)

        // Fill light
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 1000
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-0.6, 0.2, 0.6)
        scene.rootNode.addChildNode(fillLightNode)

        // Add small RGB axes at origin for visual confirmation
        let xAxis = SCNCylinder(radius: 0.005, height: 0.3)
        xAxis.firstMaterial?.diffuse.contents = NSColor.systemRed
        let xNode = SCNNode(geometry: xAxis)
        xNode.eulerAngles.z = SCNFloat.pi / 2
        xNode.position = SCNVector3(0.15, 0.0, 0.0)
        scene.rootNode.addChildNode(xNode)

        let yAxis = SCNCylinder(radius: 0.005, height: 0.3)
        yAxis.firstMaterial?.diffuse.contents = NSColor.systemGreen
        let yNode = SCNNode(geometry: yAxis)
        yNode.position = SCNVector3(0.0, 0.15, 0.0)
        scene.rootNode.addChildNode(yNode)

        let zAxis = SCNCylinder(radius: 0.005, height: 0.3)
        zAxis.firstMaterial?.diffuse.contents = NSColor.systemBlue
        let zNode = SCNNode(geometry: zAxis)
        zNode.eulerAngles.x = SCNFloat.pi / 2
        zNode.position = SCNVector3(0.0, 0.0, 0.15)
        scene.rootNode.addChildNode(zNode)

        // Ensure at least one visible geometry if model failed or has no meshes
        var hasGeometry = false
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.geometry != nil { hasGeometry = true }
        }
        if !hasGeometry {
            print("[Device3DPreview] No meshes detected; adding debug cube.")
            let box = SCNBox(width: 0.2, height: 0.4, length: 0.02, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = NSColor.systemBlue
            let boxNode = SCNNode(geometry: box)
            boxNode.position = SCNVector3(0, 0.2, 0)
            scene.rootNode.addChildNode(boxNode)
        }

        // Ensure no environment/skybox imposes a backdrop tint
        scene.lightingEnvironment.contents = nil
        scene.lightingEnvironment.intensity = 0
        scene.background.contents = backgroundColor

        return scene
    }

    // Hide meshes that look like a huge flat backdrop/floor/stage so we see the view background
    private func removeLikelyBackdropNodes(in root: SCNNode) {
        // Compute overall scene bounds in world space
        var minScene = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxScene = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        root.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bbMin, bbMax) = node.boundingBox
            let corners: [SCNVector3] = [
                SCNVector3(bbMin.x, bbMin.y, bbMin.z), SCNVector3(bbMax.x, bbMin.y, bbMin.z),
                SCNVector3(bbMin.x, bbMax.y, bbMin.z), SCNVector3(bbMax.x, bbMax.y, bbMin.z),
                SCNVector3(bbMin.x, bbMin.y, bbMax.z), SCNVector3(bbMax.x, bbMin.y, bbMax.z),
                SCNVector3(bbMin.x, bbMax.y, bbMax.z), SCNVector3(bbMax.x, bbMax.y, bbMax.z)
            ]
            for c in corners {
                let wp = node.convertPosition(c, to: nil)
                minScene.x = min(minScene.x, wp.x); minScene.y = min(minScene.y, wp.y); minScene.z = min(minScene.z, wp.z)
                maxScene.x = max(maxScene.x, wp.x); maxScene.y = max(maxScene.y, wp.y); maxScene.z = max(maxScene.z, wp.z)
            }
        }
        let sceneW = Double(maxScene.x - minScene.x)
        let sceneH = Double(maxScene.y - minScene.y)
        let sceneArea = max(1e-6, sceneW * sceneH)

        var nodesToHide: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            guard let geom = node.geometry else { return }
            let name = (node.name ?? "") + " " + (geom.name ?? "") + " " + (geom.firstMaterial?.name ?? "")
            let lower = name.lowercased()

            // Keep anything that sounds like part of the phone/device
            if lower.contains("screen") || lower.contains("display") || lower.contains("glass") ||
                lower.contains("iphone") || lower.contains("phone") || lower.contains("device") ||
                lower.contains("frame") || lower.contains("body") { return }

            // Name-based removal for obvious backdrops
            if lower.contains("background") || lower.contains("backdrop") || lower.contains("stage") || lower.contains("floor") || lower.contains("infinite") || lower.contains("cyclorama") {
                nodesToHide.append(node); return
            }

            // Heuristic removal: extremely thin, extremely large plane covering most of the scene
            let (minV, maxV) = node.boundingBox
            let w = Double(maxV.x - minV.x)
            let h = Double(maxV.y - minV.y)
            let d = Double(maxV.z - minV.z)
            guard w.isFinite && h.isFinite && d.isFinite else { return }
            let area = w * h
            let areaRatio = area / sceneArea
            let isExtremelyThin = d < min(w, h) * 0.005
            if areaRatio > 0.85 && isExtremelyThin {
                nodesToHide.append(node)
            }
        }
        nodesToHide.forEach { $0.isHidden = true }
    }

    private func loadSceneFromBundle() -> SCNScene {
        let bundle = Bundle.main
        // Try USDZ
        if let url = bundle.url(forResource: modelBaseName, withExtension: "usdz"), let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
            print("[Device3DPreview] Loaded model: \(url.lastPathComponent)")
            return scene
        }
        // Try SCN
        if let url = bundle.url(forResource: modelBaseName, withExtension: "scn"), let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
            print("[Device3DPreview] Loaded model: \(url.lastPathComponent)")
            return scene
        }
        // Try GLB via Model I/O bridge
        if let url = bundle.url(forResource: modelBaseName, withExtension: "glb"), let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
            print("[Device3DPreview] Loaded model: \(url.lastPathComponent)")
            return scene
        }
        // Empty fallback with detailed error logging
        print("⚠️  [Device3DPreview] 3D Model files not found in app bundle!")
        print("    Searched for: \(modelBaseName).{usdz,scn,glb}")
        print("    This causes the 'fopen failed for data file: errno = 2' error.")
        print("    Solution: Add the 3D model files to your Xcode project target:")
        print("    1. In Xcode, right-click your project in the navigator")
        print("    2. Choose 'Add Files to [ProjectName]'")
        print("    3. Select the .usdz and .scn files from Demofy/Frames/")
        print("    4. Make sure 'Add to target' is checked for your app target")
        print("    5. Clean and rebuild the project")
        
        let scene = SCNScene()
        let placeholder = SCNText(string: "3D Model Missing\nAdd .usdz/.scn files\nto Xcode project", extrusionDepth: 0.02)
        placeholder.firstMaterial?.diffuse.contents = NSColor.systemOrange
        placeholder.font = NSFont.systemFont(ofSize: 12)
        let textNode = SCNNode(geometry: placeholder)
        textNode.scale = SCNVector3(0.008, 0.008, 0.008)
        textNode.position = SCNVector3(-0.8, 0, 0)
        scene.rootNode.addChildNode(textNode)
        return scene
    }

    // MARK: - Camera framing
    private func frameCamera(for view: SCNView) {
        guard let scene = view.scene,
              let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
        // Compute world-space bounds of all geometry nodes
        var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var hasBox = false
        scene.rootNode.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bbMin, bbMax) = node.boundingBox
            // Transform 8 corners to world space using convertPosition
            let corners: [SCNVector3] = [
                SCNVector3(bbMin.x, bbMin.y, bbMin.z),
                SCNVector3(bbMax.x, bbMin.y, bbMin.z),
                SCNVector3(bbMin.x, bbMax.y, bbMin.z),
                SCNVector3(bbMax.x, bbMax.y, bbMin.z),
                SCNVector3(bbMin.x, bbMin.y, bbMax.z),
                SCNVector3(bbMax.x, bbMin.y, bbMax.z),
                SCNVector3(bbMin.x, bbMax.y, bbMax.z),
                SCNVector3(bbMax.x, bbMax.y, bbMax.z)
            ]
            for c in corners {
                let wp = node.convertPosition(c, to: nil)
                minV.x = min(minV.x, wp.x); minV.y = min(minV.y, wp.y); minV.z = min(minV.z, wp.z)
                maxV.x = max(maxV.x, wp.x); maxV.y = max(maxV.y, wp.y); maxV.z = max(maxV.z, wp.z)
            }
            hasBox = true
        }
        guard hasBox else { return }
        let center = SCNVector3((minV.x+maxV.x)/2, (minV.y+maxV.y)/2, (minV.z+maxV.z)/2)
        let extents = SCNVector3(maxV.x-minV.x, maxV.y-minV.y, maxV.z-minV.z)
        let radius = max(extents.x, max(extents.y, extents.z)) * 0.6
        // Position camera along diagonal looking at center
        let dist = radius / tan((cameraNode.camera?.fieldOfView ?? 35) * .pi/180 * 0.5) * 1.2
        cameraNode.position = SCNVector3(center.x + radius, center.y + radius*0.2, center.z + dist)
        cameraNode.look(at: center)
        view.defaultCameraController.target = center
    }

    private func frameCamera(on target: SCNNode, view: SCNView) {
        guard let cameraNode = view.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
        // Compute world bounds for the target subtree
        var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        target.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bbMin, bbMax) = node.boundingBox
            let corners: [SCNVector3] = [
                SCNVector3(bbMin.x, bbMin.y, bbMin.z),
                SCNVector3(bbMax.x, bbMin.y, bbMin.z),
                SCNVector3(bbMin.x, bbMax.y, bbMin.z),
                SCNVector3(bbMax.x, bbMax.y, bbMin.z),
                SCNVector3(bbMin.x, bbMin.y, bbMax.z),
                SCNVector3(bbMax.x, bbMin.y, bbMax.z),
                SCNVector3(bbMin.x, bbMax.y, bbMax.z),
                SCNVector3(bbMax.x, bbMax.y, bbMax.z)
            ]
            for c in corners {
                let wp = node.convertPosition(c, to: nil)
                minV.x = min(minV.x, wp.x); minV.y = min(minV.y, wp.y); minV.z = min(minV.z, wp.z)
                maxV.x = max(maxV.x, wp.x); maxV.y = max(maxV.y, wp.y); maxV.z = max(maxV.z, wp.z)
            }
        }
        let center = SCNVector3((minV.x+maxV.x)/2, (minV.y+maxV.y)/2, (minV.z+maxV.z)/2)
        let extents = SCNVector3(maxV.x-minV.x, maxV.y-minV.y, maxV.z-minV.z)
        let radius = max(extents.x, max(extents.y, extents.z)) * 0.6
        let dist = radius / tan((cameraNode.camera?.fieldOfView ?? 35) * .pi/180 * 0.5) * 1.2
        cameraNode.position = SCNVector3(center.x + radius, center.y + radius*0.2, center.z + dist)
        cameraNode.look(at: center)
        view.defaultCameraController.target = center
    }

    // Finds the device node; customize this if your USDZ groups nodes differently
    private func findDeviceNode(in root: SCNNode) -> SCNNode? {
        // Prefer a top-level child with many children (heuristic)
        if !root.childNodes.isEmpty { return root.childNodes.first }
        return root
    }

    // MARK: - Material Mapping
    private func updateScreenMaterial(in scene: SCNScene?, with player: AVPlayer?, image: NSImage?) {
        guard let scene else { return }
        // Try to find an existing screen node
        var screenNode = findScreenNode(in: scene.rootNode)
        // If not found, synthesize an overlay plane positioned over the device front
        if screenNode == nil {
            if let overlay = ensureOverlayScreenNode(in: scene.rootNode) {
                screenNode = overlay
            } else {
                print("[Device3DPreview] Screen node not found and could not create overlay plane.")
                onMappingStatus?(false)
                return
            }
        }
        guard let screenNode else { onMappingStatus?(false); return }
        guard let geom = screenNode.geometry else { return }

        let material = geom.firstMaterial ?? SCNMaterial()
        material.isDoubleSided = false
        material.lightingModel = .constant
        material.roughness.contents = 0.0
        material.metalness.contents = 0.0

        if let player {
            // Use SpriteKit to preserve aspect with letterboxing (fit)
            let sk = makeVideoSKScene(for: player, target: screenNode)
            material.emission.contents = sk
            material.diffuse.contents = NSColor.black
            material.emission.intensity = 1.0
            material.diffuse.wrapS = .clamp
            material.diffuse.wrapT = .clamp
        } else if let image {
            let sk = makeImageSKScene(for: image, target: screenNode)
            material.emission.contents = sk
            material.diffuse.contents = NSColor.black
            material.emission.intensity = 1.0
            material.diffuse.wrapS = .clamp
            material.diffuse.wrapT = .clamp
        } else {
            material.diffuse.contents = NSColor.black
            material.emission.contents = nil
        }

        screenNode.geometry?.firstMaterial = material
        onMappingStatus?(true)
    }

    // Create or update a front-facing plane to act as the screen when a mesh isn't provided
    private func ensureOverlayScreenNode(in root: SCNNode) -> SCNNode? {
        let overlayName = "DemofyScreenOverlay"
        if let existing = root.childNode(withName: overlayName, recursively: true) {
            // Geometry and material will be updated by updateScreenMaterial
            return existing
        }

        guard let deviceNode = findDeviceNode(in: root) else { return nil }
        let (minV, maxV) = deviceNode.boundingBox
        let width = CGFloat(maxV.x - minV.x)
        let height = CGFloat(maxV.y - minV.y)
        let depth = CGFloat(maxV.z - minV.z)
        guard width.isFinite && height.isFinite && depth.isFinite && width > 0 && height > 0 else { return nil }

        // Convert percent-based rect to local coordinates within the device bounds
        let px = CGFloat(overlayScreenRect.x / 100.0)
        let py = CGFloat(overlayScreenRect.y / 100.0)
        let pw = CGFloat(overlayScreenRect.w / 100.0)
        let ph = CGFloat(overlayScreenRect.h / 100.0)

        let planeW = max(1e-4, width * pw)
        let planeH = max(1e-4, height * ph)
        let centerX = CGFloat(minV.x) + width * (px + pw * 0.5)
        let centerY = CGFloat(minV.y) + height * (py + ph * 0.5)
        // Assume front is +Z. Place slightly in front of the device front to avoid z-fighting
        let z = CGFloat(maxV.z) + max(1e-4, depth) * 0.001

        let plane = SCNPlane(width: planeW, height: planeH)
        let mat = SCNMaterial()
        mat.isDoubleSided = false
        mat.lightingModel = .constant
        mat.diffuse.contents = NSColor.black
        mat.emission.intensity = 1.0
        plane.firstMaterial = mat

        let node = SCNNode(geometry: plane)
        node.name = overlayName
        node.position = SCNVector3(Float(centerX), Float(centerY), Float(z))
        // Ensure it faces the camera (positive Z)
        node.eulerAngles = SCNVector3Zero

        deviceNode.addChildNode(node)
        return node
    }

    // Find the node named like "screen". If not found, attempt fuzzy match on geometry/material names.
    private func findScreenNode(in root: SCNNode) -> SCNNode? {
        if let n = root.childNode(withName: screenNodeName, recursively: true) {
            return n
        }
        var queue: [SCNNode] = [root]
        while let node = queue.first {
            queue.removeFirst()
            if node.name?.lowercased().contains("screen") == true { return node }
            if node.geometry?.name?.lowercased().contains("screen") == true { return node }
            if let mats = node.geometry?.materials, mats.contains(where: { ($0.name?.lowercased().contains("screen") ?? false) || ($0.name?.lowercased().contains("display") ?? false) || ($0.name?.lowercased().contains("glass") ?? false) }) {
                return node
            }
            queue.append(contentsOf: node.childNodes)
        }
        // Fallback: heuristic auto-detect
        return autoDetectScreenNode(in: root)
    }

    // Heuristic: choose a large, thin, rectangular mesh whose aspect is close to a phone screen (~0.46 portrait or ~2.16 landscape)
    private func autoDetectScreenNode(in root: SCNNode) -> SCNNode? {
        var bestNode: SCNNode?
        var bestScore = Double.greatestFiniteMagnitude
        var queue: [SCNNode] = [root]
        let targetRatios: [Double] = [9.0/19.5, 19.5/9.0] // portrait, landscape
        while let node = queue.first {
            queue.removeFirst()
            if node.geometry != nil {
                let (minV, maxV) = node.boundingBox
                let w = Double(maxV.x - minV.x)
                let h = Double(maxV.y - minV.y)
                let d = Double(maxV.z - minV.z)
                if w > 0.001 && h > 0.001 {
                    let aspect = min(w,h) / max(w,h)
                    let aspectPenalty = targetRatios.map { abs($0 - aspect) }.min() ?? 1.0
                    let thicknessPenalty = max(0, d) / max(w, h) // thinner is better
                    let invArea = 1.0 / (w * h) // bigger area preferred
                    // Weighted score
                    let score = aspectPenalty * 4.0 + thicknessPenalty * 6.0 + invArea * 0.5
                    if score < bestScore {
                        bestScore = score
                        bestNode = node
                    }
                }
            }
            queue.append(contentsOf: node.childNodes)
        }
        return bestNode
    }

    // Build an SKScene that letterboxes to fit the screen geometry size
    private func makeVideoSKScene(for player: AVPlayer, target: SCNNode) -> SKScene {
        let size = estimateScreenPixelSize(for: target)
        let sceneSize = CGSize(width: max(64, size.width), height: max(64, size.height))
        let skScene = SKScene(size: sceneSize)
        skScene.scaleMode = .resizeFill
        skScene.backgroundColor = .black

        let videoNode = SKVideoNode(avPlayer: player)
        // Set video node size to aspect-fit inside skScene bounds
        let videoSize = estimateVideoSize(player: player)
        let fitted = aspectFitSize(inner: videoSize, outer: sceneSize)
        videoNode.size = fitted
        videoNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        videoNode.yScale = -1 // SpriteKit flipped Y when used as texture
        skScene.addChild(videoNode)
        // Ensure playback on both the AVPlayer and the SKVideoNode
        player.play()
        videoNode.play()
        return skScene
    }

    private func makeImageSKScene(for image: NSImage, target: SCNNode) -> SKScene {
        let size = estimateScreenPixelSize(for: target)
        let sceneSize = CGSize(width: max(64, size.width), height: max(64, size.height))
        let skScene = SKScene(size: sceneSize)
        skScene.scaleMode = .resizeFill
        skScene.backgroundColor = .black

        let texture = SKTexture(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil) ?? CGImage.makeBlackPixel())
        let texSize = CGSize(width: texture.size().width, height: texture.size().height)
        let fitted = aspectFitSize(inner: texSize, outer: sceneSize)
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = fitted
        sprite.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        sprite.yScale = -1
        skScene.addChild(sprite)
        return skScene
    }

    // Estimate the screen node's pixel size based on its bounds and an arbitrary DPI scale
    private func estimateScreenPixelSize(for node: SCNNode) -> CGSize {
        let (minVec, maxVec) = node.boundingBox
        let w = CGFloat(maxVec.x - minVec.x)
        let h = CGFloat(maxVec.y - minVec.y)
        // Scale up to a reasonable texture size (pixels). 2000px on the long edge.
        let longEdge: CGFloat = 2000
        let aspect = max(0.1, w / max(h, 0.001))
        if w >= h {
            return CGSize(width: longEdge, height: longEdge / max(aspect, 0.001))
        } else {
            return CGSize(width: longEdge * max(aspect, 0.001), height: longEdge)
        }
    }

    private func estimateVideoSize(player: AVPlayer) -> CGSize {
        if let sz = player.currentItem?.presentationSize, sz.width > 0, sz.height > 0 {
            return sz
        }
        return CGSize(width: 1920, height: 1080)
    }

    private func aspectFitSize(inner: CGSize, outer: CGSize) -> CGSize {
        guard inner.width > 0 && inner.height > 0 && outer.width > 0 && outer.height > 0 else { return outer }
        let scale = min(outer.width / inner.width, outer.height / inner.height)
        return CGSize(width: inner.width * scale, height: inner.height * scale)
    }

    // MARK: - Debug helpers
    private func dumpNodeTree(_ node: SCNNode, indent: String) {
        let name = node.name ?? "(unnamed)"
        var line = "\(indent)• node: \(name)"
        if let g = node.geometry {
            let gname = g.name ?? "(geom)"
            let mats = g.materials.map { $0.name ?? "(mat)" }.joined(separator: ",")
            let (minV, maxV) = node.boundingBox
            let w = Double(maxV.x - minV.x)
            let h = Double(maxV.y - minV.y)
            let d = Double(maxV.z - minV.z)
            line += "  geom=\(gname) mats=[\(mats)] bbox=\(String(format: "%.3fx%.3fx%.3f", w,h,d))"
        }
        print(line)
        for child in node.childNodes {
            dumpNodeTree(child, indent: indent + "  ")
        }
    }

    private func highlightCandidateScreenNodes(in root: SCNNode) {
        let keywords = ["screen", "display", "glass"]
        var queue: [SCNNode] = [root]
        while let node = queue.first {
            queue.removeFirst()
            let n = node.name?.lowercased() ?? ""
            let g = node.geometry?.name?.lowercased() ?? ""
            let mats = node.geometry?.materials.map { $0.name?.lowercased() ?? "" } ?? []
            let hit = keywords.contains(where: { n.contains($0) || g.contains($0) || mats.contains($0) })
            if hit, let mat = node.geometry?.firstMaterial {
                mat.emission.contents = NSColor.systemGreen
                mat.emission.intensity = 0.4
            }
            queue.append(contentsOf: node.childNodes)
        }
    }

    // MARK: - Gestures
    private func attachGestures(to view: SCNView, coordinator: Coordinator) {
        // Pan to rotate device
        let pan = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        // Pinch (magnify) to zoom
        let mag = NSMagnificationGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        view.addGestureRecognizer(mag)
    }

    final class Coordinator: NSObject {
        weak var scnView: SCNView?
        private var lastDrag: CGPoint = .zero

        func bind(view: SCNView) {
            self.scnView = view
        }

        @objc func handlePan(_ gr: NSPanGestureRecognizer) {
            guard let view = scnView, let scene = view.scene else { return }
            let translation = gr.translation(in: view)
            gr.setTranslation(.zero, in: view)
            // Rotate the top-most device node (heuristic) by orbiting camera controller
            if true {
                let controller = view.defaultCameraController
                let rotScale: CGFloat = 0.005
                let rx = Float(translation.y * rotScale)
                let ry = Float(translation.x * rotScale)
                controller.rotateBy(x: rx, y: ry)
            } else if let deviceNode = scene.rootNode.childNodes.first {
                let dx: SCNFloat = SCNFloat(translation.x) * (SCNFloat.pi / 1800)
                let dy: SCNFloat = SCNFloat(translation.y) * (SCNFloat.pi / 1800)
                var angles = deviceNode.eulerAngles
                angles.y -= dx
                angles.x -= dy
                deviceNode.eulerAngles = angles
            }
            lastDrag = translation
        }

        @objc func handleMagnify(_ gr: NSMagnificationGestureRecognizer) {
            guard let view = scnView, let scene = view.scene else { return }
            let delta = CGFloat(gr.magnification)
            if true {
                let controller = view.defaultCameraController
                let amount: Float = Float(delta) * 200.0
                let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
                controller.dolly(by: amount, onScreenPoint: center, viewport: view.bounds.size)
            } else if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                var pos = cameraNode.position
                pos.z -= SCNFloat(delta) * 0.5
                pos.z = max(0.2, min(5.0, pos.z))
                cameraNode.position = pos
            }
        }
    }
}

private extension CGImage {
    static func makeBlackPixel() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage()!
    }
}
