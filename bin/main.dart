import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

Future<void> main(List<String> arguments) async {
  var dir = Directory('test_pose');
  final poses = <Map<String, dynamic>>[];
  final files = <String>[];
  final temporaryPoses = <Map<String, dynamic>>[];

  try {
    var dirList = dir.list();

    /// ディレクトリからjsonファイルを読み込み、一旦リストに保存する。
    await for (FileSystemEntity f in dirList) {
      if (f is File && f.path.endsWith('.json')) {
        files.add(f.path);
      }
    }

    /// ファイル一覧をソートする。
    files.sort();

    for (var i = 0; i < files.length; i++) {
      final path = files[i];

      await File(path).readAsString().then((content) {
        /// ソートしたファイル一覧を参照し、jsonとして読み込む。
        Map<String, dynamic> parsed = jsonDecode(content);

        /// 一旦パースした物を保存、前のjsonとの差分を取る。
        temporaryPoses.add(parsed);
        poses.add(optimizePose(
            current: parsed, prev: i == 0 ? null : temporaryPoses[i - 1]));
      });
    }

    final posesJson = jsonEncode(poses);
    final output = File('pose_animation.json');
    await output.writeAsString(posesJson, mode: FileMode.write);
    print('Successfully generated file. [pose_animation.json]');
  } catch (e) {
    print(e.toString());
  }
}

/// パースしたjsonについて、前回との差分を取り保存する関数
Map<String, dynamic> optimizePose(
    {Map<String, dynamic> current, Map<String, dynamic> prev}) {
  final store = <String, dynamic>{};
  const listEquality = ListEquality();

  if (prev == null) {
    return current;
  }

  current.keys.forEach((key) {
    if (!listEquality.equals(current[key]['rotation'], prev[key]['rotation'])) {
      store[key] = current[key];
    }
  });

  return store;
}
