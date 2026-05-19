package com.example.crm_caller_nxtgen.core.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        ContactEntity::class,
        LeadEntity::class,
        OpportunityEntity::class,
        ComplaintEntity::class,
        NoteEntity::class,
        CallLogEntity::class,
    ],
    version = 5,             // bumped from 4 → 5 for call_logs table
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun contactDao(): ContactDao
    abstract fun leadDao(): LeadDao
    abstract fun opportunityDao(): OpportunityDao
    abstract fun complaintDao(): ComplaintDao
    abstract fun noteDao(): NoteDao
    abstract fun callLogDao(): CallLogDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        // Migration 2 → 3: add new columns to leads, opportunities, complaints
        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // leads
                db.execSQL("ALTER TABLE leads ADD COLUMN frappeDocname TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE leads ADD COLUMN email TEXT")
                db.execSQL("ALTER TABLE leads ADD COLUMN company TEXT")

                // opportunities
                db.execSQL("ALTER TABLE opportunities ADD COLUMN frappeDocname TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE opportunities ADD COLUMN leadDocname TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE opportunities ADD COLUMN note TEXT NOT NULL DEFAULT ''")

                // complaints
                db.execSQL("ALTER TABLE complaints ADD COLUMN frappeDocname TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE complaints ADD COLUMN leadDocname TEXT NOT NULL DEFAULT ''")
            }
        }

        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE leads ADD COLUMN cachedAt INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE leads ADD COLUMN latestNote TEXT NOT NULL DEFAULT ''")
            }
        }

        private val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `call_logs` (
                        `id` TEXT NOT NULL PRIMARY KEY,
                        `frappeDocname` TEXT NOT NULL DEFAULT '',
                        `phoneNumber` TEXT NOT NULL,
                        `callerName` TEXT NOT NULL,
                        `leadDocname` TEXT NOT NULL DEFAULT '',
                        `durationSeconds` INTEGER NOT NULL,
                        `notes` TEXT NOT NULL,
                        `callType` TEXT NOT NULL,
                        `direction` TEXT NOT NULL DEFAULT 'Inbound',
                        `createdAt` INTEGER NOT NULL,
                        `isSynced` INTEGER NOT NULL
                    )
                """.trimIndent())
            }
        }

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "crm_caller_database",
                )
                    .addMigrations(MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5)
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
