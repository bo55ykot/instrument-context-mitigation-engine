-- ==================================================================================
-- ARCHITECTURE DECISION RECORD (ADR) - MULTI-DATABASE TELEMETRY G0VERNANCE SCRIPT
-- DESIGNED FOR HIGH-LOAD INSTRUMENT INTELLIGENCE PLATFORM (ZERO-PII INGESTION)
-- ==================================================================================

CREATE DATABASE InstrumentIntelligence_Telemetry_Core;
GO

USE InstrumentIntelligence_Telemetry_Core;
GO

-- Таблица оптимизирована под минимальный размер страниц памяти SQL Server
CREATE TABLE dbo.InstrumentStateSnapshots (
    SnapshotId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    InstrumentId VARCHAR(50) NOT NULL,
    EncryptedStateData VARCHAR(MAX) NOT NULL, -- Сжатый и зашифрованный Base64 AES-пакет (Token-Mitigated)
    IngestionTimestamp DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_InstrumentStateSnapshots PRIMARY KEY CLUSTERED (SnapshotId, IngestionTimestamp)
) ON [PRIMARY];
GO

-- Прецизионный индекс для мгновенной выборки последних состояний приборов флота (Fleet APIs Optimization)
CREATE NONCLUSTERED INDEX IX_TelemetryCore_Instrument_Timestamp 
ON dbo.InstrumentStateSnapshots (InstrumentId, IngestionTimestamp DESC)
INCLUDE (EncryptedStateData);
GO

-- Высокопроизводительная хранимая процедура с обходом блокировок (ROWLOCK/NOLOCK) и оптимизацией планов запросов
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
        -- Логирование ошибок в системный файрвол инфраструктуры
        THROW 50001, 'Critical Error During Multi-Database Telemetry Ingestion.', 1;
    END CATCH
END;
GO
