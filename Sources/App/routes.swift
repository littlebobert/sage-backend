import Vapor
import FluentMySQL

// Store a map from Firebase UID to the state token we use for Stripe authentication.
var stateTokens = [String: String]()

final class User: MySQLModel {
    var id: Int?
    
    init(id: Int? = nil) {
        self.id = id
    }
}

extension User: Content {
    
}

extension User: MySQLMigration {
    
}

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // "It works" page
    router.get { req in
        return try req.view().render("welcome")
    }
    
    router.get("oauth") { req -> Future<View> in
        if let _ = try? req.query.get(String.self, at: "error") {
            let errorDescription = try? req.query.get(String.self, at: "error_description")
            return try req.view().render("error", [
                "errorDescription": errorDescription ?? "An unknown error occured."
            ])
        }
        let scope = try req.query.get(String.self, at: "scope")
        let state = try req.query.get(String.self, at: "state")
        let code = try req.query.get(String.self, at: "code")
        print("scope: \(scope), state: \(state), code: \(code)")
        return try req.view().render("welcome")
    }
    
    router.get("finish-authentication") { req -> String in
        guard let uid = try? req.query.get(String.self, at: "uid") else {
            throw Abort(.notFound, reason: "You must provide a Firebase UID.")
        }
        let state = UUID().uuidString
        stateTokens[uid] = state
        return state
    }
}
