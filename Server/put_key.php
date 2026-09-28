<?php
// PUT /users/{code}/key
// Speichert den öffentlichen Schlüssel (Curve25519, base64, 32 Bytes) für einen Code.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    sendError("Method not allowed", 405);
}

$code = safeCode($_GET['code'] ?? '');
$body = getJsonBody();

$publicKey = $body['publicKey'] ?? null;
if (!$publicKey || !base64_decode($publicKey, true) || strlen(base64_decode($publicKey)) !== 32) {
    sendError("Invalid publicKey: must be base64-encoded 32 bytes", 400);
}

$stmt = $db->prepare("
    INSERT INTO CompassToKeys (code, publicKey, updatedAt)
    VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE publicKey = VALUES(publicKey), updatedAt = NOW()
") or sendError("DB error", 500);
$stmt->bind_param("ss", $code, $publicKey);
$stmt->execute() or sendError("DB error", 500);

sendSuccess(null);
