-- Auf dem Server einmalig ausführen, um die neue Tabelle für aktive Freigaben anzulegen.
CREATE TABLE CompassToShares (
    fromCode VARCHAR(32) NOT NULL,
    toCode VARCHAR(32) NOT NULL,
    nameCiphertext TEXT NOT NULL,
    createdAt DATETIME NOT NULL,
    updatedAt DATETIME NOT NULL,
    PRIMARY KEY (fromCode, toCode),
    INDEX idx_toCode (toCode)
);
