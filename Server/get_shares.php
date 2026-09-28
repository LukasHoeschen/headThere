<?php
// GET /users/{code}/shares
// Liefert alle, die aktuell aktiv an {code} senden ("wer teilt gerade mit mir").
// Darüber entdeckt der Client automatisch neue Personen, ohne dass die
// Gegenseite selbst etwas eintragen musste.
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendError("Method not allowed", 405);
}

$code = safeCode($_GET['code'] ?? '');

$stmt = $db->prepare("
    SELECT fromCode, nameCiphertext, createdAt
    FROM CompassToShares
    WHERE toCode = ?
") or sendError("DB error", 500);
$stmt->bind_param("s", $code);
$stmt->execute() or sendError("DB error", 500);
$result = $stmt->get_result();

$shares = [];
while ($row = $result->fetch_object()) {
    $shares[] = [
        "fromCode"       => $row->fromCode,
        "nameCiphertext" => $row->nameCiphertext,
        "createdAt"      => $row->createdAt,
    ];
}

sendSuccess($shares);
