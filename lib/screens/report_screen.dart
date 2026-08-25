import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/producao.dart';

class ReportScreen extends StatelessWidget {
  final Producao producao;

  ReportScreen({required this.producao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatorio de Producao'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecalho
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Relatorio de Producao',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Maquina: ${producao.maquina}'),
                    Text('Operador: ${producao.operador}'),
                    Text('Data: ${producao.data}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // Tabela de cada posicao
            for (int pos = 1; pos <= 6; pos++) ...[
              _buildTabelaPosicao(pos),
              SizedBox(height: 16),
            ],
            // Botao de compartilhar
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _compartilhar(context),
              icon: Icon(Icons.share),
              label: Text('Compartilhar Relatorio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabelaPosicao(int pos) {
    final dados = producao.posicoes[pos] ?? PosicaoData();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Posicao $pos',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2563EB))),
            SizedBox(height: 8),
            // Cabecalho
            Row(
              children: [
                Expanded(
                    flex: 1,
                    child: Text('Turno',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('Tempo Rompido',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('Bobinas Cheias',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
            Divider(),
            // 4 linhas (turnos)
            for (int t = 0; t < 4; t++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        flex: 1,
                        child: Text('${t + 1}', style: TextStyle(fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text(dados.tempoRompido[t],
                            style: TextStyle(fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text(dados.bobinasCheias[t],
                            style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _compartilhar(BuildContext context) async {
    try {
      final StringBuffer sb = StringBuffer();
      sb.writeln('RELATORIO DE PRODUCAO');
      sb.writeln('====================');
      sb.writeln('Maquina: ${producao.maquina}');
      sb.writeln('Operador: ${producao.operador}');
      sb.writeln('Data: ${producao.data}');
      sb.writeln();

      for (int pos = 1; pos <= 6; pos++) {
        final dados = producao.posicoes[pos] ?? PosicaoData();
        sb.writeln('Posicao $pos:');
        for (int t = 0; t < 4; t++) {
          sb.writeln(
              '  Turno ${t + 1}: Tempo=${dados.tempoRompido[t]}, Bobinas=${dados.bobinasCheias[t]}');
        }
        sb.writeln();
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/relatorio_producao.txt');
      await file.writeAsString(sb.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Relatorio de Producao ${producao.data}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e')),
      );
    }
  }
}
