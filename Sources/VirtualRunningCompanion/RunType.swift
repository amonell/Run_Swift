import Foundation

public enum RunType: Codable, Equatable {
    case solo
    case synchronized(sessionId: String)
    case replay(originalRunId: UUID)
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case type, sessionId, originalRunId
    }
    
    enum TypeValue: String, Codable {
        case solo, synchronized, replay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeValue.self, forKey: .type)
        
        switch type {
        case .solo:
            self = .solo
        case .synchronized:
            let sessionId = try container.decode(String.self, forKey: .sessionId)
            self = .synchronized(sessionId: sessionId)
        case .replay:
            let originalRunId = try container.decode(UUID.self, forKey: .originalRunId)
            self = .replay(originalRunId: originalRunId)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .solo:
            try container.encode(TypeValue.solo, forKey: .type)
        case .synchronized(let sessionId):
            try container.encode(TypeValue.synchronized, forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
        case .replay(let originalRunId):
            try container.encode(TypeValue.replay, forKey: .type)
            try container.encode(originalRunId, forKey: .originalRunId)
        }
    }
    
    // MARK: - Validation
    
    func validate() throws {
        switch self {
        case .solo:
            break // No validation needed for solo runs
        case .synchronized(let sessionId):
            try validateSessionId(sessionId)
        case .replay(let originalRunId):
            try validateOriginalRunId(originalRunId)
        }
    }
    
    private func validateSessionId(_ sessionId: String) throws {
        guard !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptySessionId
        }
        
        guard sessionId.count <= 100 else {
            throw ValidationError.sessionIdTooLong
        }
    }
    
    private func validateOriginalRunId(_ runId: UUID) throws {
        // UUID validation is handled by the UUID type itself
        // Additional business logic validation could be added here if needed
    }
}