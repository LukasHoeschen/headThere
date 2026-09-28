-- Selbst auf dem Server ausführen (z.B. via phpMyAdmin oder mysql-CLI), um
-- komplett neu zu starten: löscht ALLE Codes, Public Keys, Standorte und
-- Freigaben für ALLE Nutzer. Betrifft nicht die App/Keychain auf dem Gerät —
-- dafür in der App unter Einstellungen "Reset Location Sharing" verwenden.
TRUNCATE TABLE CompassToShares;
TRUNCATE TABLE CompassToLocations;
TRUNCATE TABLE CompassToKeys;
