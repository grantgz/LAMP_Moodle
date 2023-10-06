<?php
// Define the lines you want to replace
$replacementLines = [
    'opcache.enable=1',
    'opcache.memory_consumption=128',
    'opcache.max_accelerated_files=10000',
    'opcache.revalidate_freq=200'
];

// Specify the path to the php.ini file
$phpIniFilePath = '/path/to/php.ini';

// Read the contents of the php.ini file
$iniContents = file_get_contents($phpIniFilePath);

// Loop through each line and replace commented-out lines with the new lines
$lines = explode("\n", $iniContents);
foreach ($lines as &$line) {
    // Remove leading and trailing spaces
    $line = trim($line);

    // Check if the line is commented out (starts with a #)
    if (strpos($line, '#') === 0) {
        // Remove the leading # and trim again
        $line = trim(substr($line, 1));

        // Check if the line without # is in the replacement lines
        if (in_array($line, $replacementLines)) {
            // Replace the line with the new line
            $line = $replacementLines[array_search($line, $replacementLines)];
        }
    }
}

// Join the modified lines back together
$modifiedContents = implode("\n", $lines);

// Write the modified contents back to the php.ini file
file_put_contents($phpIniFilePath, $modifiedContents);

echo "php.ini has been updated.";
?>
