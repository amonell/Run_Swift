import Foundation

enum ConnectionStatus: Equatable {
    case connected
    case connecting
    case disconnected
    case error(String)
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        return self == .connected
    }
    
    var canStartSynchronizedRun: Bool {
        return self == .connected
    }
    
    // MARK: - Error Handling
    
    var errorMessage: String? {
        switch self {
        case .error(let message):
            return message
        default:
            return nil
        }
    }
    
    static func error(from error: Error) -> ConnectionStatus {
        return .error(error.localizedDescription)
    }
}

// MARK: - Codable Implementation
extension ConnectionStatus: Codable {
    enum CodingKeys: String, CodingKey {
        case type, errorMessage
    }
    
    enum StatusType: String, Codable {
        case connected, connecting, disconnected, error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StatusType.self, forKey: .type)
        
        switch type {
        case .connected:
            self = .connected
        case .connecting:
            self = .connecting
        case .disconnected:
            self = .disconnected
        case .error:
            let errorMessage = try container.decode(String.self, forKey: .errorMessage)
            self = .error(errorMessage)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .connected:
            try container.encode(StatusType.connected, forKey: .type)
        case .connecting:
            try container.encode(StatusType.connecting, forKey: .type)
        case .disconnected:
            try container.encode(StatusType.disconnected, forKey: .type)
        case .error(let message):
            try container.encode(StatusType.error, forKey: .type)
            try container.encode(message, forKey: .errorMessage)
        }
    }
}