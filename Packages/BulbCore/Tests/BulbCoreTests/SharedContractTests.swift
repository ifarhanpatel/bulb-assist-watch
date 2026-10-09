import Foundation
import Testing
@testable import BulbCore

struct SharedContractTests {
    @Test func lifecycleWireFormatPreservesDistinctResults() throws {
        let results: [ProvisioningResult] = [.persisted, .removed, .connected(.preview), .failed(.persistence)]
        for result in results {
            let reply = ProvisioningAcknowledgement(revision: 42, result: result)
            let decoded = try JSONDecoder().decode(ProvisioningAcknowledgement.self, from: JSONEncoder().encode(reply))
            #expect(decoded == reply)
        }
        #expect(ProvisioningMessage.remove(revision: 43).revision == 43)
    }
    @Test func policyBoundsAndUncertainty() {
        #expect(RequestPolicy.live.minimumSpacing == .seconds(1))
        #expect(RequestPolicy(maximumConfirmationReads: 99).maximumConfirmationReads == 2)
        #expect(BulbFailure.uncertainWrite.requiresReconciliation)
        #expect(!BulbFailure.rejected.requiresReconciliation)
    }
}
