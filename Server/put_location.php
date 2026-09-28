<?php
// PUT /users/{myCode}/location/{forCode}
// Speichert den verschlüsselten Standort von myCode für forCode.
// Setzt voraus, dass eine aktive Freigabe (CompassToShares) für dieses Paar
// existiert — ohne "Sync" mit jemandem wird kein Standort mehr angenommen.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    sendError("Method not allowed", 405);
}

$myCode  = safeCode($_GET['myCode']  ?? '');
$forCode = safeCode($_GET['forCode'] ?? '');
$body    = getJsonBody();

$ciphertext = $body['ciphertext'] ?? null;
$timestamp  = $body['timestamp']  ?? null;

if (!$ciphertext || !base64_decode($ciphertext, true)) {
    sendError("Invalid ciphertext", 400);
}
// Basic ISO 8601 sanity check
if (!$timestamp || !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $timestamp)) {
    sendError("Invalid timestamp, expected ISO 8601 UTC (e.g. 2026-09-16T18:30:00Z)", 400);
}

$shareCheck = $db->prepare("SELECT 1 FROM CompassToShares WHERE fromCode = ? AND toCode = ? LIMIT 1")
    or sendError("DB error", 500);
$shareCheck->bind_param("ss", $myCode, $forCode);
$shareCheck->execute() or sendError("DB error", 500);
if (!$shareCheck->get_result()->fetch_object()) {
    sendError("No active share", 403);
}

$stmt = $db->prepare("
    INSERT INTO CompassToLocations (myCode, forCode, ciphertext, locationTimestamp, updatedAt)
    VALUES (?, ?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE ciphertext = VALUES(ciphertext), locationTimestamp = VALUES(locationTimestamp), updatedAt = NOW()
") or sendError("DB error", 500);
$stmt->bind_param("ssss", $myCode, $forCode, $ciphertext, $timestamp);
$stmt->execute() or sendError("DB error", 500);

sendSuccess(null);
