import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../utils/app_colors.dart';
import 'document_editor_screen.dart';
import 'document_viewer_screen.dart';
import 'ocr_scanner_screen.dart';
import 'widgets/document_card.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  late DocumentProvider _documentProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _documentProvider = DocumentProvider.instance;
    // Fetch documents with a small delay to ensure auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _documentProvider.fetchDocuments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app resumes from background
      _documentProvider.fetchDocuments();
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _documentProvider.clearSearch();
    } else {
      _documentProvider.searchDocuments(query);
    }
  }

  void _onCreateDocument() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DocumentEditorScreen(),
      ),
    ).then((_) {
      _searchController.clear();
      _documentProvider.clearSearch();
      _documentProvider.fetchDocuments();
    });
  }

  void _onDocumentTap(DocumentModel document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(document: document),
      ),
    ).then((_) {
      _searchController.clear();
      _documentProvider.clearSearch();
      _documentProvider.fetchDocuments();
    });
  }

  void _showFABMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 100,
        MediaQuery.of(context).size.height - 150,
        20,
        20,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'compose',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('Soạn tài liệu mới'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'scan',
          child: Row(
            children: [
              Icon(Icons.camera_alt, size: 20),
              SizedBox(width: 12),
              Text('Quét từ Camera'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'compose') {
        _onCreateDocument();
      } else if (value == 'scan') {
        _onScanDocument();
      }
    });
  }

  void _onScanDocument() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OcrScannerScreen(),
      ),
    ).then((_) {
      _searchController.clear();
      _documentProvider.clearSearch();
      _documentProvider.fetchDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Tài Liệu'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: ChangeNotifierProvider<DocumentProvider>.value(
        value: _documentProvider,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tiêu đề hoặc nội dung...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
            // Documents Grid
            Expanded(
              child: Consumer<DocumentProvider>(
                builder: (context, provider, _) {
                  final documents = _searchController.text.isEmpty
                      ? provider.documents
                      : provider.searchResults;

                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (documents.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await _documentProvider.fetchDocuments();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'Không có tài liệu nào'
                                        : 'Không tìm thấy kết quả',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await _documentProvider.fetchDocuments();
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return DocumentCard(
                          document: doc,
                          onTap: () => _onDocumentTap(doc),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _showFABMenu,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}