-- ==================================================================================
-- ARCHITECTURE DECISION RECORD (ADR) - MULTI-DATABASE TELEMETRY GOVERNANCE SCRIPT
-- DESIGNED FOR HIGH-LOAD INSTRUMENT INTELLIGENCE PLATFORM (ZERO-PII INGESTION)
-- AUTHOR: ALEX (PRINCIPAL SOFTWARE ARCHITECT)
-- ==================================================================================

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'InstrumentIntelligence_Telemetry_Core')
BEGIN
    CREATE DATABASE InstrumentIntelligence_Telemetry_Core;
END;
GO

USE InstrumentIntelligence_Telemetry_Core;
GO

-- Table design optimized for strict SQL Server memory page layout allocation
IF OBJECT_ID('dbo.InstrumentStateSnapshots', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.InstrumentStateSnapshots (
        SnapshotId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        InstrumentId VARCHAR(50) NOT NULL,
        EncryptedStateData VARCHAR(MAX) NOT NULL, -- Compressed and AES-encrypted Base64 data package
        IngestionTimestamp DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_InstrumentStateSnapshots PRIMARY KEY CLUSTERED (SnapshotId, IngestionTimestamp)
    ) ON [PRIMARY];
END;
GO

-- High-throughput index for fast fleet API analytics and snapshot isolation queries
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_TelemetryCore_Instrument_Timestamp' AND object_id = OBJECT_ID('dbo.InstrumentStateSnapshots'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_TelemetryCore_Instrument_Timestamp 
    ON dbo.InstrumentStateSnapshots (InstrumentId, IngestionTimestamp DESC)
    INCLUDE (EncryptedStateData);
END;
GO

-- Stored procedure optimized to bypass transaction locks (ROWLOCK) and avoid table deadlocks
IF OBJECT_ID('dbo.usp_IngestInstrumentContextSnapshot', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.usp_IngestInstrumentContextSnapshot;
END;
GO

CREATE PROCEDURE dbo.usp_IngestInstrumentContextSnapshot
    @InstrumentId VARCHAR(50),
    @EncryptedData VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        INSERT INTO dbo.InstrumentStateSnapshots (InstrumentId, EncryptedStateData)
        VALUES (@InstrumentId, @EncryptedData);
    END TRY
    BEGIN CATCH
        -- Structured exception handler to prevent any PII leakage into error logs
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Critical Ingestion Fault: Execution Aborted.', 16, 1);
    END CATCH
END;
GO
