import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:vector_math/vector_math.dart';

import 'handleArgParser.dart';

Future<void> main(List<String> arguments) async {
  final poses = <Map<String, dynamic>>[];
  final files = <int, String>{};
  final fileKeys = <int>[];
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
        final key = int.tryParse(f.path.replaceAll(RegExp(r'.+/|.json'), ''));
        fileKeys.add(key);
        files[key] = f.path;
        print('Loaded ${f.path} ...');
      }
    }

    /// ファイル一覧をソートする。
    fileKeys.sort();

    for (var i = 0; i < fileKeys.length; i++) {
      final currentFile = files[fileKeys[i]];

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
            final currentFrame = fileKeys[i];
            final prevFrame = fileKeys[i - 1];
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

  print('Processing $prevFrame to $currentFrame');

  assert(current != null);
  assert(prev != null);

  /// ボーンの名前ごとの処理
  current.keys.forEach((key) {
    final cRot = current[key]['rotation'];
    final pRot = prev[key]['rotation'];

    /// 各フレームごとの処理
    for (var i = prevFrame; i <= currentFrame; i++) {
      final frame = i.toString();

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
        /// https://qiita.com/mebiusbox2/items/2fa0f0a9ca1cf2044e82#%E7%90%83%E9%9D%A2%E7%B7%9A%E5%BD%A2%E8%A3%9C%E9%96%93
        /// interpolatedにフレームを記録するMap、ボーンの名前を記録するMapを作成
        interpolated[frame] ??= {};
        interpolated[frame][key] ??= {};
        final t = (i - prevFrame) / (currentFrame - prevFrame);
        final cVec = Vector4(cRot[0], cRot[1], cRot[2], cRot[3]);
        final pVec = Vector4(pRot[0], pRot[1], pRot[2], pRot[3]);

        final theta = acos(cVec.dot(pVec));
        final lerped = pVec.scaled(sin((1.0 - t) * theta) / sin(theta)) +
            cVec.scaled(sin(t * theta) / sin(theta));
        interpolated[frame][key]['rotation'] = [
          lerped.x,
          lerped.y,
          lerped.z,
          lerped.w,
        ];
      }
    }
  });

  final sortedKeys = interpolated.keys.toList()..sort();
  final store = <Map<String, dynamic>>[];
  for (var key in sortedKeys) {
    store.add(interpolated[key]);
  }

  return store;
}
