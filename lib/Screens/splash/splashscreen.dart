import 'package:flutter/material.dart';
import 'package:production/Screens/Route/RouteScreenforAgent.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:production/variables.dart';
import 'package:production/Screens/Login/loginscreen.dart';
import 'package:production/Screens/Route/RouteScreenfordriver.dart';
import 'package:production/Screens/Route/RouteScreenforincharge.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Database? _database;
  @override
  void initState() {
    super.initState();
    _initializeSplashScreen();
  }

  Future<void> _initializeSplashScreen() async {
    // Wait for 1 second to display splash screen
    await Future.delayed(Duration(seconds: 1));

    try {
      // Get active login data
      final loginData = await _getActiveLoginData();

      if (loginData != null) {
        print('🔍 DEBUG: Login data found');
        print('🔍 DEBUG: VSID: ${loginData['vsid']}');
        print('🔍 DEBUG: Driver: ${loginData['driver']}');
        print('🔍 DEBUG: Manager: ${loginData['manager_name']}');

        // Load stored data into global variables
        _loadStoredDataIntoVariables(loginData);

        // Check vsid and navigate accordingly
        if (loginData['vsid'] == null) {
          // Navigate to login screen if vsid is null
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Loginscreen()),
            );
          }
        } else {
          // vsid exists - decide route based on driver flag
          // dart
// Replace the navigation decision block inside _initializeSplashScreen()
// (the portion after you compute isDriver)

          final dynamic driverFlag = loginData['driver'];
          final dynamic agentFlag = loginData['isAgentt'];

          bool isDriver = false;
          if (driverFlag is int && driverFlag == 1) {
            isDriver = true;
            print('🔍 DEBUG: Driver flag matched as int 1');
          }
          if (driverFlag is bool && driverFlag == true) {
            isDriver = true;
            print('🔍 DEBUG: Driver flag matched as bool true');
          }
          if (driverFlag is String &&
              (driverFlag == '1' || driverFlag.toLowerCase() == 'true')) {
            isDriver = true;
            print('🔍 DEBUG: Driver flag matched as string');
          }

          bool isAgent = false;
          if (agentFlag is int && agentFlag == 1) {
            isAgent = true;
            print('🔍 DEBUG: Agent flag matched as int 1');
          }
          if (agentFlag is bool && agentFlag == true) {
            isAgent = true;
            print('🔍 DEBUG: Agent flag matched as bool true');
          }
          if (agentFlag is String &&
              (agentFlag == '1' || agentFlag.toLowerCase() == 'true')) {
            isAgent = true;
            print('🔍 DEBUG: Agent flag matched as string');
          }

          print('🔍 DEBUG: Final isDriver=$isDriver, isAgent=$isAgent');

          if (mounted) {
            if (isDriver) {
              print('🚗 DEBUG: Navigating to Routescreenfordriver');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Routescreenfordriver()),
              );
            } else if (isAgent) {
              print('👔 DEBUG: Navigating to RoutescreenforAgent');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RoutescreenforAgent()),
              );
            } else {
              print('👔 DEBUG: Navigating to RoutescreenforIncharge');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RoutescreenforIncharge()),
              );
            }
          }

        }
      } else {
        // No login data found, navigate to login screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Loginscreen()),
          );
        }
      }
    } catch (e) {
      print('Error during splash initialization: $e');
      // On error, navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Loginscreen()),
        );
      }
    }
  }

  // Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database connection (NO TABLE CREATION - connects to existing DB)
  Future<Database> _initDatabase() async {
    String dbPath = path.join(await getDatabasesPath(), 'production_login.db');
    return await openDatabase(
      dbPath,
      version: 1,
      // REMOVED: onCreate callback since table is created by login screen
      // This just connects to existing database
    );
  }

  // Get any login data from SQLite (check if table has any records)
  Future<Map<String, dynamic>?> _getActiveLoginData() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'login_data',
        orderBy: 'id ASC', // Get first user (matches login screen logic)
        limit: 1,
      );

      if (maps.isNotEmpty) {
        print(
            '📊 Login data found: ${maps.first['manager_name']} (${maps.first['mobile_number']})');
        return maps.first;
      }
      print('🔍 No login data found in table');
      return null;
    } catch (e) {
      print('Error getting login data: $e');
      return null;
    }
  }

  // Load stored data into global variables
  void _loadStoredDataIntoVariables(Map<String, dynamic> loginData) {
    managerName = loginData['manager_name'];
    registeredMovie = loginData['registered_movie'];
    projectId = loginData['project_id'];
    productionTypeId = loginData['production_type_id'] ?? 0;
    productionHouse = loginData['production_house']??' ';
    vmid = loginData['vmid']??0;

    // Convert driver field from int to bool (database stores as int, variable expects bool)
    final driverValue = loginData['driver'];
    final agentValue = loginData['isAgentt'];
    if (driverValue is int) {
      driver = driverValue == 1;
    } else if (driverValue is bool) {
      driver = driverValue;
    } else {
      driver = false; // default to false if null or other type
    }

    // Set mobile number and password in controllers
    loginmobilenumber.text = loginData['mobile_number'] ?? '';
    loginpassword.text = loginData['password'] ?? '';

    print('Loaded stored data: Manager=$managerName, Movie=$registeredMovie');
    print(
        '🔍 DEBUG: Converted driver value $driverValue (${driverValue.runtimeType}) to bool: $driver');
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2B5682),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          // 'assets/tenkrow.png',
                          // cinefoagent,
                          // cinefodriver,
                          cinefoprimarylogo,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    SizedBox(height: 30),

                    // App Title
                    Text(
                      // 'Cinefo Driver',
                     'Cinefo Agent',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: 50),

                    // Loading indicator and status
                  ],
                ),
              ),
            ),

            // Version info
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'v.4.0.2',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
