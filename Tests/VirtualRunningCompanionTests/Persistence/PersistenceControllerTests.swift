import XCTest
import CoreData
@testable import VirtualRunningCompanion

final class PersistenceControllerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(persistenceController.container)
        XCTAssertNotNil(persistenceController.viewContext)
    }
    
    func testViewContextConfiguration() {
        let context = persistenceController.viewContext
        XCTAssertTrue(context.automaticallyMergesChangesFromParent)
        XCTAssertEqual(context.mergePolicy as? NSMergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    func testBackgroundContextCreation() {
        let backgroundContext = persistenceController.newBackgroundContext()
        XCTAssertNotNil(backgroundContext)
        XCTAssertNotEqual(backgroundContext, persistenceController.viewContext)
    }
    
    func testSaveOperation() {
        let context = persistenceController.viewContext
        
        let userEntity = UserEntity(context: context)
        userEntity.id = UUID()
        userEntity.username = "testuser"
        userEntity.email = "test@example.com"
        userEntity.createdAt = Date()
        
        XCTAssertTrue(context.hasChanges)
        
        persistenceController.save()
        
        XCTAssertFalse(context.hasChanges)
    }
    
    func testPerformBackgroundTask() {
        let expectation = XCTestExpectation(description: "Background task completion")
        
        persistenceController.performBackgroundTask { context in
            let userEntity = UserEntity(context: context)
            userEntity.id = UUID()
            userEntity.username = "backgrounduser"
            userEntity.email = "background@example.com"
            userEntity.createdAt = Date()
            
            do {
                try context.save()
                expectation.fulfill()
            } catch {
                XCTFail("Background save failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPreviewController() {
        let previewController = PersistenceController.preview
        XCTAssertNotNil(previewController)
        
        let context = previewController.viewContext
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let users = try context.fetch(fetchRequest)
            XCTAssertGreaterThan(users.count, 0, "Preview should contain sample data")
        } catch {
            XCTFail("Failed to fetch preview data: \(error)")
        }
    }
}