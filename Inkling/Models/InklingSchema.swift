import SwiftData

// MARK: - Schema V1 (Current)
enum InklingSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        JournalEntry.self,
        JournalPhoto.self,
        UserProfile.self,
    ]
}

// MARK: - Migration Plan
enum InklingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        InklingSchemaV1.self,
    ]

    static var stages: [MigrationStage] = [
        // Future versions go here, e.g.:
        //
        // MigrationStage.lightweight(
        //     fromVersion: InklingSchemaV1.self,
        //     toVersion: InklingSchemaV2.self
        // ),
        //
        // For complex migrations (e.g. data transformation):
        // MigrationStage.custom(
        //     fromVersion: InklingSchemaV1.self,
        //     toVersion: InklingSchemaV2.self,
        //     willMigrate: { context in ... },
        //     didMigrate: { context in ... }
        // ),
    ]
}
