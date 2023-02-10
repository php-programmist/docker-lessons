<?php
/** @var PDO $pdo */
$pdo = include "db.php";
try {
    $stmt = $pdo->query('SELECT * from post order by id desc');
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    $posts = [];
}


$title = 'Список постов';
?>

<html lang="en">
<head>
    <title><?php echo $title ?></title>
</head>
<body>
<h1><?php echo $title ?></h1>
<table>
    <tr>
        <th>ID</th>
        <th>Текст</th>
    </tr>
    <?php foreach ($posts as $post): ?>
        <tr>
            <td><?php echo $post['id'] ?></td>
            <td><?php echo $post['text'] ?></td>
        </tr>
    <?php endforeach; ?>
</table>
</body>
</html>
