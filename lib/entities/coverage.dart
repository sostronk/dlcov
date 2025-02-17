/// Coverage entity
class Coverage {
  final double _minCoverage;
  final Map<String?, double> _fileCoverage = {};
  double _totalCoverage = 0;

  /// if [isCovered]
  bool get isCovered {
    if (_minCoverage <= 0) {
      return true;
    }
    return totalCoverage >= minCoverage && allFilesCovered;
  }

  bool get allFilesCovered {
    bool allFilesCovered = true;
    for (var fileCoverage in _fileCoverage.entries) {
      final value = fileCoverage.value;
      final file = fileCoverage.key;
      if (value < minCoverage) {
        print(
            '[FAIL]: $file has ${value.toStringAsFixed(1)}% code coverage expected $_minCoverage%');
      }
      allFilesCovered &= value >= minCoverage;
    }
    return allFilesCovered;
  }

  void addFileCoverageRecord(String? file, double coverage) {
    _fileCoverage[file] = coverage;
  }

  /// [minCoverage]
  double get minCoverage => double.parse(_minCoverage.toStringAsFixed(1));

  /// [totalCoverage]
  double get totalCoverage => double.parse(_totalCoverage.toStringAsFixed(1));
  set totalCoverage(double value) {
    _totalCoverage = value;
  }

  /// [Coverage] constructor
  Coverage(this._minCoverage);
}
