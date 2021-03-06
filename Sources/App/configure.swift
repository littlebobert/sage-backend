import Leaf
import Vapor
import FluentMySQL

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    let databaseConfig: MySQLDatabaseConfig
    if let url = Environment.get("DATABASE_URL") {
        databaseConfig = try! MySQLDatabaseConfig(url: url)!
    } else if let url = Environment.get("DB_MYSQL") {
        databaseConfig = try! MySQLDatabaseConfig(url: url)!
    } else {
        let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
        let username = Environment.get("DATABASE_USER") ?? "root"
        let password = Environment.get("DATABASE_PASSWORD") ?? ""
        let databaseName: String
        let databasePort: Int
        if (env == .testing) {
            databaseName = "vapor-test"
            if let testPort = Environment.get("DATABASE_PORT") {
                databasePort = Int(testPort) ?? 3306
            } else {
                databasePort = 3306
            }
        } else {
            databaseName = Environment.get("DATABASE_DB") ?? "clients01"
            databasePort = 3306
        }
        databaseConfig = MySQLDatabaseConfig(
            hostname: hostname,
            port: databasePort,
            username: username,
            password: password,
            database: databaseName,
            transport: .unverifiedTLS
        )
    }
    var databasesConfig = DatabasesConfig()
    databasesConfig.add(database: MySQLDatabase(config: databaseConfig), as: .mysql)
    databasesConfig.enableLogging(on: .mysql)
    services.register(databasesConfig)
    
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .mysql)
    services.register(migrations)
    
    // Use Leaf for rendering views
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
}
