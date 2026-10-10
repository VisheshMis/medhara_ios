import Foundation
import GRDB

public final class NotionDatabaseService: @unchecked Sendable {
    private let dbManager: DatabaseManager

    public init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    // MARK: - Database CRUD
    @discardableResult
    public func createDatabase(
        rootDocId: String,
        title: String = "Untitled Database",
        description: String? = nil,
        icon: String? = "tablecells"
    ) -> NotionDatabase {
        let db = NotionDatabase(
            rootDocId: rootDocId,
            title: title,
            description: description,
            icon: icon
        )

        do {
            try dbManager.dbWriter.write { dbWriter in
                try db.insert(dbWriter)

                // Create default Title property
                let titleProp = DatabaseProperty(
                    databaseId: db.id,
                    name: "Name",
                    type: .title,
                    sortOrder: 0
                )
                try titleProp.insert(dbWriter)
            }
        } catch {
            print("Error creating database: \(error)")
        }

        return db
    }

    public func fetchDatabase(id: String) -> NotionDatabase? {
        do {
            return try dbManager.dbWriter.read { db in
                try NotionDatabase.fetchOne(db, key: id)
            }
        } catch {
            print("Error fetching database: \(error)")
            return nil
        }
    }

    public func fetchDatabases(for rootDocId: String) -> [NotionDatabase] {
        do {
            return try dbManager.dbWriter.read { db in
                try NotionDatabase.filter(NotionDatabase.Columns.rootDocId == rootDocId)
                    .order(NotionDatabase.Columns.createdAt.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching databases for rootDocId: \(error)")
            return []
        }
    }

    public func updateDatabase(_ database: NotionDatabase) {
        var updated = database
        updated.updatedAt = Date()
        do {
            try dbManager.dbWriter.write { db in
                try updated.update(db)
            }
        } catch {
            print("Error updating database: \(error)")
        }
    }

    public func deleteDatabase(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try NotionDatabase.filter(NotionDatabase.Columns.id == id).deleteAll(db)
            }
        } catch {
            print("Error deleting database: \(error)")
        }
    }

    // MARK: - Properties CRUD
    @discardableResult
    public func createProperty(
        databaseId: String,
        name: String,
        type: DatabasePropertyType,
        config: DatabasePropertyConfig? = nil
    ) -> DatabaseProperty {
        let existingProps = fetchProperties(databaseId: databaseId)
        let nextOrder = (existingProps.map(\.sortOrder).max() ?? -1) + 1

        let prop = DatabaseProperty(
            databaseId: databaseId,
            name: name,
            type: type,
            configJson: config?.serialize(),
            sortOrder: nextOrder
        )

        do {
            try dbManager.dbWriter.write { db in
                try prop.insert(db)
            }
        } catch {
            print("Error creating database property: \(error)")
        }

        return prop
    }

    public func fetchProperties(databaseId: String) -> [DatabaseProperty] {
        do {
            return try dbManager.dbWriter.read { db in
                try DatabaseProperty.filter(DatabaseProperty.Columns.databaseId == databaseId)
                    .order(DatabaseProperty.Columns.sortOrder.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching properties: \(error)")
            return []
        }
    }

    public func updateProperty(_ property: DatabaseProperty) {
        do {
            try dbManager.dbWriter.write { db in
                try property.update(db)
            }
        } catch {
            print("Error updating property: \(error)")
        }
    }

    public func deleteProperty(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try DatabaseCellValue.filter(DatabaseCellValue.Columns.propertyId == id).deleteAll(db)
                _ = try DatabaseProperty.filter(DatabaseProperty.Columns.id == id).deleteAll(db)
            }
        } catch {
            print("Error deleting property: \(error)")
        }
    }

    // MARK: - Records CRUD
    @discardableResult
    public func createRecord(databaseId: String, docId: String) -> DatabaseRecord {
        let now = Date()
        var nextSeq: Int? = nil

        // If uniqueId property exists, increment sequence
        let props = fetchProperties(databaseId: databaseId)
        if props.contains(where: { $0.type == .uniqueId }) {
            do {
                try dbManager.dbWriter.read { db in
                    let maxSeq = try Int.fetchOne(
                        db,
                        sql: "SELECT MAX(uniqueSeqNumber) FROM database_records WHERE databaseId = ?",
                        arguments: [databaseId]
                    ) ?? 0
                    nextSeq = maxSeq + 1
                }
            } catch {
                print("Error calculating unique sequence: \(error)")
                nextSeq = 1
            }
        }

        let record = DatabaseRecord(
            databaseId: databaseId,
            docId: docId,
            uniqueSeqNumber: nextSeq,
            createdAt: now,
            updatedAt: now
        )

        do {
            try dbManager.dbWriter.write { db in
                try record.insert(db)

                // Fill automatic timestamp cells
                for prop in props {
                    if prop.type == .createdTime {
                        let cell = DatabaseCellValue(
                            recordId: record.id,
                            propertyId: prop.id,
                            valueDate: now
                        )
                        try cell.insert(db)
                    } else if prop.type == .lastEditedTime {
                        let cell = DatabaseCellValue(
                            recordId: record.id,
                            propertyId: prop.id,
                            valueDate: now
                        )
                        try cell.insert(db)
                    } else if prop.type == .uniqueId, let seq = nextSeq {
                        let prefix = prop.parsedConfig?.uniqueIdConfig?.prefix ?? "ID-"
                        let cell = DatabaseCellValue(
                            recordId: record.id,
                            propertyId: prop.id,
                            valueText: "\(prefix)\(seq)"
                        )
                        try cell.insert(db)
                    }
                }
            }
        } catch {
            print("Error creating database record: \(error)")
        }

        return record
    }

    public func fetchRecords(databaseId: String) -> [DatabaseRecord] {
        do {
            return try dbManager.dbWriter.read { db in
                try DatabaseRecord.filter(DatabaseRecord.Columns.databaseId == databaseId)
                    .order(DatabaseRecord.Columns.createdAt.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching records: \(error)")
            return []
        }
    }

    public func deleteRecord(id: String) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try DatabaseCellValue.filter(DatabaseCellValue.Columns.recordId == id).deleteAll(db)
                _ = try RecordRelation.filter(RecordRelation.Columns.fromRecordId == id || RecordRelation.Columns.toRecordId == id).deleteAll(db)
                _ = try DatabaseRecord.filter(DatabaseRecord.Columns.id == id).deleteAll(db)
            }
        } catch {
            print("Error deleting record: \(error)")
        }
    }

    // MARK: - Cell Values & Typed Property Operations
    public func getCellValue(recordId: String, propertyId: String) -> DatabaseCellValue? {
        do {
            return try dbManager.dbWriter.read { db in
                try DatabaseCellValue.filter(
                    DatabaseCellValue.Columns.recordId == recordId &&
                    DatabaseCellValue.Columns.propertyId == propertyId
                ).fetchOne(db)
            }
        } catch {
            print("Error reading cell value: \(error)")
            return nil
        }
    }

    public func fetchCellValues(for recordId: String) -> [DatabaseCellValue] {
        do {
            return try dbManager.dbWriter.read { db in
                try DatabaseCellValue.filter(DatabaseCellValue.Columns.recordId == recordId).fetchAll(db)
            }
        } catch {
            print("Error fetching cell values for record: \(error)")
            return []
        }
    }

    public func setCellValue(
        recordId: String,
        propertyId: String,
        valueText: String? = nil,
        valueNumber: Double? = nil,
        valueDate: Date? = nil,
        valueJson: String? = nil
    ) {
        let cell = DatabaseCellValue(
            recordId: recordId,
            propertyId: propertyId,
            valueText: valueText,
            valueNumber: valueNumber,
            valueDate: valueDate,
            valueJson: valueJson
        )

        do {
            try dbManager.dbWriter.write { db in
                try cell.save(db)

                // Update record updatedAt and any lastEditedTime properties
                try db.execute(
                    sql: "UPDATE database_records SET updatedAt = datetime('now') WHERE id = ?",
                    arguments: [recordId]
                )

                let lastEditedProps = try DatabaseProperty.fetchAll(
                    db,
                    sql: """
                    SELECT p.* FROM database_properties p
                    JOIN database_records r ON r.databaseId = p.databaseId
                    WHERE r.id = ? AND p.type = 'lastEditedTime'
                    """,
                    arguments: [recordId]
                )

                for prop in lastEditedProps {
                    let updateCell = DatabaseCellValue(
                        recordId: recordId,
                        propertyId: prop.id,
                        valueDate: Date()
                    )
                    try updateCell.save(db)
                }
            }
        } catch {
            print("Error setting cell value: \(error)")
        }
    }

    // MARK: - Bidirectional Relations
    public func addRelation(
        fromRecordId: String,
        toRecordId: String,
        relationPropertyId: String
    ) {
        let rel = RecordRelation(
            fromRecordId: fromRecordId,
            toRecordId: toRecordId,
            relationPropertyId: relationPropertyId
        )

        do {
            try dbManager.dbWriter.write { db in
                try rel.insert(db)

                // Check if two-way relation is configured
                if let prop = try DatabaseProperty.fetchOne(db, key: relationPropertyId),
                   let config = prop.parsedConfig?.relationConfig,
                   config.isTwoWay,
                   let twoWayPropId = config.twoWayPropertyId {
                    // Create reciprocal relation
                    let reciprocalRel = RecordRelation(
                        fromRecordId: toRecordId,
                        toRecordId: fromRecordId,
                        relationPropertyId: twoWayPropId
                    )
                    try reciprocalRel.insert(db)
                }
            }
        } catch {
            print("Error adding record relation: \(error)")
        }
    }

    public func removeRelation(
        fromRecordId: String,
        toRecordId: String,
        relationPropertyId: String
    ) {
        do {
            try dbManager.dbWriter.write { db in
                _ = try RecordRelation.filter(
                    RecordRelation.Columns.fromRecordId == fromRecordId &&
                    RecordRelation.Columns.toRecordId == toRecordId &&
                    RecordRelation.Columns.relationPropertyId == relationPropertyId
                ).deleteAll(db)

                // Remove reciprocal if two-way
                if let prop = try DatabaseProperty.fetchOne(db, key: relationPropertyId),
                   let config = prop.parsedConfig?.relationConfig,
                   config.isTwoWay,
                   let twoWayPropId = config.twoWayPropertyId {
                    _ = try RecordRelation.filter(
                        RecordRelation.Columns.fromRecordId == toRecordId &&
                        RecordRelation.Columns.toRecordId == fromRecordId &&
                        RecordRelation.Columns.relationPropertyId == twoWayPropId
                    ).deleteAll(db)
                }
            }
        } catch {
            print("Error removing record relation: \(error)")
        }
    }

    public func fetchRelatedRecordIds(
        recordId: String,
        relationPropertyId: String
    ) -> [String] {
        do {
            return try dbManager.dbWriter.read { db in
                let rels = try RecordRelation.filter(
                    RecordRelation.Columns.fromRecordId == recordId &&
                    RecordRelation.Columns.relationPropertyId == relationPropertyId
                ).fetchAll(db)
                return rels.map(\.toRecordId)
            }
        } catch {
            print("Error fetching related record ids: \(error)")
            return []
        }
    }

    // MARK: - Rollup Engine (Instant SQLite Aggregate Calculation)
    public func computeRollup(
        currentRecordId: String,
        rollupPropertyId: String
    ) -> Double? {
        do {
            return try dbManager.dbWriter.read { db in
                guard let rollupProp = try DatabaseProperty.fetchOne(db, key: rollupPropertyId),
                      let config = rollupProp.parsedConfig?.rollupConfig else {
                    return nil
                }

                let aggSql: String
                switch config.aggregation {
                case .sum:
                    aggSql = "SUM(c.valueNumber)"
                case .avg:
                    aggSql = "AVG(c.valueNumber)"
                case .min:
                    aggSql = "MIN(c.valueNumber)"
                case .max:
                    aggSql = "MAX(c.valueNumber)"
                case .count, .countValues:
                    aggSql = "CAST(COUNT(c.valueNumber) AS REAL)"
                }

                let sql = """
                SELECT \(aggSql) AS rollupResult
                FROM record_relations r
                JOIN database_cell_values c ON c.recordId = r.toRecordId AND c.propertyId = ?
                WHERE r.fromRecordId = ? AND r.relationPropertyId = ?;
                """

                let row = try Row.fetchOne(
                    db,
                    sql: sql,
                    arguments: [config.targetPropertyId, currentRecordId, config.relationPropertyId]
                )
                return row?["rollupResult"]
            }
        } catch {
            print("Error computing rollup: \(error)")
            return nil
        }
    }

    // MARK: - Visual Analytics Aggregate Engine
    public func computeAnalyticsData(
        databaseId: String,
        groupByPropertyId: String,
        metricPropertyId: String? = nil,
        aggregation: RollupAggregation = .count
    ) -> [ChartDataPoint] {
        do {
            return try dbManager.dbWriter.read { db in
                guard let groupProp = try DatabaseProperty.fetchOne(db, key: groupByPropertyId) else {
                    return []
                }

                if let metricId = metricPropertyId, let metricProp = try DatabaseProperty.fetchOne(db, key: metricId), metricProp.type == .number {
                    let aggFunc: String
                    switch aggregation {
                    case .sum: aggFunc = "SUM(metric.valueNumber)"
                    case .avg: aggFunc = "AVG(metric.valueNumber)"
                    case .min: aggFunc = "MIN(metric.valueNumber)"
                    case .max: aggFunc = "MAX(metric.valueNumber)"
                    case .count, .countValues: aggFunc = "COUNT(metric.valueNumber)"
                    }

                    let sql = """
                    SELECT 
                        COALESCE(grp.valueText, 'Unassigned') AS category,
                        \(aggFunc) AS aggVal
                    FROM database_records r
                    LEFT JOIN database_cell_values grp ON grp.recordId = r.id AND grp.propertyId = ?
                    LEFT JOIN database_cell_values metric ON metric.recordId = r.id AND metric.propertyId = ?
                    WHERE r.databaseId = ?
                    GROUP BY grp.valueText
                    ORDER BY aggVal DESC;
                    """
                    let rows = try Row.fetchAll(db, sql: sql, arguments: [groupByPropertyId, metricId, databaseId])
                    return rows.map { row in
                        let cat: String = row["category"]
                        let val: Double = row["aggVal"] ?? 0.0
                        return ChartDataPoint(category: cat.isEmpty ? "Unassigned" : cat, value: val)
                    }
                } else {
                    // Group by count of records
                    let sql = """
                    SELECT 
                        COALESCE(grp.valueText, 'Unassigned') AS category,
                        COUNT(r.id) AS aggVal
                    FROM database_records r
                    LEFT JOIN database_cell_values grp ON grp.recordId = r.id AND grp.propertyId = ?
                    WHERE r.databaseId = ?
                    GROUP BY grp.valueText
                    ORDER BY aggVal DESC;
                    """
                    let rows = try Row.fetchAll(db, sql: sql, arguments: [groupByPropertyId, databaseId])
                    return rows.map { row in
                        let cat: String = row["category"]
                        let rawVal: Any? = row["aggVal"]
                        let val: Double
                        if let d = rawVal as? Double {
                            val = d
                        } else if let i = rawVal as? Int {
                            val = Double(i)
                        } else if let i64 = rawVal as? Int64 {
                            val = Double(i64)
                        } else if let num = rawVal as? NSNumber {
                            val = num.doubleValue
                        } else {
                            val = 0.0
                        }
                        return ChartDataPoint(category: cat.isEmpty ? "Unassigned" : cat, value: val)
                    }
                }
            }
        } catch {
            print("Error computing analytics data: \(error)")
            return []
        }
    }

    // MARK: - Workflow Automations Engine
    public func executeAutomationRules(
        databaseId: String,
        recordId: String,
        trigger: AutomationTriggerType,
        rules: [DatabaseAutomationRule]
    ) {
        let matchingRules = rules.filter { $0.databaseId == databaseId && $0.triggerType == trigger }
        for rule in matchingRules {
            switch rule.actionType {
            case .updateProperty:
                if let targetPropId = rule.targetPropertyId {
                    setCellValue(
                        recordId: recordId,
                        propertyId: targetPropId,
                        valueText: rule.targetValueText,
                        valueNumber: rule.targetValueNumber
                    )
                }
            case .markComplete:
                if let targetPropId = rule.targetPropertyId {
                    setCellValue(
                        recordId: recordId,
                        propertyId: targetPropId,
                        valueText: "Completed",
                        valueNumber: 1.0
                    )
                }
            case .setDateFieldToNow:
                if let targetPropId = rule.targetPropertyId {
                    setCellValue(
                        recordId: recordId,
                        propertyId: targetPropId,
                        valueDate: Date()
                    )
                }
            }
        }
    }
}
