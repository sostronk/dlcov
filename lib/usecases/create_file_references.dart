import 'dart:async';
import 'dart:io';

import 'package:dlcov/core/extensions/list_extension.dart';
import 'package:dlcov/utils/file_matcher_util.dart';

import '../core/app_constants.dart';
import '../core/app_error_codes.dart';
import '../entities/config.dart';
import '../utils/file_system/file_system_util.dart';

class CreateFileReferences {
  final String _sourceDirectory;

  final CreateFileReferencesHelper _helper;
  final String? _packageName;
  final Config _config;

  CreateFileReferences(this._helper, this._sourceDirectory, this._config)
      : _packageName = _config.packageName ??
            File('pubspec.yaml')
                .readAsLinesSync()
                .firstWhere((line) => line.startsWith('name:'))
                .split(':')
                .last
                .trim();

  Future<File> call() async {
    final fileSytemEntities =
        await _helper.getFileSystemEntities(Directory(_sourceDirectory));

    final candidateFiles =
        await _helper.getOnlyCandidateFiles(fileSytemEntities);

    final filteredFilePaths = _helper.getFilteredFilePaths(
        candidateFiles,
        _config.excludeSuffixes,
        _config.excludeFiles,
        _config.excludeContents,
        _config.excludeContentsPath);

    final fileImports = [
      '/*\n'
          'Do not edit this file manually, it is overwritten every time dlcov\n'
          'runs, in order to make coverage work for all dart files\n'
          '*/\n',
    ];

    fileImports.add('// ignore_for_file: unused_import');
    filteredFilePaths.sort();

    fileImports.addAll(filteredFilePaths
        .map((path) =>
            "import 'package:$_packageName${path.replaceFirst(_sourceDirectory, '').replaceAll('\\', '/')}';")
        .toList());

    fileImports.add('void main(){}');

    final allFilesReferences = fileImports.join('\n');

    return await _helper.writeContentToFile(
        allFilesReferences, AppConstants.dlcovFileReferences);
  }
}

class CreateFileReferencesHelper {
  final FileSystemUtil fileSystemUtil;

  CreateFileReferencesHelper(this.fileSystemUtil);

  getImportsList(List<FileSystemEntity> fileSytemEntities,
      List<String> removeFileWithSuffixes) {}

  Future<List<FileSystemEntity>> getFileSystemEntities(Directory dir) {
    final files = <FileSystemEntity>[];
    final completer = Completer<List<FileSystemEntity>>();
    final filesStream = dir.list(recursive: true);
    filesStream.listen((file) => files.add(file),
        onError: (error) {
          print(error);
          exit(AppErrorCodes.commandCannotExecute);
        },
        onDone: () => completer.complete(files));
    return completer.future;
  }

  List<String> getFilteredFilePaths(
      List<File> files,
      List<String> removeFileWithSuffixes,
      List<RegExp> excludeFiles,
      List<RegExp> excludeContents,
      String? excludeContentsPath) {
    final fileMatcher = FileMatcherUtil();
    final fileSystemUtil = FileSystemUtil();
    Iterable<File> filteredList = files
        .where((file) => !fileMatcher.hasSuffix(
            file: file.path, excludeSuffixes: removeFileWithSuffixes))
        .where((file) =>
            !fileMatcher.hasPattern(value: file.path, patterns: excludeFiles));

    if (excludeContentsPath != null) {
      final excludeContentsByPathList = fileSystemUtil
          .readAsLinesSync(excludeContentsPath)
          .mapRegex()
          .toList(growable: false);

      filteredList = filteredList.where((file) {
        final loc = file.readAsLinesSync();
        final hasPatterns = fileMatcher.hasPatterns(
            values: loc, patterns: excludeContentsByPathList);
        return !hasPatterns;
      });
    } else if (excludeContents.isNotEmpty) {
      filteredList = filteredList.where((file) {
        final loc = file.readAsLinesSync();
        final hasPatterns =
            fileMatcher.hasPatterns(values: loc, patterns: excludeContents);
        return !hasPatterns;
      });
    }

    final filteredFilePaths = filteredList.map((e) => e.path).toList();
    return filteredFilePaths;
  }

  Future<List<File>> getOnlyCandidateFiles(
      List<FileSystemEntity> fileSytemEntities) async {
    List<File> candidateFiles = fileSytemEntities.whereType<File>().toList();
    return candidateFiles
        .where((file) => file.path.endsWith('.dart'))
        .where((file) =>
            !file.readAsLinesSync().any((line) => line.startsWith('part of')))
        .toList();
  }

  Future<File> writeContentToFile(String content, String path) =>
      fileSystemUtil.writeToFile(content, path);
}
