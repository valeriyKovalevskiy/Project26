//
//  GameScene.swift
//  Project26
//
//  Created by Valeriy Kovalevskiy on 5/18/20.
//  Copyright © 2020 v.kovalevskiy. All rights reserved.
//

import SpriteKit
import CoreMotion

enum CollisionTypes: UInt32 {
    case player = 1
    case wall = 2
    case star = 4
    case vortex = 8
    case finish = 16
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    //MARK:- GameScene class
    var player: SKSpriteNode!
    var lastTouchPosition: CGPoint?
    var motionManager: CMMotionManager!
    var isGameOver = false
    var scoreLabel: SKLabelNode!
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    var teleporters = [SKSpriteNode]()

    func playerCollided(with node: SKNode) {
        if node.name == "vortex" {
            player.physicsBody?.isDynamic = false
            isGameOver = true
            score -= 1
            let move = SKAction.move(to: node.position,
                                     duration: 0.25)
            let scale = SKAction.scale(to: 0.0001,
                                       duration: 0.25)
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([move, scale, remove])

            player.run(sequence) { [weak self] in
                self?.createPlayer()
                self?.isGameOver = false
            }
        } else if node.name == "star" {
            node.removeFromParent()
            score += 1
        } else if node.name == "teleporter" {

            player.physicsBody?.isDynamic = false
            let move = SKAction.move(to: node.position,
                                     duration: 0.25)
            let scale = SKAction.scale(to: 0.0001,
                                       duration: 0.25)
            let node2 = findOtherTeleporter(opposite: node)
            node2.physicsBody = nil
            let scale2 = SKAction.scale(to: 1.0,
                                       duration: 0.25)
            let move2 = SKAction.move(to: node2.position,
                                     duration: 0.25)
            let restorePhysics = SKAction.run {
                self.player.physicsBody?.isDynamic = true
            }
            let sequence = SKAction.sequence([move, scale, move2, scale2, restorePhysics])
            player.run(sequence)
        } else if node.name == "finish" {
            // next level?
            player.physicsBody?.isDynamic = false
            let move = SKAction.move(to: node.position,
                                     duration: 0.25)
            let scale = SKAction.scale(to: 0.0001,
                                       duration: 0.25)
            let remove = SKAction.removeFromParent()
            let nextLevel = SKAction.run {
                self.nextLevel()
            }
            let sequence = SKAction.sequence([move, scale, remove, nextLevel])
            player.run(sequence)
        }
    }

    func findOtherTeleporter(opposite node: SKNode) -> SKSpriteNode {
        var result = teleporters.first!
        for n in teleporters {
            if n != node {
                return n
            }
        }
        return result
    }


    func nextLevel() {
        teleporters.removeAll(keepingCapacity: true)
        levelNode.removeAllChildren()
        loadLevel(named: "level2")
        createPlayer()
    }

    func gameOver() {
        self.isGameOver = true
        self.score += 10

        let gameOver = SKSpriteNode(imageNamed: "gameOver")
        gameOver.position = CGPoint(x: 512,
                                    y: 384)
        gameOver.zPosition = 1
        gameOver.xScale = 0.001
        gameOver.yScale = 0.001

        let finalScore = SKLabelNode(fontNamed: "Chalkduster")
        finalScore.text = "Final Score: \(score)"
        finalScore.position = CGPoint(x: 0,
                                      y: gameOver.anchorPoint.y + (gameOver.texture?.size().height)!)
        finalScore.horizontalAlignmentMode = .center
        finalScore.fontSize = 60

        gameOver.addChild(finalScore)

        addChild(gameOver)
        let scale = SKAction.scale(to: 1.0,
                                   duration: 0.25)
        gameOver.run(scale)

        UIView.animate(withDuration: 1,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 5,
                       options: [],
                       animations: {
                           gameOver.xScale = 1.0
                           gameOver.yScale = 1.0
                       })
    }

    func createPlayer() {
        player = SKSpriteNode(imageNamed: "player")
        player.position = CGPoint(x: 96,
                                  y: 672)
        player.zPosition = 1
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 0.5

        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        // We care about contacts
        player.physicsBody?.contactTestBitMask = CollisionTypes.star.rawValue | CollisionTypes.vortex.rawValue | CollisionTypes.finish.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.wall.rawValue
        addChild(player)
    }

    func loadLevel(named level: String) {
        // Create a url to an item in the main bundle
        guard let levelURL = Bundle.main.url(forResource: level,
                                             withExtension: "txt") else {
            fatalError("Could not find level1.txt in the app bundle.")
        }
        // Load the contents of that item
        guard let levelString = try? String(contentsOf: levelURL) else {
            fatalError("Could not load level1.txt from the app bundle.")
        }

        // Split the text based on the newline
        let lines = levelString.components(separatedBy: "\n")

        // Start at the bottom by reversing the lines, create the bottom row first
        for (row, line) in lines.reversed().enumerated() {
            for (column, letter) in line.enumerated() {
                let position = CGPoint(x: (64 * column) + 32,
                                       y: (64 * row) + 32)
                if letter == "x" {
                    let node = createWall(position: position)
                    levelNode.addChild(node)
                } else if letter == "v" {
                    let node = createVortex(position: position)
                    levelNode.addChild(node)
                } else if letter == "s" {
                    let node = createStar(position: position)
                    levelNode.addChild(node)
                } else if letter == "f" {
                    let node = createTrophy(position: position)
                    levelNode.addChild(node)
                } else if letter == "t" {
                    let node = createTeleporter(position: position)
                    teleporters.append(node)
                    levelNode.addChild(node)
                } else if letter == " " {
                    // this is an empty space – do nothing!
                } else {
                    fatalError("Unknown level letter: \(letter)")
                }
            }
        }
    }

    func createTeleporter(position: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "teleporter")
        node.name = "teleporter"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.star.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue // We care of the player contacts teleporter
        node.physicsBody?.collisionBitMask = 0
        node.position = position
        return node
    }

    func createTrophy(position: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "finish")
        node.name = "finish"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.finish.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue // We care of the player contacts trophy
        node.physicsBody?.collisionBitMask = 0
        node.position = position
        return node
    }

    private func createStar(position: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "star")
        node.name = "star"
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.star.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue // We care of the player contacts star
        node.physicsBody?.collisionBitMask = 0
        node.position = position
        return node
    }

    private func createVortex(position: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "vortex")
        node.name = "vortex"
        node.position = position
        node.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi,
                                                        duration: 1)))
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = CollisionTypes.vortex.rawValue
        node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue // We care of the player contacts vortex
        node.physicsBody?.collisionBitMask = 0
        return node
    }

    func createWall(position: CGPoint) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "block")
        node.position = position
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        node.physicsBody?.categoryBitMask = CollisionTypes.wall.rawValue
        node.physicsBody?.isDynamic = false
        return node
    }

    //MARK:- SKPhysicsContactDelegate protocol
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }

        if nodeA == player {
            playerCollided(with: nodeB)
        } else if nodeB == player {
            playerCollided(with: nodeA)
        }
    }

    var levelNode = SKNode()

    //MARK:- SKScene class
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 512,
                                      y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        addChild(levelNode)

        scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        scoreLabel.text = "Score: 0"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 16,
                                      y: 16)
        scoreLabel.zPosition = 2
        addChild(scoreLabel)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()

        loadLevel(named: "level1")
        createPlayer()
    }

    override func update(_ currentTime: TimeInterval) {
        guard isGameOver == false else { return }

        #if targetEnvironment(simulator)
            if let currentTouch = lastTouchPosition {
                let diff = CGPoint(x: currentTouch.x - player.position.x,
                                   y: currentTouch.y - player.position.y)
                physicsWorld.gravity = CGVector(dx: diff.x / 100,
                                                dy: diff.y / 100)
            }
        #else
            if let accelerometerData = motionManager.accelerometerData {
                physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.y * -50,
                                                dy: accelerometerData.acceleration.x * 50)
            }
        #endif
    }

    //MARK:- UIResponder class
    override func touchesBegan(_ touches: Set<UITouch>,
                               with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>,
                               with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchPosition = location
    }

    override func touchesEnded(_ touches: Set<UITouch>,
                               with event: UIEvent?) {
        lastTouchPosition = nil
    }
}
