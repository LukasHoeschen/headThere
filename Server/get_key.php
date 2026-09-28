<?php
// GET /users/{code}/key
// Liefert den öffentlichen Schlüssel für einen Code.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError("Method not allowed", 405);
}

$code = safeCode($_GET['code'] ?? '');

$stmt = $db->prepare("SELECT publicKey FROM CompassToKeys WHERE code = ? LIMIT 1")
    or sendError("DB error", 500);
$stmt->bind_param("s", $code);
$stmt->execute() or sendError("DB error", 500);

$row = $stmt->get_result()->fetch_object();
if (!$row) {
    sendError("Not found", 404);
}

sendSuccess(["publicKey" => $row->publicKey]);
