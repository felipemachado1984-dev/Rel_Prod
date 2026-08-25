import 'package:flutter/material.dart';
import '../models/producao.dart';
import 'report_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Producao producao;
  final String rawText;

  ReviewScreen({required this.producao, this.rawText = ''});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Producao producao;
  late TextEditingController _rawTextController;
  final _tempoControllers = <int, TextEditingController>{};
  final _bobinaControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    producao = widget.producao;
    _rawTextController = TextEditingController(text: widget.rawText);

    for (int pos = 1; pos <= 6; pos++) {
      final dados = producao.posicoes[pos];
      _tempoControllers[pos] = TextEditingController(
        text: (dados?.tempoRompido ?? List.filled(8, '')).join(', '),
      );
      _bobinaControllers[pos] = TextEditingController(
        text: (dados?.bobinasCheias ?? List.filled(8, '')).join(', '),
      );
    }
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    for (final c in _tempoControllers.values) c.dispose();
    for (final c in _bobinaControllers.values) c.dispose();
    super.dispose();
  }

  void _salvarEAvancar() {
    for (int pos = 1; pos <= 6; pos++) {
      final tempo = _tempoControllers[pos]!.text
          .split(',')
          .map((e) => e.trim())
          .toList();
      final bobinas = _bobinaControllers[pos]!.text
          .split(',')
          .map((e) => e.trim())
          .toList();
      while (tempo.length < 8) tempo.add('');
      while (bobinas.length < 8) bobinas.add('');

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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpansionTile(
              title: Text('Texto reconhecido pelo OCR',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                    maxLines: 10,
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
                SizedBox(
                    width: 100,
                    child: Text('Tempo rompido:',
                        style: TextStyle(fontSize: 12))),
                Expanded(
                  child: TextField(
                    controller: _tempoControllers[pos],
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                    width: 100,
                    child: Text('Bobinas cheias:',
                        style: TextStyle(fontSize: 12))),
                Expanded(
                  child: TextField(
                    controller: _bobinaControllers[pos],
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
