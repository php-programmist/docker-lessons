<?php
/** @var PDO $pdo */
$pdo = include "db.php";
$pdo->exec('CREATE TABLE IF NOT EXISTS `post` (
  `id` int(11) NOT NULL auto_increment,       
  `text` varchar(255)  NOT NULL default "",
   PRIMARY KEY  (`id`)
)');


$pdo->exec('INSERT INTO `post` (`text`) VALUES 
  ("Первый"),
  ("Второй"),
  ("Третий")
  ');

echo 'Инициализация завершена';