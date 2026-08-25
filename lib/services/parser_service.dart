import '../models/producao.dart';
import 'ocr_service.dart';

class ParserService {
  static Producao parse(OcrResult res) {
    final prod = Producao(
      maquina: '1',
      data: DateTime.now().toString().substring(0, 10),
      operador: '',
    );

    final cleanNums = <String>[];
    for (final block in res.blocks) {
      for (final line in block.lines) {
        final lineNums = RegExp(r'\d+')
            .allMatches(line.text)
            .map((m) => m.group(0)!)
            .toList();
        if (lineNums.isEmpty) continue;

        if (lineNums.length >= 12) {
          final first = int.tryParse(lineNums[0]);
          if (first != null && first >= 1 && first <= 4 && lineNums.length == 13) {
            cleanNums.addAll(lineNums.sublist(1));
          } else {
            cleanNums.addAll(lineNums);
          }
        } else if (lineNums.length >= 6) {
          cleanNums.addAll(lineNums);
        } else if (lineNums.length <= 2 && cleanNums.isNotEmpty) {
          final first = int.tryParse(lineNums[0]);
          if (!(lineNums.length == 1 && first != null && first >= 1 && first <= 6)) {
            cleanNums.addAll(lineNums);
          }
        } else {
          cleanNums.addAll(lineNums);
        }
      }
    }

    for (int pos = 1; pos <= 6; pos++) {
      final tempo = List<String>.filled(4, '');
      final bob = List<String>.filled(4, '');
      for (int turno = 0; turno < 4; turno++) {
        int i = turno * 12 + (pos - 1) * 2;
        if (i < cleanNums.length) tempo[turno] = cleanNums[i];
        if (i + 1 < cleanNums.length) bob[turno] = cleanNums[i + 1];
      }
      prod.posicoes[pos] = PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
    }

    return prod;
  }
}
