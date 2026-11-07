
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/database_helper.dart';
import 'journal_page.dart';

const Color galleryGreen = Color(0xFF16865B);

class GalleryPage extends StatefulWidget {
  final int destinationId;
  final String destinationName;

  const GalleryPage({
    super.key,
    required this.destinationId,
    required this.destinationName,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _photos = [];

  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _database.getDestinationPhotos(
        widget.destinationId,
      );

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat galeri: $e')),
      );
    }
  }

  Future<void> _showPhotoOptions() async {
    if (_isProcessing) return;

    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: galleryGreen,
                ),
                title: const Text('Ambil Foto dengan Webcam'),
                subtitle: const Text('Gunakan kamera laptop secara langsung'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: galleryGreen,
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Pilih foto dari laptop'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhotoWithCamera() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Menggunakan halaman kamera yang sudah dipakai oleh fitur jurnal.
      final Uint8List? bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(),
        ),
      );

      if (!mounted) return;

      if (bytes != null) {
        await _savePhoto(bytes);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kamera gagal dibuka: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      await _savePhoto(bytes);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _savePhoto(Uint8List bytes) async {
    final captionController = TextEditingController();

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Keterangan Foto'),
            content: TextField(
              controller: captionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Contoh: Pemandangan area wisata...',
                labelText: 'Keterangan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: galleryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan Foto'),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) return;

      final photoData =
          'data:image/jpeg;base64,${base64Encode(bytes)}';

      await _database.insertDestinationPhoto(
        destinationId: widget.destinationId,
        photoData: photoData,
        caption: captionController.text.trim().isEmpty
            ? null
            : captionController.text.trim(),
      );

      await _loadPhotos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto dokumentasi berhasil disimpan!'),
          backgroundColor: galleryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      captionController.dispose();
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Foto'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus foto dokumentasi ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _database.deleteDestinationPhoto(photo['id'] as int);
      await _loadPhotos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil dihapus.'),
          backgroundColor: galleryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus foto: $e')),
      );
    }
  }

  Uint8List? _decodePhoto(String photoData) {
    try {
      if (photoData.startsWith('data:image')) {
        return base64Decode(photoData.split(',').last);
      }

      return base64Decode(photoData);
    } catch (_) {
      return null;
    }
  }

  void _showPhotoDetail(Map<String, dynamic> photo) {
    final photoData = photo['photo_data']?.toString() ?? '';
    final caption = photo['caption']?.toString() ?? '';
    final bytes = _decodePhoto(photoData);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bytes != null)
                Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                )
              else
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.destinationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(caption),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 75,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'Belum Ada Foto Dokumentasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan foto untuk menyimpan dokumentasi ${widget.destinationName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _showPhotoOptions,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Tambah Foto Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: galleryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final photoData = photo['photo_data']?.toString() ?? '';
    final caption = photo['caption']?.toString() ?? '';
    final bytes = _decodePhoto(photoData);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showPhotoDetail(photo),
              child: SizedBox(
                width: double.infinity,
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 5, 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    caption.isEmpty ? 'Dokumentasi wisata' : caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Pilihan foto',
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deletePhoto(photo);
                    } else if (value == 'view') {
                      _showPhotoDetail(photo);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Text('Lihat foto'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Hapus foto',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Galeri Dokumentasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: galleryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadPhotos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showPhotoOptions,
        backgroundColor: galleryGreen,
        foregroundColor: Colors.white,
        icon: _isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_a_photo),
        label: Text(_isProcessing ? 'Memproses...' : 'Tambah Foto'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.destinationName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_photos.length} foto dokumentasi',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPhotos,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                            return _buildPhotoCard(_photos[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
