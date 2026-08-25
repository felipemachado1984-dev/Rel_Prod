class PosicaoData {
  List<String> tempoRompido;
  List<String> bobinasCheias;

  PosicaoData({
    List<String>? tempoRompido,
    List<String>? bobinasCheias,
  })  : tempoRompido = tempoRompido ?? List.filled(4, ''),
        bobinasCheias = bobinasCheias ?? List.filled(4, '');
}

class Producao {
  String maquina;
  String data;
  String operador;
  Map<int, PosicaoData> posicoes;

  Producao({
    required this.maquina,
    required this.data,
    this.operador = '',
    Map<int, PosicaoData>? posicoes,
  }) : posicoes = posicoes ?? {};
}
