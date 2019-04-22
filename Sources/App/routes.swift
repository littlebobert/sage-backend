import Vapor
import FluentMySQL

// Store a map from a state token we returned for use with Stripe authentication to the Firebase UID.
var stateTokens = [String: String]()

final class User: MySQLStringModel {
    
    var id: String?
    
    var stripeAuthenticationCode: String?
    
    init(id: String? = nil, stripeAuthenticationCode: String? = nil) {
        self.id = id
        self.stripeAuthenticationCode = stripeAuthenticationCode
    }
}

struct StripeAuthenticationResponse: Codable {
    let status: String
    let state: String?
    
    init(status: String, state: String? = nil) {
        self.status = status
        self.state = state
    }
}

enum StripeAuthenticationResponseStatus: String {
    case notAuthenticated = "not_authenticated"
    case finished = "finished"
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
    
    router.get("stripe-authentication") { req -> String in
        guard let uid = try? req.query.get(String.self, at: "uid") else {
            throw Abort(.notFound, reason: "You must provide a Firebase UID.")
        }
        guard let _ = try? User.find(uid, on: req).wait() else {
            // We don’t have a User in the database for this uid yet.
            guard let _ = try? User().create(on: req).wait() else {
                throw Abort(.notFound, reason: "Couldn’t create User") // to do: use a more appropriate error here.
            }
            let state = UUID().uuidString
            stateTokens[state] = uid
            let stripeAuthenticationResponse = StripeAuthenticationResponse(
                status: StripeAuthenticationResponseStatus.notAuthenticated.rawValue,
                state: state)
            guard let responseData = try? JSONEncoder().encode(stripeAuthenticationResponse), let responseString = String(data: responseData, encoding: .utf8) else {
                throw Abort(.notFound, reason: "Failed to create JSON response.") // to do: use a more appropriate error here.
            }
            return responseString
        }
        
        // We found a User for this uid, just tell the client we are finished.
        let stripeAuthenticationResponse = StripeAuthenticationResponse(
            status: StripeAuthenticationResponseStatus.finished.rawValue
        )
        guard let responseData = try? JSONEncoder().encode(stripeAuthenticationResponse), let responseString = String(data: responseData, encoding: .utf8) else {
            throw Abort(.notFound, reason: "Failed to create JSON response.") // to do: use a more appropriate error here.
        }
        return responseString
    }
}
