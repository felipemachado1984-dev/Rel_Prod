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

  @override
  void initState() {
    super.initState();
    producao = widget.producao;
    _rawTextController = TextEditingController(text: widget.rawText);
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
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
            // Mostra o texto bruto reconhecido pelo OCR
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Texto reconhecido pelo OCR:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _rawTextController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Nenhum texto reconhecido',
                    ),
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Tabela editavel
            Text('Dados extraidos (editaveis):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            for (int pos = 1; pos <= 6; pos++) ...[
              _buildPosicaoEditor(pos),
              SizedBox(height: 16),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReportScreen(producao: producao),
            ),
          );
        },
        icon: Icon(Icons.check),
        label: Text('Gerar Relatorio'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPosicaoEditor(int pos) {
    final dados = producao.posicoes[pos]!;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Posicao $pos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 120, child: Text('Tempo rompido:')),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: dados.tempoRompido.join(', '),
                    ),
                    onChanged: (value) {
                      final lista = value.split(',').map((e) => e.trim()).toList();
                      while (lista.length < 8) lista.add('');
                      dados.tempoRompido = lista;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 120, child: Text('Bobinas cheias:')),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: dados.bobinasCheias.join(', '),
                    ),
                    onChanged: (value) {
                      final lista = value.split(',').map((e) => e.trim()).toList();
                      while (lista.length < 8) lista.add('');
                      dados.bobinasCheias = lista;
                    },
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
