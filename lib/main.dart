import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database_helper.dart';
import 'screens/map_page.dart';
import 'screens/journal_page.dart';
import 'screens/gallery_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JelajahKuApp());
}

const Color primaryGreen = Color(0xFF087F5B);
const Color darkGreen = Color(0xFF075B43);
const Color backgroundColor = Color(0xFFF6F8F6);

const String adminUsername = 'admin';
const String adminPassword = 'JelajahKu2026!';
const String adminSessionKey = 'jelajahku_admin_logged_in';

class JelajahKuApp extends StatelessWidget {
  const JelajahKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JelajahKu',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class Destination {
  final int id;
  final String name;
  final String location;
  final String category;
  final String description;
  final String image;
  final double rating;
  final double? latitude;
  final double? longitude;

  const Destination({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.description,
    required this.image,
    required this.rating,
    this.latitude,
    this.longitude,
  });

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      id: map['id'] as int,
      name: map['name'] as String,
      location: map['location'] as String,
      category: map['category'] as String,
      description: map['description'] as String,
      image: (map['image'] ?? '') as String,
      rating: (map['rating'] as num).toDouble(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedTab = 0;
  String selectedCategory = 'Semua';
  String searchQuery = '';

  bool isLoading = true;
  String? loadError;

  List<Destination> destinations = [];
  Set<int> favoriteIds = {};

  final TextEditingController searchController = TextEditingController();

  final List<String> categories = [
    'Semua',
    'Alam',
    'Sejarah',
    'Edukasi',
    'Rekreasi',
  ];

  @override
  void initState() {
    super.initState();
    loadAppData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadAppData() async {
    try {
      final destinationRows =
          await DatabaseHelper.instance.getDestinations();
      final favoriteRows =
          await DatabaseHelper.instance.getFavorites();

      if (!mounted) return;

      setState(() {
        destinations =
            destinationRows.map(Destination.fromMap).toList();
        favoriteIds =
            favoriteRows.map((row) => row['id'] as int).toSet();
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }
  }

  List<Destination> get filteredDestinations {
    return destinations.where((destination) {
      final matchesCategory =
          selectedCategory == 'Semua' ||
          destination.category == selectedCategory;

      final query = searchQuery.toLowerCase().trim();

      final matchesSearch =
          destination.name.toLowerCase().contains(query) ||
          destination.location.toLowerCase().contains(query);

      final matchesTab =
          selectedTab != 2 || favoriteIds.contains(destination.id);

      return matchesCategory && matchesSearch && matchesTab;
    }).toList();
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryGreen,
      ),
    );
  }

  Future<void> toggleFavorite(Destination destination) async {
    final wasFavorite = favoriteIds.contains(destination.id);

    try {
      if (wasFavorite) {
        await DatabaseHelper.instance.removeFavorite(destination.id);
      } else {
        await DatabaseHelper.instance.addFavorite(destination.id);
      }

      if (!mounted) return;

      setState(() {
        if (wasFavorite) {
          favoriteIds.remove(destination.id);
        } else {
          favoriteIds.add(destination.id);
        }
      });
    } catch (error) {
      showMessage(
        'Gagal menyimpan favorit: $error',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text('Gagal memuat data aplikasi.'),
                          const SizedBox(height: 8),
                          Text(
                            loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => isLoading = true);
                              loadAppData();
                            },
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : IndexedStack(
                    index: selectedTab,
                    children: [
                      buildHome(),
                      buildExplore(),
                      buildFavorites(),
                      buildProfile(),
                    ],
                  ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
            if (index == 2) {
              selectedCategory = 'Semua';
              searchQuery = '';
              searchController.clear();
            }
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF3E9),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: primaryGreen),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: primaryGreen),
            label: 'Jelajah',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite, color: primaryGreen),
            label: 'Favorit',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: primaryGreen),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    final popularDestinations = destinations.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFDDF3E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.travel_explore,
                color: primaryGreen,
                size: 25,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JelajahKu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      color: darkGreen,
                    ),
                  ),
                  Text(
                    'Panduan wisata Kabupaten Ngawi',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JournalPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.book_outlined,
                color: primaryGreen,
              ),
              tooltip: 'Jurnal perjalanan',
            ),
          ],
        ),
        const SizedBox(height: 22),
        buildWelcomeBanner(),
        const SizedBox(height: 25),
        buildSectionTitle(
          'Kategori Wisata',
          'Lihat semua',
          () => setState(() => selectedTab = 1),
        ),
        const SizedBox(height: 13),
        buildCategories(),
        const SizedBox(height: 24),
        buildSectionTitle(
          'Destinasi Wisata',
          'Lihat semua',
          () {
            setState(() {
              selectedTab = 1;
              selectedCategory = 'Semua';
            });
          },
        ),
        const SizedBox(height: 13),
        if (popularDestinations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(25),
            child: Center(
              child: Text('Belum ada destinasi wisata.'),
            ),
          )
        else
          ...popularDestinations.map(buildDestinationCard),
      ],
    );
  }

  Widget buildWelcomeBanner() {
    return Container(
      height: 205,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -10,
            child: Icon(
              Icons.landscape,
              size: 135,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'EXPLORE NGAWI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Jelajahi Keindahan\nKabupaten Ngawi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 21,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => setState(() => selectedTab = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: darkGreen,
                ),
                child: const Text('Mulai Jelajah'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(
    String title,
    String action,
    VoidCallback onPressed,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCategories() {
    final icons = [
      Icons.apps,
      Icons.park_outlined,
      Icons.account_balance_outlined,
      Icons.museum_outlined,
      Icons.pool_outlined,
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final category = categories[index];

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
                selectedTab = 1;
              });
            },
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 57,
                    height: 57,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F3EB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icons[index],
                      color: primaryGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    category,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildExplore() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Jelajahi Ngawi',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Temukan destinasi menarik untuk perjalananmu.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        buildSearchField(),
        const SizedBox(height: 17),
        buildCategoryChips(),
        const SizedBox(height: 15),
        Text(
          '${filteredDestinations.length} destinasi ditemukan',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (filteredDestinations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(35),
            child: Center(
              child: Text('Destinasi tidak ditemukan.'),
            ),
          ),
        ...filteredDestinations.map(buildDestinationCard),
      ],
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() => searchQuery = value);
      },
      decoration: InputDecoration(
        hintText: 'Cari nama atau lokasi wisata...',
        prefixIcon: const Icon(
          Icons.search,
          color: primaryGreen,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selectedCategory == category,
              selectedColor: const Color(0xFFDDF3E9),
              onSelected: (_) {
                setState(() => selectedCategory = category);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget imagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFDDECE2),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.landscape,
            size: 48,
            color: primaryGreen,
          ),
          SizedBox(height: 5),
          Text(
            'Foto destinasi belum tersedia',
            style: TextStyle(
              color: darkGreen,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget destinationImage(
    Destination destination, {
    double height = 155,
  }) {
    final hasImage = destination.image.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(height == 155 ? 19 : 17),
      ),
      child: hasImage
          ? Image.network(
              destination.image,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => imagePlaceholder(height),
            )
          : imagePlaceholder(height),
    );
  }

  Widget buildDestinationCard(Destination destination) {
    final isFavorite = favoriteIds.contains(destination.id);

    return GestureDetector(
      onTap: () => showDestinationDetail(destination),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                destinationImage(destination),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      destination.category,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      onPressed: () => toggleFavorite(destination),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite ? Colors.red : primaryGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          destination.location,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (destination.rating > 0) ...[
                        const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          destination.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFavorites() {
    final favorites = destinations
        .where((destination) => favoriteIds.contains(destination.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Wisata Favorit',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Destinasi yang kamu simpan.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.all(35),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 65,
                  color: primaryGreen,
                ),
                SizedBox(height: 15),
                Text(
                  'Belum ada destinasi favorit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 7),
                Text(
                  'Tekan ikon hati pada destinasi untuk menyimpannya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ...favorites.map(buildDestinationCard),
      ],
    );
  }

  Widget buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 25),
        const CircleAvatar(
          radius: 43,
          backgroundColor: Color(0xFFDDF3E9),
          child: Icon(
            Icons.person,
            size: 48,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Pengguna JelajahKu',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Center(
          child: Text(
            'Selamat datang, Petualang!',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 30),
        profileMenu(
          Icons.favorite_outline,
          'Destinasi Favorit',
          () => setState(() => selectedTab = 2),
        ),
        profileMenu(
          Icons.edit_location_alt_outlined,
          'Kelola Destinasi',
          manageDestinations,
        ),
        profileMenu(
          Icons.photo_camera_outlined,
          'Jurnal Perjalanan',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const JournalPage(),
              ),
            );
          },
        ),
        profileMenu(
          Icons.location_on_outlined,
          'Lokasi Saya',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MapPage(),
              ),
            );
          },
        ),
        profileMenu(
          Icons.info_outline,
          'Tentang JelajahKu',
          () {
            showAboutDialog(
              context: context,
              applicationName: 'JelajahKu',
              applicationVersion: '1.0.0',
              children: const [
                Text('Aplikasi panduan wisata Kabupaten Ngawi.'),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget profileMenu(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: primaryGreen),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  // LOGIN ADMIN DAN KELOLA DESTINASI
  Future<void> manageDestinations() async {
    final prefs = await SharedPreferences.getInstance();

    // Memastikan halaman masih aktif setelah proses asynchronous.
    if (!mounted) return;

    final isLoggedIn =
        prefs.getBool(adminSessionKey) ?? false;

    if (!isLoggedIn) {
      final loginResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminLoginPage(),
        ),
      );

      if (!mounted || loginResult != true) return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationManagementPage(
          onChanged: loadAppData,
        ),
      ),
    );

    if (!mounted) return;

    await loadAppData();
  }

  void showDestinationDetail(Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationDetailPage(
          destination: destination,
          isFavorite: favoriteIds.contains(destination.id),
          onToggleFavorite: () => toggleFavorite(destination),
        ),
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Username dan password wajib diisi.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (username == adminUsername &&
        password == adminPassword) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(adminSessionKey, true);

        if (!mounted) return;

        Navigator.pop(context, true);
      } catch (error) {
        if (!mounted) return;

        setState(() {
          errorMessage = 'Gagal menyimpan sesi login.';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = 'Username atau password salah.';
        passwordController.clear();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Login Admin'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFFDDF3E9),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 42,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'Admin JelajahKu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Silakan login untuk mengelola data wisata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: primaryGreen,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      onSubmitted: (_) => login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: primaryGreen,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 13),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 23),
                    SizedBox(
                      width: double.infinity,
                      height: 49,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DestinationDetailPage extends StatefulWidget {
  final Destination destination;
  final bool isFavorite;
  final Future<void> Function() onToggleFavorite;

  const DestinationDetailPage({
    super.key,
    required this.destination,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<DestinationDetailPage> createState() =>
      _DestinationDetailPageState();
}

class _DestinationDetailPageState
    extends State<DestinationDetailPage> {
  late bool isFavorite;
  bool isSavingFavorite = false;

  @override
  void initState() {
    super.initState();
    isFavorite = widget.isFavorite;
  }

  Future<void> toggleFavorite() async {
    if (isSavingFavorite) return;

    setState(() => isSavingFavorite = true);

    try {
      await widget.onToggleFavorite();

      if (!mounted) return;

      setState(() => isFavorite = !isFavorite);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? 'Ditambahkan ke destinasi favorit.'
                : 'Dihapus dari destinasi favorit.',
          ),
          backgroundColor: primaryGreen,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSavingFavorite = false);
      }
    }
  }

  Widget buildHeroImage() {
    final image = widget.destination.image.trim();

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: image.isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _heroPlaceholder(),
            )
          : _heroPlaceholder(),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      color: const Color(0xFFDDECE2),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.landscape_outlined,
              size: 76,
              color: primaryGreen,
            ),
            SizedBox(height: 8),
            Text(
              'Foto destinasi belum tersedia',
              style: TextStyle(color: darkGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryGreen, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
    final destination = widget.destination;
    final hasCoordinates =
        destination.latitude != null &&
        destination.longitude != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            title: const Text('Detail Destinasi'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildHeroImage(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        destination.category,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: isFavorite
                    ? 'Hapus dari favorit'
                    : 'Simpan ke favorit',
                onPressed:
                    isSavingFavorite ? null : toggleFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: isFavorite
                      ? Colors.pinkAccent
                      : Colors.white,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF20352B),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          destination.location,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (destination.rating > 0) ...[
                        const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          destination.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Tentang Destinasi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      destination.description.trim().isEmpty
                          ? 'Belum ada deskripsi untuk destinasi ini.'
                          : destination.description,
                      style: const TextStyle(
                        height: 1.6,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Informasi Destinasi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  infoTile(
                    Icons.category_outlined,
                    'Kategori wisata',
                    destination.category,
                  ),
                  infoTile(
                    Icons.location_on_outlined,
                    'Lokasi',
                    destination.location,
                  ),
                  if (hasCoordinates) ...[
                    infoTile(
                      Icons.my_location,
                      'Latitude',
                      destination.latitude!.toStringAsFixed(7),
                    ),
                    infoTile(
                      Icons.explore_outlined,
                      'Longitude',
                      destination.longitude!.toStringAsFixed(7),
                    ),
                  ] else
                    infoTile(
                      Icons.info_outline,
                      'Koordinat',
                      'Koordinat lokasi belum ditambahkan oleh admin.',
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MapPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Lihat Peta Destinasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GalleryPage(
                              destinationId: destination.id,
                              destinationName: destination.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text('Buka Galeri Dokumentasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          isSavingFavorite ? null : toggleFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      label: Text(
                        isFavorite
                            ? 'Hapus dari Favorit'
                            : 'Simpan ke Favorit',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: const BorderSide(color: primaryGreen),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
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
}

class DestinationManagementPage extends StatefulWidget {
  final Future<void> Function() onChanged;

  const DestinationManagementPage({
    super.key,
    required this.onChanged,
  });

  @override
  State<DestinationManagementPage> createState() =>
      _DestinationManagementPageState();
}

class _DestinationManagementPageState
    extends State<DestinationManagementPage> {
  List<Destination> destinations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDestinations();
  }

  Future<void> loadDestinations() async {
    try {
      final rows =
          await DatabaseHelper.instance.getDestinations();

      if (!mounted) return;

      setState(() {
        destinations = rows.map(Destination.fromMap).toList();
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $error'),
        ),
      );
    }
  }

  Future<void> openForm([Destination? destination]) async {
    final nameController =
        TextEditingController(text: destination?.name ?? '');
    final locationController =
        TextEditingController(text: destination?.location ?? '');
    final descriptionController =
        TextEditingController(text: destination?.description ?? '');
    final imageController =
        TextEditingController(text: destination?.image ?? '');
    final latitudeController = TextEditingController(
      text: destination?.latitude?.toString() ?? '',
    );
    final longitudeController = TextEditingController(
      text: destination?.longitude?.toString() ?? '',
    );

    String category = destination?.category ?? 'Alam';

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  destination == null
                      ? 'Tambah Destinasi Wisata'
                      : 'Edit Destinasi Wisata',
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          textCapitalization:
                              TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama wisata *',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Lokasi *',
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Kategori wisata',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Alam',
                              child: Text('Alam'),
                            ),
                            DropdownMenuItem(
                              value: 'Sejarah',
                              child: Text('Sejarah'),
                            ),
                            DropdownMenuItem(
                              value: 'Edukasi',
                              child: Text('Edukasi'),
                            ),
                            DropdownMenuItem(
                              value: 'Rekreasi',
                              child: Text('Rekreasi'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                category = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Deskripsi wisata *',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.description_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'URL foto (opsional)',
                            prefixIcon: Icon(Icons.image_outlined),
                            hintText: 'https://...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: latitudeController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude (opsional)',
                            prefixIcon: Icon(Icons.my_location),
                            hintText: '-7.3902055',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: longitudeController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude (opsional)',
                            prefixIcon: Icon(
                              Icons.explore_outlined,
                            ),
                            hintText: '111.4546788',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '* Nama, lokasi, dan deskripsi wajib diisi. '
                          'Koordinat harus diisi berpasangan. '
                          'URL foto boleh dikosongkan.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Batal'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final location =
                          locationController.text.trim();
                      final description =
                          descriptionController.text.trim();

                      final latitudeText =
                          latitudeController.text.trim();
                      final longitudeText =
                          longitudeController.text.trim();

                      final latitude = latitudeText.isEmpty
                          ? null
                          : double.tryParse(
                              latitudeText.replaceAll(',', '.'),
                            );

                      final longitude = longitudeText.isEmpty
                          ? null
                          : double.tryParse(
                              longitudeText.replaceAll(',', '.'),
                            );

                      if (name.isEmpty ||
                          location.isEmpty ||
                          description.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Nama, lokasi, dan deskripsi wajib diisi!',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if ((latitudeText.isNotEmpty &&
                              latitude == null) ||
                          (longitudeText.isNotEmpty &&
                              longitude == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Format koordinat harus berupa angka.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if ((latitude == null) !=
                          (longitude == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Latitude dan longitude harus diisi bersamaan.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (latitude != null &&
                          (latitude < -90 || latitude > 90)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Latitude harus antara -90 sampai 90.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (longitude != null &&
                          (longitude < -180 || longitude > 180)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Longitude harus antara -180 sampai 180.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(dialogContext, true);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) return;

      final data = <String, dynamic>{
        'name': nameController.text.trim(),
        'location': locationController.text.trim(),
        'category': category,
        'description': descriptionController.text.trim(),
        'image': imageController.text.trim(),
        'rating': destination?.rating ?? 0.0,
        'latitude': latitudeController.text.trim().isEmpty
            ? null
            : double.parse(
                latitudeController.text.trim().replaceAll(',', '.'),
              ),
        'longitude': longitudeController.text.trim().isEmpty
            ? null
            : double.parse(
                longitudeController.text.trim().replaceAll(',', '.'),
              ),
      };

      if (destination == null) {
        await DatabaseHelper.instance.insertDestination(data);
      } else {
        await DatabaseHelper.instance.updateDestination(
          destination.id,
          data,
        );
      }

      await loadDestinations();
      await widget.onChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            destination == null
                ? 'Destinasi berhasil ditambahkan!'
                : 'Destinasi berhasil diperbarui!',
          ),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan destinasi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      nameController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      imageController.dispose();
      latitudeController.dispose();
      longitudeController.dispose();
    }
  }

  Future<void> deleteDestination(
    Destination destination,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus destinasi?'),
          content: Text(
            'Yakin ingin menghapus ${destination.name}?',
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
      await DatabaseHelper.instance.deleteDestination(
        destination.id,
      );

      await loadDestinations();
      await widget.onChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destinasi berhasil dihapus.'),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> logoutAdmin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout Admin'),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun Admin?',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(adminSessionKey);

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Destinasi'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout Admin',
            icon: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            onPressed: logoutAdmin,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Wisata'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : destinations.isEmpty
              ? const Center(
                  child: Text('Belum ada data wisata.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final item = destinations[index];

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFDDF3E9),
                          child: Icon(
                            Icons.place,
                            color: primaryGreen,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item.location}\n${item.category}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              openForm(item);
                            } else if (value == 'delete') {
                              deleteDestination(item);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                  ),
                                  SizedBox(width: 9),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 19,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 9),
                                  Text('Hapus'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}