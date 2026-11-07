import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    final String dbPath;

    if (kIsWeb) {
      dbPath = 'jelajahku.db';
    } else {
      final folder = await getDatabasesPath();
      dbPath = p.join(folder, 'jelajahku.db');
    }

    _database = await openDatabase(
      dbPath,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE destinations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            location TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            image TEXT,
            rating REAL NOT NULL DEFAULT 0,
            latitude REAL,
            longitude REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            destination_id INTEGER NOT NULL UNIQUE,
            FOREIGN KEY (destination_id)
              REFERENCES destinations(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE journals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT,
            photo_path TEXT,
            visit_date TEXT NOT NULL,
            destination_id INTEGER,
            FOREIGN KEY (destination_id)
              REFERENCES destinations(id) ON DELETE SET NULL
          )
        ''');

        await _createDestinationPhotosTable(db);
        await _insertInitialDestinations(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE destinations ADD COLUMN latitude REAL',
          );

          await db.execute(
            'ALTER TABLE destinations ADD COLUMN longitude REAL',
          );

          await _updateInitialCoordinates(db);
        }

        if (oldVersion < 3) {
          await _createDestinationPhotosTable(db);
        }
      },
    );

    return _database!;
  }

  // =========================
  // MEMBUAT TABEL GALERI
  // =========================

  Future<void> _createDestinationPhotosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS destination_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination_id INTEGER NOT NULL,
        photo_data TEXT NOT NULL,
        caption TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (destination_id)
          REFERENCES destinations(id) ON DELETE CASCADE
      )
    ''');
  }

  // =========================
  // DATA DESTINASI AWAL
  // =========================

  Future<void> _insertInitialDestinations(Database db) async {
    final data = [
      {
        'name': 'Benteng Van Den Bosch',
        'location': 'Ngawi, Jawa Timur',
        'category': 'Sejarah',
        'description':
            'Bangunan benteng peninggalan sejarah kolonial Belanda yang menjadi salah satu ikon wisata Kabupaten Ngawi.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.3902055,
        'longitude': 111.4546788,
      },
      {
        'name': 'Srambang Park',
        'location': 'Jogorogo, Ngawi',
        'category': 'Alam',
        'description':
            'Destinasi wisata alam di kawasan Jogorogo dengan suasana pepohonan hijau dan udara sejuk.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.56594,
        'longitude': 111.22429,
      },
      {
        'name': 'Kebun Teh Jamus',
        'location': 'Sine, Ngawi',
        'category': 'Alam',
        'description':
            'Kawasan perkebunan teh di wilayah Sine dengan pemandangan hijau dan suasana pegunungan.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.561906,
        'longitude': 111.183743,
      },
      {
        'name': 'Museum Trinil',
        'location': 'Kedunggalar, Ngawi',
        'category': 'Edukasi',
        'description':
            'Museum yang menyimpan koleksi dan informasi mengenai temuan fosil serta sejarah manusia purba.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.37432,
        'longitude': 111.35781,
      },
      {
        'name': 'Waduk Pondok',
        'location': 'Bringin, Ngawi',
        'category': 'Alam',
        'description':
            'Kawasan waduk di Kabupaten Ngawi yang menawarkan pemandangan perairan dan suasana alam.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.410603,
        'longitude': 111.561969,
      },
      {
        'name': 'Pemandian Tawun',
        'location': 'Kasreman, Ngawi',
        'category': 'Rekreasi',
        'description':
            'Destinasi rekreasi air yang menjadi salah satu pilihan wisata keluarga di Kabupaten Ngawi.',
        'image': '',
        'rating': 0.0,
        'latitude': -7.3989,
        'longitude': 111.4901,
      },
    ];

    for (final item in data) {
      await db.insert('destinations', item);
    }
  }

  // =========================
  // UPDATE KOORDINAT AWAL
  // =========================

  Future<void> _updateInitialCoordinates(Database db) async {
    final coordinates = [
      {
        'name': 'Benteng Van Den Bosch',
        'latitude': -7.3902055,
        'longitude': 111.4546788,
      },
      {
        'name': 'Srambang Park',
        'latitude': -7.56594,
        'longitude': 111.22429,
      },
      {
        'name': 'Kebun Teh Jamus',
        'latitude': -7.561906,
        'longitude': 111.183743,
      },
      {
        'name': 'Museum Trinil',
        'latitude': -7.37432,
        'longitude': 111.35781,
      },
      {
        'name': 'Waduk Pondok',
        'latitude': -7.410603,
        'longitude': 111.561969,
      },
      {
        'name': 'Pemandian Tawun',
        'latitude': -7.3989,
        'longitude': 111.4901,
      },
    ];

    for (final item in coordinates) {
      await db.update(
        'destinations',
        {
          'latitude': item['latitude'],
          'longitude': item['longitude'],
        },
        where: 'name = ?',
        whereArgs: [item['name']],
      );
    }
  }

  // =========================
  // DESTINASI
  // =========================

  Future<List<Map<String, dynamic>>> getDestinations() async {
    final db = await database;

    return db.query(
      'destinations',
      orderBy: 'name ASC',
    );
  }

  Future<int> insertDestination(Map<String, dynamic> data) async {
    final db = await database;

    return db.insert('destinations', data);
  }

  // UPDATE DESTINASI
  // URL FOTO LAMA TIDAK DIHAPUS JIKA INPUT KOSONG.

  Future<int> updateDestination(
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    final updateData = Map<String, dynamic>.from(data);

    // Mempertahankan URL foto lama jika kolom URL kosong.
    if (updateData['image'] == null ||
        updateData['image'].toString().trim().isEmpty) {
      updateData.remove('image');
    }

    return db.update(
      'destinations',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDestination(int id) async {
    final db = await database;

    return db.delete(
      'destinations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // FAVORIT
  // =========================

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;

    return db.rawQuery('''
      SELECT destinations.*
      FROM destinations
      INNER JOIN favorites
      ON destinations.id = favorites.destination_id
      ORDER BY destinations.name ASC
    ''');
  }

  Future<void> addFavorite(int destinationId) async {
    final db = await database;

    await db.insert(
      'favorites',
      {'destination_id': destinationId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(int destinationId) async {
    final db = await database;

    await db.delete(
      'favorites',
      where: 'destination_id = ?',
      whereArgs: [destinationId],
    );
  }

  Future<bool> isFavorite(int destinationId) async {
    final db = await database;

    final result = await db.query(
      'favorites',
      where: 'destination_id = ?',
      whereArgs: [destinationId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // =========================
  // JURNAL PERJALANAN
  // =========================

  Future<int> insertJournal(Map<String, dynamic> data) async {
    final db = await database;

    return db.insert('journals', data);
  }

  Future<List<Map<String, dynamic>>> getJournals() async {
    final db = await database;

    return db.query(
      'journals',
      orderBy: 'visit_date DESC',
    );
  }

  Future<int> deleteJournal(int id) async {
    final db = await database;

    return db.delete(
      'journals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // GALERI FOTO DESTINASI
  // =========================

  Future<int> insertDestinationPhoto({
    required int destinationId,
    required String photoData,
    String? caption,
  }) async {
    final db = await database;

    return db.insert('destination_photos', {
      'destination_id': destinationId,
      'photo_data': photoData,
      'caption': caption,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getDestinationPhotos(
    int destinationId,
  ) async {
    final db = await database;

    return db.query(
      'destination_photos',
      where: 'destination_id = ?',
      whereArgs: [destinationId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> deleteDestinationPhoto(int photoId) async {
    final db = await database;

    return db.delete(
      'destination_photos',
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  Future<int> countDestinationPhotos(int destinationId) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM destination_photos '
      'WHERE destination_id = ?',
      [destinationId],
    );

    return (result.first['total'] as int?) ?? 0;
  }
}