import SwiftUI
import SceneKit

/// A SceneKit 3D board. Pieces are built from primitives so no assets are required.
/// The scene is created once and updated incrementally, with animated moves.
struct Board3DView: UIViewRepresentable {
    let position: Position
    let interaction: BoardInteraction
    var cameraPreset: CameraPreset
    var onTap: (Square) -> Void

    @EnvironmentObject private var settings: AppSettings

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = false
        let coordinator = context.coordinator
        coordinator.build(in: view, light: UIColor(settings.lightSquare), dark: UIColor(settings.darkSquare), frame: UIColor(settings.boardTheme.frame))
        coordinator.onTap = onTap
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        coordinator.setOrientation(interaction.orientation, animated: false)
        coordinator.setElevation(cameraPreset.elevation, animated: false)
        coordinator.sync(position: position, animated: false)
        coordinator.applyHighlights(interaction)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.onTap = onTap
        c.updateColors(light: UIColor(settings.lightSquare), dark: UIColor(settings.darkSquare), frame: UIColor(settings.boardTheme.frame))
        c.setOrientation(interaction.orientation, animated: true)
        if c.lastPreset != cameraPreset {
            c.lastPreset = cameraPreset
            c.setElevation(cameraPreset.elevation, animated: true)
        }
        c.sync(position: position, animated: settings.animations)
        c.applyHighlights(interaction)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onTap: ((Square) -> Void)?
        var lastPreset: CameraPreset?
        private weak var view: SCNView?
        private let scene = SCNScene()
        private let boardRoot = SCNNode()          // rotates for orientation
        private let cameraOrbit = SCNNode()        // yaw
        private let cameraPitch = SCNNode()        // elevation
        private let cameraNode = SCNNode()
        private var squareNodes: [SCNNode] = []
        private var squareMaterials: [SCNMaterial] = []
        private var pieceNodes: [Int: SCNNode] = [:]   // square index -> node
        private var pieceKinds: [Int: Piece] = [:]
        private var highlightNodes: [SCNNode] = []
        private var lastPositionFEN = ""
        private var yaw: Double = 0
        private var elevation: Double = 50
        private var distance: Double = 13.8
        private var lightColor = UIColor.white
        private var darkColor = UIColor.gray
        private var frameMaterial = SCNMaterial()
        private var orientation: PieceColor = .white
        private let squareSize: CGFloat = 1.0

        func build(in view: SCNView, light: UIColor, dark: UIColor, frame: UIColor) {
            self.view = view
            lightColor = light
            darkColor = dark
            view.scene = scene
            scene.rootNode.addChildNode(boardRoot)

            // Board frame
            let frameGeo = SCNBox(width: 9.2, height: 0.45, length: 9.2, chamferRadius: 0.12)
            frameMaterial.diffuse.contents = frame
            frameMaterial.roughness.contents = 0.55
            frameMaterial.metalness.contents = 0.05
            frameMaterial.lightingModel = .physicallyBased
            frameGeo.materials = [frameMaterial]
            let frameNode = SCNNode(geometry: frameGeo)
            frameNode.position = SCNVector3(0, -0.23, 0)
            boardRoot.addChildNode(frameNode)

            // Squares
            for rank in 0..<8 {
                for file in 0..<8 {
                    let sq = Square(file: file, rank: rank)
                    let geo = SCNBox(width: squareSize, height: 0.08, length: squareSize, chamferRadius: 0.0)
                    let mat = SCNMaterial()
                    mat.diffuse.contents = sq.isLight ? light : dark
                    mat.roughness.contents = 0.35
                    mat.lightingModel = .physicallyBased
                    geo.materials = [mat]
                    let node = SCNNode(geometry: geo)
                    node.position = worldPosition(for: sq, y: 0.04)
                    node.name = "sq\(sq.index)"
                    boardRoot.addChildNode(node)
                    squareNodes.append(node)
                    squareMaterials.append(mat)
                }
            }

            // Coordinates on the frame
            for i in 0..<8 {
                addLabel("abcdefgh"[String.Index(utf16Offset: i, in: "abcdefgh")].uppercased(), at: SCNVector3(Float(i) - 3.5, 0.02, 4.35))
                addLabel("\(i + 1)", at: SCNVector3(-4.35, 0.02, 3.5 - Float(i)))
            }

            // Camera rig
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 40
            cameraNode.camera?.wantsHDR = false
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 100
            cameraNode.position = SCNVector3(0, 0, Float(distance))
            cameraPitch.addChildNode(cameraNode)
            cameraOrbit.addChildNode(cameraPitch)
            scene.rootNode.addChildNode(cameraOrbit)
            cameraNode.look(at: SCNVector3(0, 0, 0))

            // Lights
            let key = SCNLight()
            key.type = .directional
            key.intensity = 900
            key.castsShadow = true
            key.shadowMode = .deferred
            key.shadowRadius = 6
            key.shadowSampleCount = 8
            key.shadowColor = UIColor(white: 0, alpha: 0.45)
            key.orthographicScale = 8
            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
            scene.rootNode.addChildNode(keyNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 420
            ambient.color = UIColor(white: 0.9, alpha: 1)
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let fill = SCNLight()
            fill.type = .omni
            fill.intensity = 350
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.position = SCNVector3(-6, 8, -6)
            scene.rootNode.addChildNode(fillNode)

            updateCamera(animated: false)
        }

        private func addLabel(_ text: String, at pos: SCNVector3) {
            let t = SCNText(string: text, extrusionDepth: 0.01)
            t.font = UIFont.systemFont(ofSize: 0.30, weight: .bold)
            t.flatness = 0.2
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(white: 1, alpha: 0.75)
            t.materials = [mat]
            let node = SCNNode(geometry: t)
            let (minB, maxB) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2 + minB.x, (maxB.y - minB.y) / 2 + minB.y, 0)
            node.position = pos
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            boardRoot.addChildNode(node)
        }

        func updateColors(light: UIColor, dark: UIColor, frame: UIColor) {
            guard light != lightColor || dark != darkColor else { return }
            lightColor = light
            darkColor = dark
            frameMaterial.diffuse.contents = frame
            for (i, mat) in squareMaterials.enumerated() {
                mat.diffuse.contents = Square(i).isLight ? light : dark
            }
        }

        private func worldPosition(for square: Square, y: Float) -> SCNVector3 {
            SCNVector3(Float(square.file) - 3.5, y, 3.5 - Float(square.rank))
        }

        // MARK: Camera

        func setOrientation(_ color: PieceColor, animated: Bool) {
            guard color != orientation else { return }
            orientation = color
            yaw = color == .white ? 0 : Double.pi
            updateCamera(animated: animated)
        }

        func setElevation(_ degrees: Double, animated: Bool) {
            elevation = degrees
            updateCamera(animated: animated)
        }

        private func updateCamera(animated: Bool) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.6 : 0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cameraOrbit.eulerAngles = SCNVector3(0, Float(yaw), 0)
            cameraPitch.eulerAngles = SCNVector3(Float(-elevation * .pi / 180), 0, 0)
            cameraNode.position = SCNVector3(0, 0, Float(distance))
            SCNTransaction.commit()
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            g.setTranslation(.zero, in: g.view)
            yaw -= Double(t.x) * 0.008
            elevation = min(85, max(20, elevation + Double(t.y) * 0.25))
            updateCamera(animated: false)
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            distance = min(20, max(9, distance / Double(g.scale)))
            g.scale = 1
            updateCamera(animated: false)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let view else { return }
            let point = g.location(in: view)
            let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
            for hit in hits {
                var node: SCNNode? = hit.node
                while let n = node {
                    if let name = n.name {
                        if name.hasPrefix("sq"), let idx = Int(name.dropFirst(2)) { onTap?(Square(idx)); return }
                        if name.hasPrefix("piece"), let idx = Int(name.dropFirst(5)) { onTap?(Square(idx)); return }
                    }
                    node = n.parent
                }
            }
        }

        // MARK: Pieces

        func sync(position: Position, animated: Bool) {
            let fen = position.fen
            guard fen != lastPositionFEN else { return }
            lastPositionFEN = fen

            var desired: [Int: Piece] = [:]
            for i in 0..<64 { if let p = position.board[i] { desired[i] = p } }

            // Work out which nodes can slide to new squares (same piece kind vanished from A and appeared on B).
            var removed: [Int: Piece] = [:]
            var added: [Int: Piece] = [:]
            for (idx, piece) in pieceKinds where desired[idx] != piece { removed[idx] = piece }
            for (idx, piece) in desired where pieceKinds[idx] != piece { added[idx] = piece }

            var moves: [(from: Int, to: Int)] = []
            for (to, piece) in added {
                if let from = removed.first(where: { $0.value == piece })?.key {
                    moves.append((from, to))
                    removed.removeValue(forKey: from)
                    added.removeValue(forKey: to)
                }
            }

            let duration: TimeInterval = animated ? 0.28 : 0
            // Captures: fade out anything left in `removed` that isn't being replaced by a slide.
            for (idx, _) in removed {
                guard let node = pieceNodes[idx], !moves.contains(where: { $0.to == idx }) else {
                    if let node = pieceNodes[idx], moves.contains(where: { $0.to == idx }) {
                        // captured piece on a destination square
                        let fade = SCNAction.sequence([SCNAction.fadeOut(duration: duration), SCNAction.removeFromParentNode()])
                        node.name = nil
                        node.runAction(fade)
                        pieceNodes.removeValue(forKey: idx)
                    }
                    continue
                }
                let fade = SCNAction.sequence([SCNAction.fadeOut(duration: duration), SCNAction.removeFromParentNode()])
                node.name = nil
                node.runAction(fade)
                pieceNodes.removeValue(forKey: idx)
            }
            for move in moves {
                guard let node = pieceNodes[move.from] else { continue }
                pieceNodes.removeValue(forKey: move.from)
                if let existing = pieceNodes[move.to] {
                    existing.name = nil
                    existing.runAction(SCNAction.sequence([SCNAction.fadeOut(duration: duration), SCNAction.removeFromParentNode()]))
                }
                pieceNodes[move.to] = node
                node.name = "piece\(move.to)"
                let target = worldPosition(for: Square(move.to), y: 0.08)
                if animated {
                    let lift = SCNAction.move(by: SCNVector3(0, 0.5, 0), duration: duration * 0.4)
                    let slide = SCNAction.move(to: SCNVector3(target.x, target.y + 0.5, target.z), duration: duration * 0.6)
                    let drop = SCNAction.move(to: target, duration: duration * 0.35)
                    drop.timingMode = .easeIn
                    node.runAction(SCNAction.sequence([lift, slide, drop]))
                } else {
                    node.position = target
                }
            }
            for (idx, piece) in added {
                let node = makePiece(piece)
                node.name = "piece\(idx)"
                node.position = worldPosition(for: Square(idx), y: 0.08)
                if animated {
                    node.opacity = 0
                    node.runAction(SCNAction.fadeIn(duration: duration))
                }
                if let existing = pieceNodes[idx] { existing.removeFromParentNode() }
                boardRoot.addChildNode(node)
                pieceNodes[idx] = node
            }
            pieceKinds = desired
        }

        private func material(for color: PieceColor) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = color == .white ? UIColor(red: 0.94, green: 0.91, blue: 0.84, alpha: 1) : UIColor(red: 0.16, green: 0.14, blue: 0.15, alpha: 1)
            m.roughness.contents = color == .white ? 0.35 : 0.3
            m.metalness.contents = 0.08
            return m
        }

        private func makePiece(_ piece: Piece) -> SCNNode {
            let root = SCNNode()
            let mat = material(for: piece.color)
            func add(_ geo: SCNGeometry, y: Float, scale: Float = 1) {
                geo.materials = [mat]
                let n = SCNNode(geometry: geo)
                n.position = SCNVector3(0, y, 0)
                n.scale = SCNVector3(scale, scale, scale)
                root.addChildNode(n)
            }
            // Common base
            add(SCNCylinder(radius: 0.36, height: 0.10), y: 0.05)
            add(SCNCylinder(radius: 0.30, height: 0.08), y: 0.14)
            switch piece.kind {
            case .pawn:
                add(SCNCone(topRadius: 0.13, bottomRadius: 0.24, height: 0.45), y: 0.40)
                add(SCNTorus(ringRadius: 0.13, pipeRadius: 0.05), y: 0.64)
                add(SCNSphere(radius: 0.17), y: 0.82)
            case .rook:
                add(SCNCone(topRadius: 0.22, bottomRadius: 0.27, height: 0.65), y: 0.50)
                add(SCNCylinder(radius: 0.28, height: 0.12), y: 0.88)
                for i in 0..<4 {
                    let box = SCNBox(width: 0.14, height: 0.14, length: 0.14, chamferRadius: 0.02)
                    box.materials = [mat]
                    let n = SCNNode(geometry: box)
                    let a = Float(i) * .pi / 2 + .pi / 4
                    n.position = SCNVector3(cos(a) * 0.19, 1.0, sin(a) * 0.19)
                    root.addChildNode(n)
                }
            case .knight:
                add(SCNCone(topRadius: 0.20, bottomRadius: 0.27, height: 0.45), y: 0.40)
                let body = SCNBox(width: 0.30, height: 0.55, length: 0.26, chamferRadius: 0.08)
                body.materials = [mat]
                let bodyNode = SCNNode(geometry: body)
                bodyNode.position = SCNVector3(0, 0.85, 0.02)
                bodyNode.eulerAngles = SCNVector3(-0.35, 0, 0)
                root.addChildNode(bodyNode)
                let head = SCNBox(width: 0.24, height: 0.24, length: 0.46, chamferRadius: 0.07)
                head.materials = [mat]
                let headNode = SCNNode(geometry: head)
                headNode.position = SCNVector3(0, 1.10, 0.20)
                headNode.eulerAngles = SCNVector3(0.25, 0, 0)
                root.addChildNode(headNode)
                let ear = SCNCone(topRadius: 0.0, bottomRadius: 0.07, height: 0.16)
                ear.materials = [mat]
                for dx in [-0.07, 0.07] as [Float] {
                    let e = SCNNode(geometry: ear)
                    e.position = SCNVector3(dx, 1.26, 0.02)
                    root.addChildNode(e)
                }
                // Knights face the opponent.
                root.eulerAngles = SCNVector3(0, piece.color == .white ? 0 : Float.pi, 0)
            case .bishop:
                add(SCNCone(topRadius: 0.12, bottomRadius: 0.26, height: 0.70), y: 0.52)
                add(SCNTorus(ringRadius: 0.13, pipeRadius: 0.04), y: 0.89)
                let head = SCNSphere(radius: 0.17)
                head.materials = [mat]
                let hn = SCNNode(geometry: head)
                hn.position = SCNVector3(0, 1.05, 0)
                hn.scale = SCNVector3(1, 1.3, 1)
                root.addChildNode(hn)
                add(SCNSphere(radius: 0.05), y: 1.32)
            case .queen:
                add(SCNCone(topRadius: 0.14, bottomRadius: 0.28, height: 0.85), y: 0.60)
                add(SCNTorus(ringRadius: 0.16, pipeRadius: 0.05), y: 1.05)
                add(SCNCone(topRadius: 0.24, bottomRadius: 0.14, height: 0.22), y: 1.18)
                for i in 0..<6 {
                    let s = SCNSphere(radius: 0.05)
                    s.materials = [mat]
                    let n = SCNNode(geometry: s)
                    let a = Float(i) * .pi / 3
                    n.position = SCNVector3(cos(a) * 0.20, 1.32, sin(a) * 0.20)
                    root.addChildNode(n)
                }
                add(SCNSphere(radius: 0.09), y: 1.40)
            case .king:
                add(SCNCone(topRadius: 0.15, bottomRadius: 0.29, height: 0.90), y: 0.63)
                add(SCNTorus(ringRadius: 0.17, pipeRadius: 0.05), y: 1.10)
                add(SCNCone(topRadius: 0.22, bottomRadius: 0.15, height: 0.20), y: 1.22)
                add(SCNBox(width: 0.08, height: 0.34, length: 0.08, chamferRadius: 0.01), y: 1.50)
                add(SCNBox(width: 0.24, height: 0.08, length: 0.08, chamferRadius: 0.01), y: 1.55)
            }
            let scale: Float = piece.kind == .pawn ? 0.82 : 0.86
            root.scale = SCNVector3(scale, scale, scale)
            return root
        }

        // MARK: Highlights

        func applyHighlights(_ interaction: BoardInteraction) {
            highlightNodes.forEach { $0.removeFromParentNode() }
            highlightNodes.removeAll()
            func plate(_ sq: Square, color: UIColor, height: Float = 0.085, inset: CGFloat = 0.0) {
                let geo = SCNBox(width: squareSize - inset, height: 0.02, length: squareSize - inset, chamferRadius: 0.02)
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.lightingModel = .constant
                m.transparency = CGFloat(color.cgColor.alpha)
                geo.materials = [m]
                let n = SCNNode(geometry: geo)
                n.position = worldPosition(for: sq, y: height)
                n.name = "sq\(sq.index)"
                boardRoot.addChildNode(n)
                highlightNodes.append(n)
            }
            func dot(_ sq: Square, capture: Bool) {
                let geo: SCNGeometry = capture ? SCNTorus(ringRadius: 0.36, pipeRadius: 0.05) : SCNCylinder(radius: 0.14, height: 0.03)
                let m = SCNMaterial()
                m.diffuse.contents = UIColor(white: 0.05, alpha: 0.35)
                m.lightingModel = .constant
                m.transparency = 0.5
                geo.materials = [m]
                let n = SCNNode(geometry: geo)
                n.position = worldPosition(for: sq, y: 0.11)
                n.name = "sq\(sq.index)"
                boardRoot.addChildNode(n)
                highlightNodes.append(n)
            }
            if let last = interaction.lastMove {
                plate(last.0, color: UIColor.systemYellow.withAlphaComponent(0.55))
                plate(last.1, color: UIColor.systemYellow.withAlphaComponent(0.55))
            }
            if let check = interaction.checkSquare { plate(check, color: UIColor.systemRed.withAlphaComponent(0.6)) }
            for sq in interaction.threatSquares { plate(sq, color: UIColor.systemRed.withAlphaComponent(0.35), inset: 0.15) }
            for sq in interaction.coachSquares { plate(sq, color: UIColor.systemBlue.withAlphaComponent(0.3)) }
            if let sel = interaction.selected { plate(sel, color: UIColor(Duo.accent).withAlphaComponent(0.7), height: 0.09) }
            if let pending = interaction.pendingConfirm { plate(pending.to, color: UIColor(Duo.mint).withAlphaComponent(0.6), height: 0.09) }
            for sq in interaction.legalTargets { dot(sq, capture: interaction.captureTargets.contains(sq)) }
            if let hint = interaction.hintMove {
                plate(hint.from, color: UIColor(Duo.mint).withAlphaComponent(0.55), height: 0.09)
                plate(hint.to, color: UIColor(Duo.mint).withAlphaComponent(0.55), height: 0.09)
            }
        }
    }
}
