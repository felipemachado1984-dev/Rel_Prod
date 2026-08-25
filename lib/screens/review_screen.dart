import 'package:flutter/material.dart';
import '../models/producao.dart';
import 'report_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Producao producao;
  final String rawText;
  final List<String> debugNums;

  ReviewScreen({
    required this.producao,
    this.rawText = '',
    this.debugNums = const [],
  });

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Producao producao;
  late TextEditingController _rawTextController;
  late TextEditingController _maquinaController;
  late TextEditingController _operadorController;
  final _tempoControllers = <int, List<TextEditingController>>{};
  final _bobinaControllers = <int, List<TextEditingController>>{};

  @override
  void initState() {
    super.initState();
    producao = widget.producao;
    _rawTextController = TextEditingController(text: widget.rawText);
    _maquinaController = TextEditingController(text: producao.maquina);
    _operadorController = TextEditingController(text: producao.operador);

    for (int pos = 1; pos <= 6; pos++) {
      final dados = producao.posicoes[pos] ?? PosicaoData();
      _tempoControllers[pos] = [];
      _bobinaControllers[pos] = [];
      for (int t = 0; t < 4; t++) {
        _tempoControllers[pos]!.add(
          TextEditingController(text: dados.tempoRompido[t]),
        );
        _bobinaControllers[pos]!.add(
          TextEditingController(text: dados.bobinasCheias[t]),
        );
      }
    }
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    _maquinaController.dispose();
    _operadorController.dispose();
    for (final list in _tempoControllers.values) {
      for (final c in list) c.dispose();
    }
    for (final list in _bobinaControllers.values) {
      for (final c in list) c.dispose();
    }
    super.dispose();
  }

  void _salvarEAvancar() {
    producao.maquina = _maquinaController.text.trim();
    producao.operador = _operadorController.text.trim();

    for (int pos = 1; pos <= 6; pos++) {
      final tempo = <String>[];
      final bobinas = <String>[];
      for (int t = 0; t < 4; t++) {
        tempo.add(_tempoControllers[pos]![t].text.trim());
        bobinas.add(_bobinaControllers[pos]![t].text.trim());
      }
      if (producao.posicoes[pos] != null) {
        producao.posicoes[pos]!.tempoRompido = tempo;
        producao.posicoes[pos]!.bobinasCheias = bobinas;
      } else {
        producao.posicoes[pos] =
            PosicaoData(tempoRompido: tempo, bobinasCheias: bobinas);
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(producao: producao),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Revisar Dados'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== CAMPOS DE MAQUINA E OPERADOR =====
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('Maquina:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maquinaController,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('Operador:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _operadorController,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('Data: ${producao.data}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            // ===== DEBUG =====
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[400]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DEBUG: ${widget.debugNums.length} numeros extraidos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Esperado: 48 (4 turnos x 6 pos x 2 valores)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (int i = 0; i < widget.debugNums.length; i++)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '$i:${widget.debugNums[i]}',
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            ExpansionTile(
              title: Text('Texto OCR (bruto)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              initiallyExpanded: false,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _rawTextController,
                    maxLines: 12,
                    decoration: InputDecoration(border: InputBorder.none),
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            for (int pos = 1; pos <= 6; pos++) _buildPosicaoEditor(pos),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _salvarEAvancar,
        icon: Icon(Icons.check),
        label: Text('Gerar Relatorio'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPosicaoEditor(int pos) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Posicao $pos',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2563EB))),
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 50, child: Text('Turno', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Tempo rompido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Bobinas cheias', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
            Divider(),
            for (int t = 0; t < 4; t++) ...[
              Row(
                children: [
                  SizedBox(width: 50, child: Text('${t + 1}', style: TextStyle(fontSize: 12))),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: TextField(
                        controller: _tempoControllers[pos]![t],
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        ),
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _bobinaControllers[pos]![t],
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      ),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
