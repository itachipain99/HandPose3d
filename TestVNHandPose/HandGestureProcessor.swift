/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This class is a state machine that transitions between states based on pair
    of points stream. These points are the tips for thumb and index finger.
    If the tips are closer than the desired distance, the state is "pinched", otherwise it's "apart".
    There are also "possiblePinch" and "possibeApart" states that are used to smooth out state transitions.
    During these possible states HandGestureProcessor collects the required amount of evidence before committing to a definite state.
*/

import CoreGraphics

class HandGestureProcessor {
    enum State {
        case possiblePinch
        case pinched
        case possibleApart
        case apart
        case unknown
    }
    
    typealias PointsPair = (indexMCP: CGPoint, litterMCP: CGPoint,wrist : CGPoint,midMCP : CGPoint)
    
    private var state = State.unknown {
        didSet {
            didChangeStateClosure?(state)
        }
    }
    private var pinchEvidenceCounter = 0
    private var apartEvidenceCounter = 0
    private let pinchMaxDistance: CGFloat
    private let evidenceCounterStateTrigger: Int
    
    var didChangeStateClosure: ((State) -> Void)?
    private (set) var lastProcessedPointsPair = PointsPair(.zero, .zero,.zero,.zero)
    
    init(pinchMaxDistance: CGFloat = 40, evidenceCounterStateTrigger: Int = 3) {
        self.pinchMaxDistance = pinchMaxDistance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    func reset() {
        state = .unknown
        pinchEvidenceCounter = 0
        apartEvidenceCounter = 0
    }
    
    func getAngleX(_ pointsPair: PointsPair) -> CGFloat {
//        change = vector
        let vectorIndex = pointsPair.indexMCP.vector(from : pointsPair.wrist)
//        print(vector)
        let vectorLittle = pointsPair.litterMCP.vector(from: pointsPair.wrist)
        let angle = atan2(vectorLittle.dy,vectorLittle.dx) - atan2(vectorIndex.dy, vectorIndex.dx)
        return angle
//        print(angle)
//        lastProcessedPointsPair = pointsPair
//        let distance = pointsPair.indexMCP.distance(from: pointsPair.litterMCP)
//        if distance < pinchMaxDistance {
//            // Keep accumulating evidence for pinch state.
//            pinchEvidenceCounter += 1
////            print(pinchEvidenceCounter)
//            apartEvidenceCounter = 0
//            // Set new state based on evidence amount.
//            state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .pinched : .possiblePinch
//        } else {
//            // Keep accumulating evidence for apart state.
//            apartEvidenceCounter += 1
////            print(apartEvidenceCounter)
//            pinchEvidenceCounter = 0
//            // Set new state based on evidence amount.
//            state = (apartEvidenceCounter >= evidenceCounterStateTrigger) ? .apart : .possibleApart
//        }
    }
    func getAngleZ(_ pointsPair: PointsPair) -> CGFloat{
        let vectorWrist = pointsPair.midMCP.vector(from: pointsPair.wrist)
        let angle = acos(vectorWrist.lengthVector(p1: vectorWrist))
        return angle
    }
}

// MARK: - CGPoint helpers

extension CGPoint {
    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }

    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
    
    func vector(from p2:CGPoint) -> CGVector {
        return CGVector(dx: p2.x - x, dy: p2.y - y)
    }
}

extension CGVector {
    func lengthVector(p1 : CGVector) -> CGFloat {
        return CGFloat(p1.dx/sqrt(p1.dx*p1.dx + p1.dy*p1.dy))
    }
}

//MARK:- VECTOR
