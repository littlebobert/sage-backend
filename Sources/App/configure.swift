import Leaf
import Vapor
import FluentMySQL

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())
    
    let mysqlConfig = MySQLDatabaseConfig(
        hostname: Environment.get("$DATABASE_HOSTNAME")!,
        port: Int(Environment.get("$DATABASE_PORT")!)!,
        username: Environment.get("$DATABASE_USER")!,
        password: Environment.get("$DATABASE_PASSWORD")!,
        database: Environment.get("$DATABASE_DB")!,
        transport: MySQLTransportConfig.unverifiedTLS
    )
    services.register(mysqlConfig)
    
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .mysql)
    services.register(migrations)

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    // Use Leaf for rendering views
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
}
