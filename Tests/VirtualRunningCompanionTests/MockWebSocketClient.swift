import Foundation
import Combine
@testable import VirtualRunningCompanion

class MockWebSocketClient: WebSocketClientProtocol {
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let messageReceivedSubject = PassthroughSubject<WebSocketMessage, Never>()
    
    private var isConnectedValue = false
    private var sentMessages: [WebSocketMessage] = []
    
    // MARK: - Protocol Implementation
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    
    var messageReceived: AnyPublisher<WebSocketMessage, Never> {
        messageReceivedSubject.eraseToAnyPublisher()
    }
    
    func connect(to url: URL) {
        connectionStatusSubject.send(.connecting)
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isConnectedValue = true
            self.connectionStatusSubject.send(.connected)
        }
    }
    
    func disconnect() {
        isConnectedValue = false
        connectionStatusSubject.send(.disconnected)
    }
    
    func send(message: WebSocketMessage) {
        guard isConnectedValue else { return }
        sentMessages.append(message)
        
        // Simulate server responses for certain message types
        simulateServerResponse(for: message)
    }
    
    func isConnected() -> Bool {
        return isConnectedValue
    }
    
    // MARK: - Test Helper Methods
    
    func getSentMessages() -> [WebSocketMessage] {
        return sentMessages
    }
    
    func clearSentMessages() {
        sentMessages.removeAll()
    }
    
    func simulateConnectionError(_ error: String) {
        connectionStatusSubject.send(.error(error))
    }
    
    func simulateDisconnection() {
        isConnectedValue = false
        connectionStatusSubject.send(.disconnected)
    }
    
    func simulateReconnection() {
        isConnectedValue = true
        connectionStatusSubject.send(.connected)
    }
    
    func simulateIncomingMessage(_ message: WebSocketMessage) {
        messageReceivedSubject.send(message)
    }
    
    func simulateFriendUpdate(userId: String, sessionId: String, pace: Double, location: LocationCoordinate) {
        let friendUpdate = FriendUpdateData(
            userId: userId,
            sessionId: sessionId,
            pace: pace,
            location: location,
            timestamp: Date(),
            status: "running"
        )
        
        do {
            let data = try JSONEncoder().encode(friendUpdate)
            let message = WebSocketMessage(
                type: .friendUpdate,
                data: data,
                timestamp: Date()
            )
            simulateIncomingMessage(message)
        } catch {
            print("Failed to encode friend update: \(error)")
        }
    }
    
    func simulateSessionStatus(sessionId: String, participants: [String], status: String) {
        let sessionStatus = SessionStatusData(
            sessionId: sessionId,
            participants: participants,
            status: status
        )
        
        do {
            let data = try JSONEncoder().encode(sessionStatus)
            let message = WebSocketMessage(
                type: .sessionStatus,
                data: data,
                timestamp: Date()
            )
            simulateIncomingMessage(message)
        } catch {
            print("Failed to encode session status: \(error)")
        }
    }
    
    func simulateError(_ errorMessage: String) {
        let data = errorMessage.data(using: .utf8) ?? Data()
        let message = WebSocketMessage(
            type: .error,
            data: data,
            timestamp: Date()
        )
        simulateIncomingMessage(message)
    }
    
    // MARK: - Private Methods
    
    private func simulateServerResponse(for message: WebSocketMessage) {
        switch message.type {
        case .joinSession:
            // Simulate successful join response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let joinData = try? JSONDecoder().decode(JoinSessionData.self, from: message.data) {
                    self.simulateSessionStatus(
                        sessionId: joinData.sessionId,
                        participants: [joinData.userId] + joinData.friends,
                        status: "active"
                    )
                }
            }
            
        case .ping:
            // Respond with pong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let pongMessage = WebSocketMessage(
                    type: .pong,
                    data: Data(),
                    timestamp: Date()
                )
                self.simulateIncomingMessage(pongMessage)
            }
            
        default:
            break
        }
    }
}