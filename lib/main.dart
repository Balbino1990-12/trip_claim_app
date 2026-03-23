import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'pages/login/login_page.dart';
import 'pages/logout/logout_page.dart';
import 'services/network_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Set up error handlers to prevent WebSocket crashes
      FlutterError.onError = (FlutterErrorDetails details) {
        // Ignore WebSocket errors
        if (details.exceptionAsString().contains('WebSocket') ||
            details.exceptionAsString().contains('websocket')) {
          return;
        }
        // Show other errors normally
        FlutterError.presentError(details);
      };

      // Initialize network monitoring
      await NetworkService().initializeNetworkMonitoring();
      runApp(const MyApp());
    },
    (error, stackTrace) {
      // Ignore WebSocket errors silently
      if (error.toString().contains('WebSocket') ||
          error.toString().contains('websocket') ||
          error.toString().contains('Connection') ||
          error.toString().contains('HTTP status')) {
        developer.log(
          'Network error (suppressed): ${error.toString()}',
          name: 'network',
          stackTrace: stackTrace,
        );
        return;
      }
      
      // Log and report other errors
      developer.log(
        'Unhandled error: $error',
        name: 'error',
        stackTrace: stackTrace,
        error: error,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 218, 210, 7),
        ),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      themeMode: ThemeMode.light,
      home: LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _navigateToLogoutPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LogoutPage()),
    );
  }

  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: const Icon(Icons.card_travel),
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _navigateToLogoutPage,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Your content Should be here:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
