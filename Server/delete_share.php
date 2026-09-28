<?php
// DELETE /users/{fromCode}/share/{toCode}
// Stoppt, dass fromCode an toCode sendet: löscht die Freigabe und den zuletzt
// veröffentlichten Standort für dieses Paar, damit danach nichts Altes mehr abrufbar ist.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    sendError("Method not allowed", 405);
}

$fromCode = safeCode($_GET['fromCode'] ?? '');
$toCode   = safeCode($_GET['toCode']   ?? '');

$stmt = $db->prepare("DELETE FROM CompassToShares WHERE fromCode = ? AND toCode = ?")
    or sendError("DB error", 500);
$stmt->bind_param("ss", $fromCode, $toCode);
$stmt->execute() or sendError("DB error", 500);

$stmt = $db->prepare("DELETE FROM CompassToLocations WHERE myCode = ? AND forCode = ?")
    or sendError("DB error", 500);
$stmt->bind_param("ss", $fromCode, $toCode);
$stmt->execute() or sendError("DB error", 500);

sendSuccess(null);
