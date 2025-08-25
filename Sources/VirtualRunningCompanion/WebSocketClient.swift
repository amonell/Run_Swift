import Foundation
import Combine

// MARK: - WebSocket Message Types
public struct WebSocketMessage: Codable {
    let type: MessageType
    let data: Data
    let timestamp: Date
    
    public enum MessageType: String, Codable {
        case joinSession = "join_session"
        case leaveSession = "leave_session"
        case paceUpdate = "pace_update"
        case friendUpdate = "friend_update"
        case sessionStatus = "session_status"
        case error = "error"
        case ping = "ping"
        case pong = "pong"
    }
}

struct JoinSessionData: Codable {
    let sessionId: String
    let userId: String
    let friends: [String] // Friend user IDs
}

public struct PaceUpdateData: Codable {
    let userId: String
    let sessionId: String
    let pace: Double
    let location: LocationCoordinate2D
    let timestamp: Date
}

public struct FriendUpdateData: Codable {
    let userId: String
    let sessionId: String
    let pace: Double
    let location: LocationCoordinate2D
    let timestamp: Date
    let status: String
}

struct SessionStatusData: Codable {
    let sessionId: String
    let participants: [String]
    let status: String
}

// MARK: - WebSocket Client Protocol
#if canImport(Combine)
public protocol WebSocketClientProtocol {
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> { get }
    var messageReceived: AnyPublisher<WebSocketMessage, Never> { get }
    
    func connect(to url: URL)
    func disconnect()
    func send(message: WebSocketMessage)
    func isConnected() -> Bool
}
#else
public protocol WebSocketClientProtocol {
    func connect(to url: URL)
    func disconnect()
    func send(message: WebSocketMessage)
    func isConnected() -> Bool
}
#endif

// MARK: - WebSocket Client Implementation
public class WebSocketClient: NSObject, WebSocketClientProtocol {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let messageReceivedSubject = PassthroughSubject<WebSocketMessage, Never>()
    
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    private let pingInterval: TimeInterval = 30.0
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    
    var messageReceived: AnyPublisher<WebSocketMessage, Never> {
        messageReceivedSubject.eraseToAnyPublisher()
    }
    
    public override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: configuration)
        super.init()
    }
    
    public func connect(to url: URL) {
        guard webSocketTask == nil else { return }
        
        connectionStatusSubject.send(.connecting)
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.delegate = self
        webSocketTask?.resume()
        
        startListening()
        startPingTimer()
    }
    
    public func disconnect() {
        stopReconnectTimer()
        stopPingTimer()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        connectionStatusSubject.send(.disconnected)
    }
    
    public func send(message: WebSocketMessage) {
        guard isConnected() else {
            print("WebSocket not connected, cannot send message")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let message = URLSessionWebSocketTask.Message.data(data)
            
            webSocketTask?.send(message) { [weak self] error in
                if let error = error {
                    print("Failed to send WebSocket message: \(error)")
                    self?.handleConnectionError(error)
                }
            }
        } catch {
            print("Failed to encode WebSocket message: \(error)")
        }
    }
    
    public func isConnected() -> Bool {
        return webSocketTask?.state == .running
    }
    
    // MARK: - Private Methods
    
    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleReceivedMessage(message)
                self?.startListening() // Continue listening
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }
    
    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let webSocketMessage = try JSONDecoder().decode(WebSocketMessage.self, from: data)
                
                // Handle pong messages internally
                if webSocketMessage.type == .pong {
                    // Connection is alive, reset reconnect attempts
                    reconnectAttempts = 0
                    return
                }
                
                messageReceivedSubject.send(webSocketMessage)
            } catch {
                print("Failed to decode WebSocket message: \(error)")
            }
            
        case .string(let text):
            print("Received text message (not supported): \(text)")
            
        @unknown default:
            print("Received unknown WebSocket message type")
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        connectionStatusSubject.send(.error(error.localizedDescription))
        
        // Attempt reconnection if not manually disconnected
        if webSocketTask?.state != .canceling {
            attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionStatusSubject.send(.error("Max reconnection attempts reached"))
            return
        }
        
        reconnectAttempts += 1
        connectionStatusSubject.send(.connecting)
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay * Double(reconnectAttempts), repeats: false) { [weak self] _ in
            guard let self = self, let url = self.webSocketTask?.originalRequest?.url else { return }
            
            self.webSocketTask?.cancel()
            self.webSocketTask = nil
            
            self.connect(to: url)
        }
    }
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let pingMessage = WebSocketMessage(
            type: .ping,
            data: Data(),
            timestamp: Date()
        )
        send(message: pingMessage)
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        connectionStatusSubject.send(.connected)
        reconnectAttempts = 0
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        connectionStatusSubject.send(.disconnected)
        
        // Attempt reconnection unless it was a manual disconnect
        if closeCode != .goingAway {
            attemptReconnection()
        }
    }
}