import 'dart:convert';
import 'dart:html' as html; // For web
import 'dart:io' as io;
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pluto_grid/pluto_grid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ExportScreen(),
    );
  }
}

class ExportScreen extends StatefulWidget {
  static const routeName = 'feature/export';

  const ExportScreen({super.key});

  @override
  ExportScreenState createState() => ExportScreenState();
}

class ExportScreenState extends State<ExportScreen> {
  final List<PlutoColumn> columns = [];
  final List<PlutoRow> rows = [];
  late PlutoGridStateManager stateManager;

  @override
  void initState() {
    super.initState();

    columns.addAll([
      PlutoColumn(
        title: 'Column 1',
        field: 'column1',
        type: PlutoColumnType.text(),
        enableRowDrag: true,
        enableRowChecked: true,
        width: 250,
        minWidth: 175,
        renderer: (rendererContext) {
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  rendererContext.stateManager.insertRows(
                    rendererContext.rowIdx,
                    [rendererContext.stateManager.getNewRow()],
                  );
                },
                iconSize: 18,
                color: Colors.green,
                padding: const EdgeInsets.all(0),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outlined),
                onPressed: () {
                  rendererContext.stateManager
                      .removeRows([rendererContext.row]);
                },
                iconSize: 18,
                color: Colors.red,
                padding: const EdgeInsets.all(0),
              ),
              Expanded(
                child: Text(
                  rendererContext.row.cells[rendererContext.column.field]!.value
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      PlutoColumn(
        title: 'Column 2',
        field: 'column2',
        type: PlutoColumnType.select(<String>['red', 'blue', 'green']),
        renderer: (rendererContext) {
          Color textColor = Colors.black;

          if (rendererContext.cell.value == 'red') {
            textColor = Colors.red;
          } else if (rendererContext.cell.value == 'blue') {
            textColor = Colors.blue;
          } else if (rendererContext.cell.value == 'green') {
            textColor = Colors.green;
          }

          return Text(
            rendererContext.cell.value.toString(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'Column 3',
        field: 'column3',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Column 4',
        field: 'column4',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Column 5',
        field: 'column5',
        type: PlutoColumnType.text(),
       
      ),
    ]);

    rows.addAll(DummyData.rowsByColumns(length: 15, columns: columns));
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export / Download as PDF or CSV'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'You can export grid contents as PDF or CSV. The actual file download part is implemented directly for each platform or is possible through a package such as FileSaver.',
            ),
          ),
          
          Expanded(
            child: PlutoGrid(
              columns: columns,
              rows: rows,
              onChanged: (PlutoGridOnChangedEvent event) {
                print(event);
              },
              onLoaded: (PlutoGridOnLoadedEvent event) {
                event.stateManager
                    .setSelectingMode(PlutoGridSelectingMode.cell);
                stateManager = event.stateManager;
              },
              createHeader: (stateManager) => Header(
                stateManager: stateManager,
                context: context,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({
    required this.context,
    required this.stateManager,
    required this.columns,
    required this.rows,
    super.key,
  });
  final BuildContext context;
  final PlutoGridStateManager stateManager;
  final List<PlutoColumn> columns;
  final List<PlutoRow> rows;

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.TableHelper.fromTextArray(
            context: context,
            data: [
              // Column titles
              columns.map((col) => col.title).toList(),
              // Row data
              ...rows.map((row) => columns
                  .map((col) => row.cells[col.field]?.value.toString() ?? '')
                  .toList())
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  void _exportGridAsPDF() async {
    final pdfData = await _generatePDF();

    if (kIsWeb) {
      try {
        final base64Str = base64Encode(pdfData);
        final url = 'data:application/pdf;base64,$base64Str';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'export.pdf')
          ..click();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export initiated')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/export.pdf';

        final file = io.File(path);
        await file.writeAsBytes(pdfData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exported to $path')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  void _exportGridAsCSV() async {
    final csvData = <List<String>>[
      columns.map((col) => col.title).toList(),
      ...rows.map((row) => columns
          .map((col) => row.cells[col.field]?.value.toString() ?? '')
          .toList())
    ];

    final csv = const ListToCsvConverter().convert(csvData);

    if (kIsWeb) {
      // Web export
      try {
        final bytes = utf8.encode(csv);
        final base64Str = base64Encode(bytes);
        final url = 'data:text/csv;base64,$base64Str';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'export.csv')
          ..click();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV export initiated')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    } else {
      // Mobile export
      try {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/export.csv';

        final file = io.File(path);
        await file.writeAsString(csv);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported to $path')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 10,
            children: [
              ElevatedButton(
                onPressed: _exportGridAsPDF,
                child: const Text("Print to PDF and Share"),
              ),
              // Add other buttons for different export formats

              ElevatedButton(
                onPressed: _exportGridAsCSV,
                child: const Text("Print CSV"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DummyData {
  static List<PlutoRow> rowsByColumns(
      {required int length, required List<PlutoColumn> columns}) {
    final random = Random();

    return List.generate(length, (index) {
      final cells = <String, PlutoCell>{};

      for (var column in columns) {
        String value;
        if (column.field == 'column2') {
          value = ['red', 'blue', 'green'][random.nextInt(3)];
        } else {
          value = 'Item ${index + 1}';
        }
        cells[column.field] = PlutoCell(value: value);
      }

      return PlutoRow(cells: cells);
    });
  }
}
