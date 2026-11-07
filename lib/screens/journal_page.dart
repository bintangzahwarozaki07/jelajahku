
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

import '../database/database_helper.dart';

const Color primaryGreen = Color(0xFF16865B);

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _destinations = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final journals = await _database.getJournals();
      final destinations = await _database.getDestinations();

      if (!mounted) return;

      setState(() {
        _journals = journals;
        _destinations = destinations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat jurnal: $e')),
      );
    }
  }

  Future<void> _openJournalForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalFormPage(
          destinations: _destinations,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteJournal(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Jurnal'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus jurnal perjalanan ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _database.deleteJournal(id);
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jurnal berhasil dihapus.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus jurnal: $e')),
      );
    }
  }

  String _destinationName(dynamic destinationId) {
    if (destinationId == null) {
      return 'Destinasi tidak ditentukan';
    }

    for (final destination in _destinations) {
      if (destination['id'] == destinationId) {
        return destination['name']?.toString() ?? 'Destinasi';
      }
    }

    return 'Destinasi tidak ditemukan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jurnal Perjalanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openJournalForm,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Tambah Jurnal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _journals.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _journals.length,
                    itemBuilder: (context, index) {
                      return _buildJournalCard(_journals[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 85,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Jurnal Perjalanan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Simpan pengalaman perjalanan Anda dengan foto dan cerita menarik.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openJournalForm,
              icon: const Icon(Icons.add),
              label: const Text('Buat Jurnal Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalCard(Map<String, dynamic> journal) {
    final title = journal['title']?.toString() ?? 'Tanpa Judul';
    final note = journal['note']?.toString() ?? '';
    final date = journal['visit_date']?.toString() ?? '';
    final photoPath = journal['photo_path']?.toString() ?? '';

    final destinationName =
        _destinationName(journal['destination_id']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(photoPath),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.place,
                      size: 17,
                      color: primaryGreen,
                    ),
                    const SizedBox(width: 5),
                    Expanded(child: Text(destinationName)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 7),
                    Text(date),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    note,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _deleteJournal(journal['id'] as int);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String photoPath) {
    if (photoPath.startsWith('data:image')) {
      try {
        final encoded = photoPath.split(',').last;
        final bytes = base64Decode(encoded);

        return Image.memory(
          bytes,
          width: double.infinity,
          height: 190,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _photoPlaceholder(),
        );
      } catch (_) {
        return _photoPlaceholder();
      }
    }

    if (photoPath.startsWith('http://') ||
        photoPath.startsWith('https://')) {
      return Image.network(
        photoPath,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoPlaceholder(),
      );
    }

    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 170,
      color: Colors.grey.shade200,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 50,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'Tidak ada foto',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FORM TAMBAH JURNAL PERJALANAN
// =====================================================

class JournalFormPage extends StatefulWidget {
  final List<Map<String, dynamic>> destinations;

  const JournalFormPage({
    super.key,
    required this.destinations,
  });

  @override
  State<JournalFormPage> createState() => _JournalFormPageState();
}

class _JournalFormPageState extends State<JournalFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;

  DateTime _visitDate = DateTime.now();

  int? _selectedDestinationId;

  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Mengambil foto langsung menggunakan webcam.
  Future<void> _takePhotoWithCamera() async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final Uint8List? capturedPhoto = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(),
        ),
      );

      if (!mounted) return;

      if (capturedPhoto != null) {
        setState(() {
          _photoBytes = capturedPhoto;
        });
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
        setState(() => _isPickingImage = false);
      }
    }
  }

  // Galeri tetap menggunakan image_picker.
  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isPickingImage = true);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _photoBytes = bytes;
      });
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
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _showImageOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: primaryGreen,
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
                  color: primaryGreen,
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

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Kunjungan',
    );

    if (selectedDate != null) {
      setState(() {
        _visitDate = selectedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }

  Future<void> _saveJournal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String photoData = '';

      if (_photoBytes != null) {
        photoData =
            'data:image/jpeg;base64,${base64Encode(_photoBytes!)}';
      }

      await DatabaseHelper.instance.insertJournal({
        'title': _titleController.text.trim(),
        'note': _noteController.text.trim(),
        'photo_path': photoData,
        'visit_date': _formatDate(_visitDate),
        'destination_id': _selectedDestinationId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jurnal perjalanan berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan jurnal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Jurnal Perjalanan'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dokumentasi Perjalanan',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: _isPickingImage ? null : _showImageOptions,
                child: Container(
                  width: double.infinity,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isPickingImage
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _photoBytes != null
                          ? Image.memory(
                              _photoBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 55,
                                  color: primaryGreen,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Tambahkan Foto Perjalanan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Ketuk untuk membuka kamera atau galeri',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Judul Perjalanan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Liburan ke Srambang Park',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul perjalanan wajib diisi.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              const Text(
                'Destinasi Wisata',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedDestinationId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.place),
                  hintText: 'Pilih destinasi wisata',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.destinations.map((destination) {
                  return DropdownMenuItem<int>(
                    value: destination['id'] as int,
                    child: Text(
                      destination['name'].toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDestinationId = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              const Text(
                'Tanggal Kunjungan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_month),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_formatDate(_visitDate)),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Cerita Perjalanan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Ceritakan pengalaman, suasana, dan kesan selama perjalanan...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveJournal,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Jurnal',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HALAMAN KAMERA WEBCAM
// =====================================================

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;

  bool _isInitializing = true;
  bool _isTakingPicture = false;
  String? _errorMessage;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang ditemukan.');
      }

      await _startCamera(_selectedCameraIndex);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _startCamera(int index) async {
    try {
      final oldController = _controller;
      _controller = null;

      if (oldController != null) {
        await oldController.dispose();
      }

      final controller = CameraController(
        _cameras[index],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _selectedCameraIndex = index;
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Tidak dapat mengaktifkan kamera. Periksa izin kamera Chrome. Detail: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;

    setState(() {
      _isInitializing = true;
    });

    await _startCamera(nextIndex);
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    try {
      setState(() => _isTakingPicture = true);

      final XFile photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();

      if (!mounted) return;

      Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isTakingPicture = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kamera Perjalanan'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _isInitializing ? null : _switchCamera,
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Ganti kamera',
            ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography,
                          size: 65,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isInitializing = true;
                              _errorMessage = null;
                            });
                            _initializeCamera();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : controller != null &&
                      controller.value.isInitialized
                  ? Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 25),
                          child: ElevatedButton(
                            onPressed: _isTakingPicture
                                ? null
                                : _capturePhoto,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(180, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isTakingPicture
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt),
                                      SizedBox(width: 10),
                                      Text(
                                        'Ambil Foto',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'Kamera belum siap.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
    );
  }
}
