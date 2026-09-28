<?php
// GET /users/{ownerCode}/location/{myCode}
// Holt den verschlüsselten Standort, den ownerCode für myCode veröffentlicht hat.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError("Method not allowed", 405);
}

$ownerCode = safeCode($_GET['ownerCode'] ?? '');
$myCode    = safeCode($_GET['myCode']    ?? '');

$stmt = $db->prepare("
    SELECT ciphertext, locationTimestamp
    FROM CompassToLocations
    WHERE myCode = ? AND forCode = ?
    LIMIT 1
") or sendError("DB error", 500);
$stmt->bind_param("ss", $ownerCode, $myCode);
$stmt->execute() or sendError("DB error", 500);

$row = $stmt->get_result()->fetch_object();
if (!$row) {
    sendError("Not found", 404);
}

sendSuccess([
    "ciphertext" => $row->ciphertext,
    "timestamp"  => $row->locationTimestamp,
]);
