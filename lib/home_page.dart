import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'pdf_merge_service.dart';

/// Item de arquivo selecionado pelo usuário.
class SelectedFile {
  final File file;

  SelectedFile(this.file);

  String get name => p.basename(file.path);
  String get sizeLabel {
    final kb = file.lengthSync() / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<SelectedFile> _files = [];
  bool _dragging = false;
  bool _processing = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione os PDFs',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    final added = result.paths
        .whereType<String>()
        .map((path) => File(path))
        .where((f) => f.existsSync())
        .map(SelectedFile.new);
    _addUnique(added);
    setState(() {});
  }

  void _addUnique(Iterable<SelectedFile> added) {
    final existing = _files.map((e) => e.file.path).toSet();
    for (final f in added) {
      if (!existing.contains(f.file.path)) {
        _files.add(f);
        existing.add(f.file.path);
      }
    }
  }

  void _handleDrop(DropDoneDetails details) async {
    final added = details.files
        .where((XFile f) => f.path.toLowerCase().endsWith('.pdf'))
        .map((f) => File(f.path))
        .where((f) => f.existsSync())
        .map(SelectedFile.new);
    _addUnique(added);
    setState(() {});
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _files.length) return;
    setState(() {
      final item = _files.removeAt(from);
      _files.insert(to, item);
    });
  }

  void _removeAt(int index) {
    setState(() => _files.removeAt(index));
  }

  void _clear() {
    setState(() => _files.clear());
  }

  void _sortByName() {
    final sorted = PdfMergeService.sortByName(
      _files.map((e) => e.file).toList(),
    );
    setState(() {
      _files
        ..clear()
        ..addAll(sorted.map(SelectedFile.new));
    });
  }

  Future<void> _merge() async {
    if (_files.isEmpty) return;
    setState(() => _processing = true);

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar PDF unido como',
      fileName: 'unidos.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    try {
      if (outputPath == null || outputPath.isEmpty) {
        setState(() => _processing = false);
        return;
      }

      final result = await PdfMergeService.merge(
        files: _files.map((e) => e.file).toList(),
        outputPath: outputPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unido: ${result.fileCount} arquivos, ${result.pageCount} páginas.\nSalvo em: ${result.outputPath}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao unir: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unir PDFs'),
        actions: [
          IconButton(
            tooltip: 'Ordenar por nome',
            icon: const Icon(Icons.sort_by_alpha),
            onPressed: _files.length < 2 ? null : _sortByName,
          ),
          IconButton(
            tooltip: 'Limpar lista',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _files.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: _handleDrop,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDropZone(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildList()),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 150,
      decoration: BoxDecoration(
        color: _dragging
            ? Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: 0.35,
              )
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _dragging
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: _dragging ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickFiles,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              _dragging ? 'Solte os PDFs aqui' : 'Arraste PDFs ou clique para selecionar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Apenas arquivos .pdf',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_files.isEmpty) {
      return const Center(
        child: Text('Nenhum arquivo adicionado ainda.'),
      );
    }
    return Card(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: _files.length,
        onReorder: _move,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, index) {
          final item = _files[index];
          return ListTile(
            key: ValueKey(item.file.path),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text('${index + 1}'),
            ),
            title: Text(item.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(item.sizeLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Subir',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index == 0 ? null : () => _move(index, index - 1),
                ),
                IconButton(
                  tooltip: 'Descer',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index == _files.length - 1
                      ? null
                      : () => _move(index, index + 1),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, semanticLabel: 'Arraste'),
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeAt(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return FilledButton.icon(
      onPressed: _processing || _files.length < 2 ? null : _merge,
      icon: _processing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.merge),
      label: Text(
        _processing
            ? 'Unindo...'
            : _files.length < 2
                ? 'Adicione ao menos 2 PDFs'
                : 'Unir ${_files.length} PDFs',
      ),
    );
  }
}