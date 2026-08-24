class Producao {
  String maquina;
  String data;
  int turnos;
  String operador;
  Map<int, Posicao> posicoes;

  Producao({
    this.maquina = '',
    this.data = '',
    this.turnos = 4,
    this.operador = '',
  }) : posicoes = {
          for (int i = 1; i <= 6; i++) i: Posicao(),
        };
}

class Posicao {
  List<String> tempoRompido;
  List<String> bobinasCheias;

  Posicao()
      : tempoRompido = List.filled(8, ''),
        bobinasCheias = List.filled(8, '');

  int get preenchidos =>
      tempoRompido.where((v) => v.isNotEmpty).length +
      bobinasCheias.where((v) => v.isNotEmpty).length;
}
