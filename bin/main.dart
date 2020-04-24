import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:collection/collection.dart';

import 'handleArgParser.dart';

Future<void> main(List<String> arguments) async {
  final poses = <Map<String, dynamic>>[];
  final files = <String>[];
  final temporaryPoses = <Map<String, dynamic>>[];
  final parser = ArgParser();
  var isPro = false;

  var inputDirectory = 'input';

  final parsedArgs = handleParseArguments(parser, arguments);
  isPro = parsedArgs['pro'];

  if (parsedArgs['help']) {
    print(parser.usage);
    exit(0);
  }

  if (parsedArgs.rest.isNotEmpty) {
    inputDirectory = parsedArgs.rest[0];
  }

  var dir = Directory(inputDirectory);
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
      final currentFile = files[i];

      await File(currentFile).readAsString().then((content) {
        /// ソートしたファイル一覧を参照し、jsonとして読み込む。
        Map<String, dynamic> parsed = jsonDecode(content);

        /// 一旦パースした物を保存、前のjsonとの差分を取る。
        temporaryPoses.add(parsed);

        if (isPro) {
          /// Pro mode
          poses.add(optimizePose(
              current: parsed, prev: i == 0 ? null : temporaryPoses[i - 1]));
        } else {
          /// Basic interpolate mode
          if (i != 0) {
            final currentFrame =
                int.tryParse(currentFile.replaceAll(RegExp(r'.+/|.json'), ''));
            final prevFrame =
                int.tryParse(files[i - 1].replaceAll(RegExp(r'.+/|.json'), ''));
            poses.addAll(
              optimizePoseWithInterpolate(
                prevFrame: prevFrame == 0 ? prevFrame : prevFrame + 1,
                currentFrame: currentFrame,
                prev: temporaryPoses[i - 1],
                current: parsed,
                isFirst: prevFrame == 0,
              ),
            );
          }
        }
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

/// パースしたjsonについて、補間しつつ差分を取り保存する関数
List<Map<String, dynamic>> optimizePoseWithInterpolate(
    {int prevFrame,
    int currentFrame,
    Map<String, dynamic> current,
    Map<String, dynamic> prev,
    bool isFirst}) {
  final interpolated = <String, Map<String, dynamic>>{};
  const listEquality = ListEquality();

  assert(current != null);
  assert(prev != null);

  /// 各フレームごとの処理
  for (var i = prevFrame; i <= currentFrame; i++) {
    final frame = i.toString();

    /// ボーンの名前ごとの処理
    current.keys.forEach((key) {
      final cRot = current[key]['rotation'];
      final pRot = prev[key]['rotation'];

      if (isFirst && i == prevFrame) {
        /// 0フレーム目の処理の場合
        /// rotationをそのまま記録する
        /// interpolatedにフレームを記録するMap、ボーンの名前を記録するMapを作成
        interpolated[frame] ??= {};
        interpolated[frame][key] ??= {};
        interpolated[frame][key]['rotation'] = [...pRot];
      } else if (!listEquality.equals(cRot, pRot)) {
        /// 差分がある場合
        /// 差分を線形補間する
        /// interpolatedにフレームを記録するMap、ボーンの名前を記録するMapを作成
        interpolated[frame] ??= {};
        interpolated[frame][key] ??= {};
        interpolated[frame][key]['rotation'] = [
          (cRot[0] - pRot[0]) * (i - prevFrame) / (currentFrame - prevFrame) +
              pRot[0],
          (cRot[1] - pRot[1]) * (i - prevFrame) / (currentFrame - prevFrame) +
              pRot[1],
          (cRot[2] - pRot[2]) * (i - prevFrame) / (currentFrame - prevFrame) +
              pRot[2],
          (cRot[3] - pRot[3]) * (i - prevFrame) / (currentFrame - prevFrame) +
              pRot[3],
        ];
      }
    });
  }

  final sortedKeys = interpolated.keys.toList()..sort();
  final store = <Map<String, dynamic>>[];
  for (var key in sortedKeys) {
    store.add(interpolated[key]);
  }

  return store;
}
