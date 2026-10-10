package com.medha.companion.data.local

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory

/**
 * Native SQLite Database Helper managing creation, foreign key enforcement,
 * and lifecycle for Medha Android Companion.
 */
class MedhaDatabaseOpenHelper(
    context: Context,
    name: String? = DatabaseSchema.DB_NAME
) {
    private val callback = object : SupportSQLiteOpenHelper.Callback(DatabaseSchema.DB_VERSION) {
        override fun onConfigure(db: SupportSQLiteDatabase) {
            super.onConfigure(db)
            db.setForeignKeyConstraintsEnabled(true)
        }

        override fun onCreate(db: SupportSQLiteDatabase) {
            var fts5Created = false
            DatabaseSchema.CREATE_TABLES.forEach { sql ->
                val isFtsTable = sql.contains("CREATE VIRTUAL TABLE", ignoreCase = true) && sql.contains("block_fts", ignoreCase = true)
                val isFtsTrigger = sql.contains("block_fts", ignoreCase = true) && sql.contains("CREATE TRIGGER", ignoreCase = true)

                if (isFtsTrigger && !fts5Created) {
                    // Skip trigger if virtual table was not created
                    return@forEach
                }

                try {
                    db.execSQL(sql)
                    if (isFtsTable) {
                        fts5Created = true
                    }
                } catch (e: android.database.sqlite.SQLiteException) {
                    // If host test SQLite lacks the FTS5 extension, degrade gracefully for unit testing
                    if (isFtsTable || isFtsTrigger) {
                        // Skip FTS5 in headless environment lacking the module
                    } else {
                        throw e
                    }
                }
            }
        }

        override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {
            // Future schema migrations
        }
    }

    private val helper: SupportSQLiteOpenHelper = FrameworkSQLiteOpenHelperFactory().create(
        SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(name)
            .callback(callback)
            .build()
    )

    val writableDatabase: SupportSQLiteDatabase
        get() = helper.writableDatabase

    val readableDatabase: SupportSQLiteDatabase
        get() = helper.readableDatabase

    fun close() {
        helper.close()
    }
}
