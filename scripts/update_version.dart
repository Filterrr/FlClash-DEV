import 'dart:io';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  final content = await pubspecFile.readAsString();
  final now = DateTime.now();
  final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

  final versionPattern = RegExp(r"version:\s*[\d.+]+");
  final match = versionPattern.firstMatch(content);

  if (match == null) {
    print('Error: Could not find version line in pubspec.yaml');
    exit(1);
  }

  final newVersion = "version: $dateStr";

  final newContent = content.replaceFirst(match.group(0)!, newVersion);

  await pubspecFile.writeAsString(newContent);
  print('Version updated to $newVersion');
}
