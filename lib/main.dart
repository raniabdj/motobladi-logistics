import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importation ajoutée

// --- SERVICE DE NOTIFICATION ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void initialize() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'motobladi_channel_id',
          'MotoBladi Channel',
          channelDescription: 'Notifications pour les nouvelles commandes',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    // Utiliser un ID basé sur le temps pour afficher plusieurs notifications
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("--- Notification en arrière-plan reçue ---");
  NotificationService.showNotification(
    message.notification?.title ?? 'Nouvelle Notification',
    message.notification?.body ?? 'Vous avez une nouvelle mise à jour',
  );
}

// --- CONFIGURATION ---
final String API_BASE_URL = 'https://bld.portalsi-erp.info';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1A237E);
    const accentColor = Color(0xFF1E88E5);
    return MaterialApp(
      title: 'MotoBladi Logistique',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          secondary: accentColor,
          background: const Color(0xFFF4F6F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: Colors.black12,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      // Démarrer avec AuthCheck pour la redirection
      home: const AuthCheck(),
    );
  }
}

// --- Widget de Vérification d'Authentification ---
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('motobladi_auth_token');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getToken(),
      builder: (context, snapshot) {
        // Afficher un indicateur pendant la vérification
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Si un token existe, aller à la liste
        if (snapshot.hasData && snapshot.data != null) {
          return DeliveryListPage(token: snapshot.data!);
        }
        // Sinon, aller à la connexion
        else {
          return const LoginPage();
        }
      },
    );
  }
}

// --- Modèle de données ---
class DeliveryTask {
  final int orderId;
  final String orderNumber;
  final String customerName;
  final String phone;
  final String email;
  final String address;
  final String nin;
  final String product;
  final String chassis;
  String logisticsStatus;
  DeliveryTask({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.nin,
    required this.product,
    required this.chassis,
    required this.logisticsStatus,
  });
  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      orderId: json['orderId'],
      orderNumber: json['orderNumber'],
      customerName: json['customerName'] ?? 'N/A', // Valeur par défaut
      phone: json['phone'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      address: json['address'] ?? 'N/A',
      nin: json['nin'] ?? 'N/A',
      product: json['product'] ?? 'N/A',
      chassis: json['chassis'] ?? 'N/A',
      logisticsStatus: json['logisticsStatus'] ?? 'Nouveau',
    );
  }
}

// --- Écran de Connexion ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController(text: 'motobladi');
  final _passwordController = TextEditingController(text: 'xnUX98Bs2cP23h');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    print("[FCM] Demande d'autorisation pour les notifications...");
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] Autorisation accordée par l\'utilisateur.');
      try {
        String? token = await messaging.getToken();
        if (token != null) {
          print('[FCM] Jeton obtenu: ${token.substring(0, 20)}...');
          _sendTokenToServer(token);
        } else {
          print(
            '[FCM] ERREUR: Impossible d\'obtenir le jeton de Firebase (null).',
          );
        }
      } catch (e) {
        print('[FCM] ERREUR lors de la récupération du jeton: $e');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('--- Notification en premier plan reçue ---');
        NotificationService.showNotification(
          message.notification?.title ?? 'Nouvelle Notification',
          message.notification?.body ?? 'Vous avez une nouvelle mise à jour.',
        );
        // Afficher un SnackBar aussi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification?.title}: ${message.notification?.body}',
              ),
            ),
          );
        }
      });
    } else {
      print('[FCM] L\'utilisateur a refusé l\'autorisation.');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      print("[API] Tentative d'envoi du jeton au serveur...");
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );
      if (response.statusCode == 200) {
        print("[API] Jeton enregistré avec succès sur le serveur.");
      } else {
        print(
          "[API] ERREUR: Le serveur a répondu avec le statut ${response.statusCode} lors de l'enregistrement du jeton.",
        );
      }
    } catch (e) {
      print("[API] ERREUR lors de l'envoi du jeton au serveur: $e");
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        // Vérifier mounted
        final data = json.decode(response.body);
        final String token = data['token'];

        // Sauvegarder le token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('motobladi_auth_token', token);
        print("[Auth] Token sauvegardé.");

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DeliveryListPage(token: token)),
        );
      } else if (mounted) {
        // Vérifier mounted
        final error =
            json.decode(response.body)['message'] ?? 'Erreur de connexion';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) // Vérifier mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur réseau. Vérifiez votre connexion.'),
            backgroundColor: Colors
                .orangeAccent, // Utiliser une couleur différente pour erreur réseau
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false); // Vérifier mounted
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.two_wheeler_rounded,
                      size: 64,
                      color: Color(0xFF1A237E),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MotoBladi Logistique',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Espace Livreur',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'utilisateur',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _login,
                            style: theme.elevatedButtonTheme.style?.copyWith(
                              minimumSize: MaterialStateProperty.all(
                                const Size(double.infinity, 50),
                              ),
                            ),
                            child: const Text('Se connecter'),
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

// --- Écran Principal (Liste des livraisons) ---
enum SortOption { orderNumber, customerName, status }

class DeliveryListPage extends StatefulWidget {
  final String token;
  const DeliveryListPage({super.key, required this.token});

  @override
  State<DeliveryListPage> createState() => _DeliveryListPageState();
}

class _DeliveryListPageState extends State<DeliveryListPage> {
  List<DeliveryTask> _tasks = [];
  List<DeliveryTask> _filteredTasks = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  SortOption _currentSortOption = SortOption.orderNumber;
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchDeliveryTasks();
    _setupForegroundNotifications(); // Écouter les notifications quand la page est active
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setupForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('--- Notification reçue en premier plan (DeliveryListPage) ---');
      NotificationService.showNotification(
        message.notification?.title ?? 'Nouvelle Notification',
        message.notification?.body ?? 'Vous avez une nouvelle mise à jour.',
      );
      // Afficher SnackBar et rafraîchir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification?.title}: ${message.notification?.body}',
            ),
            action: SnackBarAction(
              label: "Actualiser",
              onPressed: () => _fetchDeliveryTasks(),
            ),
          ),
        );
        _fetchDeliveryTasks(); // Rafraîchir la liste
      }
    });
  }

  void _applyFiltersAndSort() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _tasks.where((task) {
        return task.orderNumber.toLowerCase().contains(query) ||
            task.customerName.toLowerCase().contains(query) ||
            task.address.toLowerCase().contains(query);
      }).toList();

      _filteredTasks.sort((a, b) {
        int comparison;
        switch (_currentSortOption) {
          case SortOption.orderNumber:
            comparison = a.orderNumber.compareTo(b.orderNumber);
            break;
          case SortOption.customerName:
            comparison = a.customerName.compareTo(b.customerName);
            break;
          case SortOption.status:
            // Ordre de tri personnalisé: Nouveau > Préparation > Livraison > Autres
            final statusOrder = {
              'Nouveau': 0,
              'En cours de Prép.': 1,
              'En cours de livraison': 2,
            }; // Simplifié
            comparison = (statusOrder[a.logisticsStatus] ?? 99).compareTo(
              statusOrder[b.logisticsStatus] ?? 99,
            );
            break;
        }
        return _isSortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _fetchDeliveryTasks() async {
    // Si la page est déjà construite (pas le premier chargement), ne pas mettre isLoading à true pour éviter le CircularProgressIndicator plein écran
    if (_tasks.isNotEmpty) {
      setState(
        () => _error = null,
      ); // Réinitialiser l'erreur en cas de rafraîchissement manuel réussi
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/api/logistics/orders-to-deliver'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 && mounted) {
        // Vérifier mounted
        final data = json.decode(response.body);
        final List<dynamic> tasksJson = data['data'];
        final newTasks = tasksJson
            .map((json) => DeliveryTask.fromJson(json))
            .toList();

        // Comparer si la liste a réellement changé pour éviter des rebuilds inutiles
        bool listChanged =
            _isLoading || // Toujours reconstruire au premier chargement
            newTasks.length != _tasks.length ||
            !ListEquality().equals(
              newTasks.map((t) => t.orderId).toList(),
              _tasks.map((t) => t.orderId).toList(),
            ) || // Si les IDs ont changé
            !ListEquality().equals(
              newTasks.map((t) => t.logisticsStatus).toList(),
              _tasks.map((t) => t.logisticsStatus).toList(),
            ); // Si les statuts ont changé

        if (listChanged) {
          setState(() {
            _tasks = newTasks;
            _applyFiltersAndSort();
            // _isLoading = false; // Ne mettre à false qu'ici
          });
        }
      } else if (mounted) {
        // Vérifier mounted
        String errorMessage = 'Impossible de charger les livraisons.';
        try {
          final errorData = json.decode(response.body);
          errorMessage +=
              ' Raison: ${errorData['error'] ?? response.reasonPhrase}';
        } catch (e) {
          /* Ignorer l'erreur de parsing JSON si le body n'est pas du JSON */
        }
        // Gérer spécifiquement le cas 401 Unauthorized (token expiré)
        if (response.statusCode == 401) {
          print("Token expiré détecté, déconnexion...");
          _logout(); // Appeler la fonction de déconnexion
        } else {
          throw Exception('Erreur ${response.statusCode}: $errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        // Vérifier mounted
        setState(() {
          _error = e.toString();
        });
        // Afficher un SnackBar pour les erreurs de rafraîchissement
        if (!_isLoading) {
          // Ne pas montrer si c'est l'erreur du chargement initial
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur réseau.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted)
        setState(
          () => _isLoading = false,
        ); // Mettre à false dans tous les cas à la fin
    }
  }

  // Fonction de déconnexion
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('motobladi_auth_token'); // Supprimer le token
    print("[Auth] Token supprimé.");
    if (mounted) {
      // Vérifier si le widget est toujours monté
      // Utiliser pushAndRemoveUntil pour vider la pile de navigation
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (Route<dynamic> route) =>
            false, // Supprimer toutes les routes précédentes
      );
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface, // Mieux pour le thème
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                    child: Text(
                      'Trier par',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _buildSortRadioTile(
                    context,
                    setModalState,
                    'N° de Commande',
                    SortOption.orderNumber,
                  ),
                  _buildSortRadioTile(
                    context,
                    setModalState,
                    'Nom du Client',
                    SortOption.customerName,
                  ),
                  _buildSortRadioTile(
                    context,
                    setModalState,
                    'Statut',
                    SortOption.status,
                  ),
                  const Divider(height: 32, thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        'Ordre:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      FilterChip(
                        label: const Text('Croissant'),
                        selected: _isSortAscending,
                        onSelected: (s) {
                          _setSortOrder(setModalState, true);
                        },
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      ),
                      FilterChip(
                        label: const Text('Décroissant'),
                        selected: !_isSortAscending,
                        onSelected: (s) {
                          _setSortOrder(setModalState, false);
                        },
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper pour construire les RadioListTile de tri
  Widget _buildSortRadioTile(
    BuildContext context,
    StateSetter setModalState,
    String title,
    SortOption value,
  ) {
    return RadioListTile<SortOption>(
      title: Text(title),
      value: value,
      groupValue: _currentSortOption,
      onChanged: (newValue) {
        setModalState(() => _currentSortOption = newValue!);
        setState(
          () => _applyFiltersAndSort(),
        ); // Appliquer le tri immédiatement
        Navigator.pop(context); // Fermer le bottom sheet
      },
      activeColor: Theme.of(context).primaryColor,
      contentPadding: EdgeInsets.zero, // Retirer le padding par défaut
    );
  }

  // Helper pour régler l'ordre de tri via les FilterChip
  void _setSortOrder(StateSetter setModalState, bool ascending) {
    setModalState(() => _isSortAscending = ascending);
    setState(() => _applyFiltersAndSort()); // Appliquer le tri immédiatement
    Navigator.pop(context); // Fermer le bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes à traiter'),
        actions: [
          Tooltip(
            message: "Trier",
            child: IconButton(
              onPressed: _showSortOptions,
              icon: const Icon(Icons.sort_rounded),
            ),
          ), // Icône plus adaptée
          Tooltip(
            message: "Rafraîchir",
            child: IconButton(
              onPressed: _fetchDeliveryTasks,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Tooltip(
            message: "Déconnexion",
            child: IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
          ), // Utiliser la fonction _logout
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (query) =>
                  _applyFiltersAndSort(), // Filtrage instantané
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: Colors.grey,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _applyFiltersAndSort();
                          FocusScope.of(context).unfocus();
                        },
                        splashRadius: 20,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardTheme.color ?? Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                isDense: true,
              ),
            ),
          ),
          // Afficher l'indicateur linéaire seulement si on rafraîchit une liste existante
          if (_isLoading && _tasks.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDeliveryTasks,
              color: Theme.of(context).primaryColor,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Afficher l'indicateur plein écran seulement au premier chargement
    if (_isLoading && _tasks.isEmpty)
      return const Center(child: CircularProgressIndicator());

    // Afficher l'erreur seulement si la liste est vide après l'erreur
    if (_error != null && _tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red[300],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDeliveryTasks,
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    // Afficher "Aucune commande" si la liste globale est vide
    if (_tasks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune commande à traiter',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tirez vers le bas pour rafraîchir.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Afficher "Aucun résultat" si la liste filtrée est vide mais la liste globale ne l'est pas
    if (_filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat trouvé',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres mots-clés.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Afficher la liste filtrée
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 16, left: 4, right: 4),
      itemCount: _filteredTasks.length,
      separatorBuilder: (c, i) => const SizedBox(height: 4),
      itemBuilder: (c, i) {
        final task = _filteredTasks[i];
        return DeliveryTaskListItem(
          task: task,
          onTap: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) =>
                    DeliveryDetailPage(task: task, token: widget.token),
              ),
            );
            // Mettre à jour l'état local si un nouveau statut est renvoyé
            if (result != null) {
              setState(() {
                // Trouver l'index dans la liste originale (_tasks) et la liste filtrée
                final originalTaskIndex = _tasks.indexWhere(
                  (t) => t.orderId == task.orderId,
                );
                final filteredTaskIndex = _filteredTasks.indexWhere(
                  (t) => t.orderId == task.orderId,
                );

                if (originalTaskIndex != -1)
                  _tasks[originalTaskIndex].logisticsStatus = result;
                if (filteredTaskIndex != -1)
                  _filteredTasks[filteredTaskIndex].logisticsStatus =
                      result; // Mettre à jour aussi la liste filtrée directement

                _applyFiltersAndSort(); // Réappliquer le tri au cas où le statut change l'ordre
              });
            } else {
              // Si l'utilisateur revient en arrière sans changer le statut, rafraîchir au cas où
              _fetchDeliveryTasks();
            }
          },
        );
      },
    );
  }
}

class DeliveryTaskListItem extends StatelessWidget {
  final DeliveryTask task;
  final VoidCallback onTap;
  const DeliveryTaskListItem({
    super.key,
    required this.task,
    required this.onTap,
  });
  DeliveryStatus _getStatusDetails(String status) =>
      statusConfig[status] ?? statusConfig['Nouveau']!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusDetails = _getStatusDetails(task.logisticsStatus);
    final statusColor = statusDetails.color;
    return Card(
      elevation: 1.2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: statusColor.withOpacity(0.1),
        highlightColor: statusColor.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '#${task.orderNumber}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        color: theme.primaryColor.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      statusDetails.icon,
                      size: 15,
                      color: statusColor,
                    ),
                    label: Text(statusDetails.title),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: statusColor.withOpacity(0.1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.customerName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.5),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[650],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryStatus {
  final String title;
  final IconData icon;
  final Color color;
  const DeliveryStatus({
    required this.title,
    required this.icon,
    required this.color,
  });
}

// Map de tous les statuts possibles pour l'affichage ET la sélection
// CORRECTION: Revenir aux statuts simplifiés
final Map<String, DeliveryStatus> statusConfig = {
  'Nouveau': DeliveryStatus(
    title: 'Nouveau',
    icon: Icons.fiber_new_rounded,
    color: Colors.grey.shade500,
  ),
  'En cours de Prép.': DeliveryStatus(
    title: 'En cours de Prép.',
    icon: Icons.inventory_2_outlined,
    color: Colors.blue.shade700,
  ),
  'En cours de livraison': DeliveryStatus(
    title: 'En cours de livraison',
    icon: Icons.local_shipping_outlined,
    color: Colors.orange.shade700,
  ),
  // Garder les anciens pour l'affichage si besoin, mais ils ne sont pas sélectionnables
  'Prêt pour livraison': DeliveryStatus(
    title: 'Prêt pour livraison',
    icon: Icons.inventory_outlined,
    color: Colors.cyan.shade700,
  ),
  'Livré': DeliveryStatus(
    title: 'Livré',
    icon: Icons.check_circle_outline_rounded,
    color: Colors.green.shade700,
  ),
  'Reporté': DeliveryStatus(
    title: 'Reporté',
    icon: Icons.history_rounded,
    color: Colors.brown.shade500,
  ),
  'Problème de livraison': DeliveryStatus(
    title: 'Problème de livraison',
    icon: Icons.error_outline_rounded,
    color: Colors.red.shade600,
  ),
};

// Liste des statuts que le livreur peut sélectionner
// CORRECTION: Revenir à la liste simplifiée
final List<DeliveryStatus> selectableLogisticsStatuses = [
  statusConfig['En cours de Prép.']!,
  statusConfig['En cours de livraison']!,
];

class DeliveryDetailPage extends StatefulWidget {
  final DeliveryTask task;
  final String token;
  const DeliveryDetailPage({
    super.key,
    required this.task,
    required this.token,
  });
  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  late String _currentStatus;
  bool _isUpdating = false;
  @override
  void initState() {
    super.initState();
    _currentStatus = statusConfig.containsKey(widget.task.logisticsStatus)
        ? widget.task.logisticsStatus
        : 'Nouveau';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lancer $url'),
            backgroundColor: Colors.red,
          ),
        );
  }

  Future<void> _updateTaskStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final response = await http.put(
        Uri.parse(
          '$API_BASE_URL/api/logistics/orders/${widget.task.orderId}/status',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({'status': newStatus}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut mis à jour !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(newStatus);
      } else if (mounted) {
        final eb = json.decode(response.body);
        throw Exception('Échec màj: ${eb['error'] ?? response.reasonPhrase}');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.task.orderNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 32.0),
        children: [
          _buildStatusHeader(context),
          const SizedBox(height: 18),
          InfoCard(
            title: 'Client',
            icon: Icons.person_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.customerName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.task.address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          InfoCard(
            title: 'Détails Commande',
            icon: Icons.motorcycle_rounded,
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: "Produit",
                  value: widget.task.product,
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: "NIN",
                  value: widget.task.nin,
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: "Châssis",
                  value: widget.task.chassis,
                ),
              ],
            ),
          ),
          InfoCard(
            title: 'Contact',
            icon: Icons.contact_phone_outlined,
            child: Column(
              children: [
                ActionableInfoRow(
                  icon: Icons.phone_outlined,
                  text: widget.task.phone,
                  onActionPressed: () => _launchUrl('tel:${widget.task.phone}'),
                  actionIcon: Icons.call_rounded,
                  tooltip: "Appeler",
                ),
                const Divider(height: 8, thickness: 0.5),
                ActionableInfoRow(
                  icon: Icons.email_outlined,
                  text: widget.task.email,
                  onActionPressed: () =>
                      _launchUrl('mailto:${widget.task.email}'),
                  actionIcon: Icons.send_rounded,
                  tooltip: "Envoyer E-mail",
                ),
              ],
            ),
          ),
          InfoCard(
            title: 'Changer le Statut',
            icon: Icons.sync_alt_rounded,
            child: _isUpdating
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildStatusSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    final status = statusConfig[_currentStatus] ?? statusConfig['Nouveau']!;
    return Card(
      color: status.color,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(status.icon, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                status.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Container(
      height: 105,
      alignment: Alignment.center,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        itemCount: selectableLogisticsStatuses.length,
        separatorBuilder: (c, i) => const SizedBox(width: 18),
        itemBuilder: (c, i) {
          final status = selectableLogisticsStatuses[i];
          final isSelected = _currentStatus == status.title;
          return StatusChip(
            status: status,
            isSelected: isSelected,
            onTap: () {
              if (!isSelected && !_isUpdating) _updateTaskStatus(status.title);
            },
          );
        },
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final DeliveryStatus status;
  final bool isSelected;
  final VoidCallback onTap;
  const StatusChip({
    super.key,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: status.color.withOpacity(0.2),
      highlightColor: status.color.withOpacity(0.1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 115,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? status.color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status.color.withOpacity(isSelected ? 1.0 : 0.6),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: status.color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status.icon,
              color: isSelected ? Colors.white : status.color,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              status.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : status.color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ), // Police légèrement réduite
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5, color: Colors.black12),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 18),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionableInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final IconData actionIcon;
  final VoidCallback onActionPressed;
  final String? tooltip;
  const ActionableInfoRow({
    super.key,
    required this.icon,
    required this.text,
    required this.actionIcon,
    required this.onActionPressed,
    this.tooltip,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 15.5),
            ),
          ),
          Tooltip(
            message: tooltip ?? "",
            child: IconButton(
              icon: Icon(
                actionIcon,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
              onPressed: onActionPressed,
              visualDensity: VisualDensity.compact,
              splashRadius: 24,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper pour ListEquality (utilisé dans fetchDeliveryTasks)
class ListEquality {
  bool equals(List? list1, List? list2) {
    if (identical(list1, list2)) return true;
    if (list1 == null || list2 == null) return false;
    final length = list1.length;
    if (length != list2.length) return false;
    for (var i = 0; i < length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}
