-- ===================================================
-- TaxiApp - Tablo Olusturma + Veri Aktarimi
-- Supabase SQL Editor'da calistirin
-- ===================================================

-- TABLOLAR
CREATE TABLE IF NOT EXISTS "Drivers" (
    "Id" TEXT NOT NULL,
    "Email" TEXT NOT NULL,
    "PasswordHash" TEXT NOT NULL,
    "TaxiStandId" TEXT NOT NULL,
    "TaxiStandName" TEXT NOT NULL,
    "DriverName" TEXT NOT NULL,
    "VehiclePlate" TEXT NOT NULL,
    "ConnectionId" TEXT,
    "IsOnline" BOOLEAN NOT NULL DEFAULT FALSE,
    "IsVerified" BOOLEAN NOT NULL DEFAULT FALSE,
    "VerificationCode" TEXT,
    CONSTRAINT "PK_Drivers" PRIMARY KEY ("Id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Drivers_Email" ON "Drivers" ("Email");

CREATE TABLE IF NOT EXISTS "TaxiRequests" (
    "RequestId" TEXT NOT NULL,
    "UserId" TEXT NOT NULL,
    "TaxiStandId" TEXT NOT NULL,
    "FromLat" DOUBLE PRECISION NOT NULL,
    "FromLng" DOUBLE PRECISION NOT NULL,
    "ToLat" DOUBLE PRECISION NOT NULL,
    "ToLng" DOUBLE PRECISION NOT NULL,
    "EstimatedFare" DOUBLE PRECISION NOT NULL,
    "RequestTime" TIMESTAMP WITH TIME ZONE NOT NULL,
    "Status" TEXT NOT NULL,
    "DriverId" TEXT,
    "DriverName" TEXT,
    "DriverPlate" TEXT,
    CONSTRAINT "PK_TaxiRequests" PRIMARY KEY ("RequestId")
);

CREATE TABLE IF NOT EXISTS "Users" (
    "Id" TEXT NOT NULL,
    "Email" VARCHAR(200) NOT NULL,
    "PasswordHash" TEXT NOT NULL,
    "FullName" VARCHAR(100) NOT NULL,
    "PhoneNumber" TEXT,
    "VerificationCode" TEXT,
    "IsVerified" BOOLEAN NOT NULL DEFAULT FALSE,
    "CreatedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT "PK_Users" PRIMARY KEY ("Id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Users_Email" ON "Users" ("Email");

CREATE TABLE IF NOT EXISTS "UserCards" (
    "Id" TEXT NOT NULL,
    "UserId" TEXT NOT NULL,
    "CardCode" VARCHAR(50) NOT NULL,
    "CardNickname" TEXT NOT NULL,
    "Balance" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "AddedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "LastUsedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT "PK_UserCards" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_UserCards_Users_UserId" FOREIGN KEY ("UserId")
        REFERENCES "Users" ("Id") ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_UserCards_CardCode" ON "UserCards" ("CardCode");
CREATE INDEX IF NOT EXISTS "IX_UserCards_UserId" ON "UserCards" ("UserId");

CREATE TABLE IF NOT EXISTS "PaymentTransactions" (
    "Id" TEXT NOT NULL,
    "CardId" TEXT NOT NULL,
    "UserId" TEXT NOT NULL,
    "Amount" DECIMAL(10,2) NOT NULL,
    "Description" TEXT NOT NULL,
    "OldBalance" DECIMAL(10,2) NOT NULL,
    "NewBalance" DECIMAL(10,2) NOT NULL,
    "DeviceId" TEXT,
    "CreatedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT "PK_PaymentTransactions" PRIMARY KEY ("Id"),
    CONSTRAINT "FK_PaymentTransactions_UserCards_CardId" FOREIGN KEY ("CardId")
        REFERENCES "UserCards" ("Id") ON DELETE RESTRICT,
    CONSTRAINT "FK_PaymentTransactions_Users_UserId" FOREIGN KEY ("UserId")
        REFERENCES "Users" ("Id") ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS "IX_PaymentTransactions_CardId" ON "PaymentTransactions" ("CardId");
CREATE INDEX IF NOT EXISTS "IX_PaymentTransactions_UserId" ON "PaymentTransactions" ("UserId");

CREATE TABLE IF NOT EXISTS "LoginLogs" (
    "Id" SERIAL NOT NULL,
    "DriverId" TEXT,
    "IpAddress" TEXT NOT NULL DEFAULT 'unknown',
    "LoginAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "UserId" TEXT,
    "Success" BOOLEAN NOT NULL DEFAULT FALSE,
    "FailReason" TEXT,
    CONSTRAINT "PK_LoginLogs" PRIMARY KEY ("Id")
);

-- ===================================================
-- MEVCUT VERILER (SQLite'dan aktarildi)
-- ===================================================

INSERT INTO "Users" ("Id", "Email", "PasswordHash", "FullName", "PhoneNumber", "VerificationCode", "IsVerified", "CreatedAt") VALUES
('bccdbc10-eda2-4ba8-bcc1-e76c21e54548', 'zamazingo971@gmail.com', '.QwqG97643rU1.x7pszP/hlRCC34S79ZQ.ZqSAmwZYyqq', 'zama', '1254521245', NULL, TRUE, '2026-04-17 23:16:26.193368+00'),
('18ee22b5-65ac-47f8-ad3f-43a9b6e0f674', 'zamazingo865@gmail.com', '.Q.Vn5x4MaDrxXkf60qsKsWaSyWhQOxq', 'ali', '+905533712504', NULL, TRUE, '2026-04-17 23:33:15.705894+00');

INSERT INTO "LoginLogs" ("Id", "DriverId", "IpAddress", "LoginAt", "UserId", "Success", "FailReason") VALUES
(1, NULL, '88.236.72.121', '2026-04-17 23:16:50.357088+00', 'bccdbc10-eda2-4ba8-bcc1-e76c21e54548', TRUE, NULL),
(2, NULL, '88.236.72.121', '2026-04-17 23:33:38.603257+00', '18ee22b5-65ac-47f8-ad3f-43a9b6e0f674', TRUE, NULL);

-- SERIAL sequence'i guncelle (yeni kayitlar dogru ID alsin)
SELECT setval('"LoginLogs_Id_seq"', (SELECT MAX("Id") FROM "LoginLogs"));
