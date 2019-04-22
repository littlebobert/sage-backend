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

private func getFuture(from string: String, req: Request) -> Future<String> {
    let promise = req.eventLoop.newPromise(of: String.self)
    promise.succeed(result: string)
    return promise.futureResult
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
    
    router.get("stripe-authentication") { req -> Future<String> in
        guard let uid = try? req.query.get(String.self, at: "uid") else {
            throw Abort(.notFound, reason: "You must provide a Firebase UID.")
        }
        let future = User.find(uid, on: req).then({ (user) -> EventLoopFuture<String> in
            guard let user = user else {
                // We don’t have a User in the database for this uid yet.
                let newUserFuture = User().create(on: req).then({ (user) -> EventLoopFuture<String> in
                    let state = UUID().uuidString
                    stateTokens[state] = uid
                    let stripeAuthenticationResponse = StripeAuthenticationResponse(
                        status: StripeAuthenticationResponseStatus.notAuthenticated.rawValue,
                        state: state)
                    let responseData = try! JSONEncoder().encode(stripeAuthenticationResponse)
                    let responseString = String(data: responseData, encoding: .utf8)!
                    return getFuture(from: responseString, req: req)
                })
                return newUserFuture
            }
            // We have a User for this uid.
            guard let _ = user.stripeAuthenticationCode else {
                // This User hasn’t authenticated with Stripe yet.
                let state = UUID().uuidString
                stateTokens[state] = uid
                let stripeAuthenticationResponse = StripeAuthenticationResponse(
                    status: StripeAuthenticationResponseStatus.notAuthenticated.rawValue,
                    state: state)
                let responseData = try! JSONEncoder().encode(stripeAuthenticationResponse)
                let responseString = String(data: responseData, encoding: .utf8)!
                return getFuture(from: responseString, req: req)
            }
            
            let stripeAuthenticationResponse = StripeAuthenticationResponse(
                status: StripeAuthenticationResponseStatus.finished.rawValue
            )
            let responseData = try! JSONEncoder().encode(stripeAuthenticationResponse)
            let responseString = String(data: responseData, encoding: .utf8)!
            return getFuture(from: responseString, req: req)
        })
        return future
    }
}
