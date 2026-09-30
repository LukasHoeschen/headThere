<?php
// PUT /users/{fromCode}/share/{toCode}
// Legt fest, dass fromCode aktiv (verschlüsselt) an toCode sendet.
// Upsert, wie put_key.php/put_location.php.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    sendError("Method not allowed", 405);
}

$fromCode = safeCode($_GET['fromCode'] ?? '');
$toCode   = safeCode($_GET['toCode']   ?? '');
$body     = getJsonBody();

if ($fromCode !== '' && $fromCode === $toCode) {
    sendError("Can't share with yourself", 400);
}

$nameCiphertext = $body['nameCiphertext'] ?? null;
if ($nameCiphertext === null || !is_string($nameCiphertext) || $nameCiphertext === '' || !base64_decode($nameCiphertext, true)) {
    sendError("Invalid nameCiphertext", 400);
}

$stmt = $db->prepare("
    INSERT INTO CompassToShares (fromCode, toCode, nameCiphertext, createdAt, updatedAt)
    VALUES (?, ?, ?, NOW(), NOW())
    ON DUPLICATE KEY UPDATE nameCiphertext = VALUES(nameCiphertext), updatedAt = NOW()
") or sendError("DB error", 500);
$stmt->bind_param("sss", $fromCode, $toCode, $nameCiphertext);
$stmt->execute() or sendError("DB error", 500);

sendSuccess(null);
