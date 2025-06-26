import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ArnetControlApp());
}

class ArnetControlApp extends StatelessWidget {
  const ArnetControlApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CGR Lanester DMX/Art-Net Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ArnetControlHome(),
    );
  }
}

class ArnetControlHome extends StatefulWidget {
  const ArnetControlHome({Key? key}) : super(key: key);

  @override
  State<ArnetControlHome> createState() => _ArnetControlHomeState();
}

class _ArnetControlHomeState extends State<ArnetControlHome> {
  // Network settings
  String _ipAddress = '192.168.4.1';
  int _udpPort = 6454;

  // Connection state
  bool _isConnected = false;
  RawDatagramSocket? _socket;
  Timer? _pingTimer;

  // Debug mode
  bool _debugMode = false;
  List<String> _debugLogs = [];

  // DMX values for both projectors (5 channels each)
  final List<int> _dmxProjector1 = List.filled(5, 0);
  final List<int> _dmxProjector2 = List.filled(5, 0);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadSettings();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // await Permission.internet.request();
      if (Platform.version.compareTo('10') >= 0) {
        // await Permission.accessWifiState.request();
        // await Permission.changeWifiState.request();
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipAddress = prefs.getString('artnet_ip') ?? '192.168.4.1';
      _udpPort = prefs.getInt('artnet_port') ?? 6454;
      _debugMode = prefs.getBool('debug_mode') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('artnet_ip', _ipAddress);
    await prefs.setInt('artnet_port', _udpPort);
    await prefs.setBool('debug_mode', _debugMode);
  }

  void _addDebugLog(String message) {
    if (_debugMode) {
      setState(() {
        _debugLogs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
        if (_debugLogs.length > 100) {
          _debugLogs.removeLast();
        }
      });
    }
  }

  Future<void> _connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setState(() {
        _isConnected = true;
      });

      _addDebugLog('Connecté au nœud ArtNet $_ipAddress:$_udpPort');

      // Start ping timer
      _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendArtPoll();
      });

      // Listen for responses
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _addDebugLog('Reçu: ${datagram.data.length} bytes de ${datagram.address.address}');
            // Check if it's an ArtPollReply
            if (datagram.data.length >= 10) {
              final opCode = (datagram.data[9] << 8) | datagram.data[8];
              if (opCode == 0x2100) {
                _addDebugLog('ArtPollReply reçu - Connexion confirmée');
              }
            }
          }
        }
      });

      // Send initial poll
      _sendArtPoll();

    } catch (e) {
      _addDebugLog('Erreur de connexion: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _disconnect() {
    _pingTimer?.cancel();
    _socket?.close();
    setState(() {
      _isConnected = false;
    });
    _addDebugLog('Déconnecté du nœud ArtNet');
  }

  void _sendArtPoll() {
    if (_socket == null) return;

    try {
      // ArtPoll packet
      final packet = ByteData(14);
      // ID "Art-Net\0"
      packet.setUint8(0, 0x41); // 'A'
      packet.setUint8(1, 0x72); // 'r'
      packet.setUint8(2, 0x74); // 't'
      packet.setUint8(3, 0x2D); // '-'
      packet.setUint8(4, 0x4E); // 'N'
      packet.setUint8(5, 0x65); // 'e'
      packet.setUint8(6, 0x74); // 't'
      packet.setUint8(7, 0x00); // 0
      // OpCode - OpPoll
      packet.setUint16(8, 0x2000, Endian.little);
      // ProtVer
      packet.setUint16(10, 14, Endian.big);
      // TalkToMe
      packet.setUint8(12, 0);
      // Priority
      packet.setUint8(13, 0);

      _socket!.send(packet.buffer.asUint8List(), InternetAddress(_ipAddress), _udpPort);
      _addDebugLog('Paquet ArtPoll envoyé');
    } catch (e) {
      _addDebugLog('Erreur envoi ArtPoll: $e');
    }
  }

  void _sendArtDmx() {
    if (_socket == null) return;

    try {
      // Prepare DMX data for universe 0 (512 channels)
      final dmxData = List<int>.filled(512, 0);
      
      // Projector 1: channels 1-5 (DMX channels 0-4)
      for (int i = 0; i < 5; i++) {
        dmxData[i] = _dmxProjector1[i];
      }
      
      // Projector 2: channels 6-10 (DMX channels 5-9)
      for (int i = 0; i < 5; i++) {
        dmxData[i + 5] = _dmxProjector2[i];
      }

      // ArtDmx packet
      final packetSize = 18 + 512; // Header + DMX data
      final packet = ByteData(packetSize);

      // ID "Art-Net\0"
      packet.setUint8(0, 0x41); // 'A'
      packet.setUint8(1, 0x72); // 'r'
      packet.setUint8(2, 0x74); // 't'
      packet.setUint8(3, 0x2D); // '-'
      packet.setUint8(4, 0x4E); // 'N'
      packet.setUint8(5, 0x65); // 'e'
      packet.setUint8(6, 0x74); // 't'
      packet.setUint8(7, 0x00); // 0

      // OpCode - OpDmx
      packet.setUint16(8, 0x5000, Endian.little);

      // ProtVer
      packet.setUint16(10, 14, Endian.big);

      // Sequence (0 for now)
      packet.setUint8(12, 0);

      // Physical
      packet.setUint8(13, 0);

      // Universe (0)
      packet.setUint16(14, 0, Endian.little);

      // Length (512)
      packet.setUint16(16, 512, Endian.big);

      // DMX Data
      for (int i = 0; i < 512; i++) {
        packet.setUint8(18 + i, dmxData[i]);
      }

      _socket!.send(packet.buffer.asUint8List(), InternetAddress(_ipAddress), _udpPort);
      _addDebugLog('ArtDmx envoyé - P1: ${_dmxProjector1.toString()}, P2: ${_dmxProjector2.toString()}');
    } catch (e) {
      _addDebugLog('Erreur envoi ArtDmx: $e');
    }
  }

  void _setMasterControl(String preset) {
    setState(() {
      switch (preset) {
        case 'cold_25':
          _dmxProjector1[0] = 64;   // Ch1: Cold white 25%
          _dmxProjector1[1] = 0;    // Ch2: Warm white 0%
          _dmxProjector1[2] = 0;    // Ch3: Strobe off
          _dmxProjector1[3] = 0;    // Ch4: Programs off
          _dmxProjector1[4] = 255;  // Ch5: Dimmer 100%
          
          _dmxProjector2[0] = 64;
          _dmxProjector2[1] = 0;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'cold_50':
          _dmxProjector1[0] = 128;
          _dmxProjector1[1] = 0;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 128;
          _dmxProjector2[1] = 0;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'cold_75':
          _dmxProjector1[0] = 191;
          _dmxProjector1[1] = 0;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 191;
          _dmxProjector2[1] = 0;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'cold_100':
          _dmxProjector1[0] = 255;
          _dmxProjector1[1] = 0;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 255;
          _dmxProjector2[1] = 0;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'warm_25':
          _dmxProjector1[0] = 0;
          _dmxProjector1[1] = 64;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 0;
          _dmxProjector2[1] = 64;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'warm_50':
          _dmxProjector1[0] = 0;
          _dmxProjector1[1] = 128;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 0;
          _dmxProjector2[1] = 128;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'warm_75':
          _dmxProjector1[0] = 0;
          _dmxProjector1[1] = 191;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 0;
          _dmxProjector2[1] = 191;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'warm_100':
          _dmxProjector1[0] = 0;
          _dmxProjector1[1] = 255;
          _dmxProjector1[2] = 0;
          _dmxProjector1[3] = 0;
          _dmxProjector1[4] = 255;
          
          _dmxProjector2[0] = 0;
          _dmxProjector2[1] = 255;
          _dmxProjector2[2] = 0;
          _dmxProjector2[3] = 0;
          _dmxProjector2[4] = 255;
          break;
        case 'all_off':
          for (int i = 0; i < 5; i++) {
            _dmxProjector1[i] = 0;
            _dmxProjector2[i] = 0;
          }
          break;
      }
    });

    _sendArtDmx();
  }

  void _showSettingsDialog() {
    final ipController = TextEditingController(text: _ipAddress);
    final portController = TextEditingController(text: _udpPort.toString());
    bool tempDebugMode = _debugMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Adresse IP',
                  hintText: '192.168.4.1',
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port UDP',
                  hintText: '6454',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Mode Debug'),
                value: tempDebugMode,
                onChanged: (value) {
                  setDialogState(() {
                    tempDebugMode = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _ipAddress = ipController.text;
                  _udpPort = int.tryParse(portController.text) ?? 6454;
                  _debugMode = tempDebugMode;
                });
                _saveSettings();
                Navigator.pop(context);
                if (_isConnected) {
                  _disconnect();
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _connect();
                  });
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGR Lanester DMX Controller'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connecté à $_ipAddress' : 'Déconnecté',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isConnected ? _disconnect : _connect,
                  child: Text(_isConnected ? 'Déconnecter' : 'Connecter'),
                ),
              ],
            ),
          ),

          // Master controls
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Contrôles Master',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Cold white controls
                  const Text('Blanc Froid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('cold_25') : null,
                        child: const Text('25%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('cold_50') : null,
                        child: const Text('50%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('cold_75') : null,
                        child: const Text('75%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('cold_100') : null,
                        child: const Text('100%'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Warm white controls
                  const Text('Blanc Chaud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('warm_25') : null,
                        child: const Text('25%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('warm_50') : null,
                        child: const Text('50%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('warm_75') : null,
                        child: const Text('75%'),
                      ),
                      ElevatedButton(
                        onPressed: _isConnected ? () => _setMasterControl('warm_100') : null,
                        child: const Text('100%'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // All off button
                  ElevatedButton(
                    onPressed: _isConnected ? () => _setMasterControl('all_off') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('TOUT ÉTEINDRE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 24),

                  // Individual channel controls
                  const Text(
                    'Contrôles Avancés',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Projector 1
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Projecteur 1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildChannelSlider('Ch1: Blanc Froid', _dmxProjector1[0], (value) {
                            setState(() => _dmxProjector1[0] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch2: Blanc Chaud', _dmxProjector1[1], (value) {
                            setState(() => _dmxProjector1[1] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch3: Strobe', _dmxProjector1[2], (value) {
                            setState(() => _dmxProjector1[2] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch4: Programmes', _dmxProjector1[3], (value) {
                            setState(() => _dmxProjector1[3] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch5: Dimmer', _dmxProjector1[4], (value) {
                            setState(() => _dmxProjector1[4] = value.round());
                            _sendArtDmx();
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Projector 2
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Projecteur 2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildChannelSlider('Ch1: Blanc Froid', _dmxProjector2[0], (value) {
                            setState(() => _dmxProjector2[0] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch2: Blanc Chaud', _dmxProjector2[1], (value) {
                            setState(() => _dmxProjector2[1] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch3: Strobe', _dmxProjector2[2], (value) {
                            setState(() => _dmxProjector2[2] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch4: Programmes', _dmxProjector2[3], (value) {
                            setState(() => _dmxProjector2[3] = value.round());
                            _sendArtDmx();
                          }),
                          _buildChannelSlider('Ch5: Dimmer', _dmxProjector2[4], (value) {
                            setState(() => _dmxProjector2[4] = value.round());
                            _sendArtDmx();
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Debug logs
                  if (_debugMode) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Logs de Debug',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ListView.builder(
                        itemCount: _debugLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.0),
                            child: Text(
                              _debugLogs[index],
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _debugLogs.clear();
                        });
                      },
                      child: const Text('Effacer les logs'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSlider(String label, int value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: _isConnected ? onChanged : null,
          ),
        ],
      ),
    );
  }
}