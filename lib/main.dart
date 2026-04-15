
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';

/*
final channel = WebSocketChannel.connect(
  Uri.parse('ws://172.20.10.13:81'),
);
*/
late WebSocketChannel channel;

final Logger logger = Logger('JoystickLogger');

void connectWebSocket() {
  try {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.13:81'),
    );

    channel.stream.listen(
      (message) {
        logger.info("Ricevuto: $message");
      },
      onDone: () {
        logger.warning("Connessione chiusa, ritento...");
        reconnect();
      },
      onError: (error) {
        logger.severe("Errore: $error");
        reconnect();
      },
    );
  } catch (e) {
    logger.severe("Connessione fallita: $e");
    reconnect();
  }
}

void reconnect() {
  Future.delayed(Duration(seconds: 2), () {
    connectWebSocket();
  });
}



void setupLogging() {
  Logger.root.level = Level.ALL; // tutto, dai debug agli errori
  Logger.root.onRecord.listen((record) {
    // qui puoi decidere come loggare: console, file, ecc.
    //print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

int lastSent = 0;

void sendJoystick(int x, int y) {
  final now = DateTime.now().millisecondsSinceEpoch;

  if (now - lastSent < 30) return; // ⛔ max 20 comandi/sec

  lastSent = now;

  sendJoystickToArduino(x, y);
}

Future<void> sendJoystickToArduino(int x, int y) async {
  final ipArduino = '172.20.10.13:81'; // IP reale di Arduino
  final url = Uri.parse('http://$ipArduino/?x=$x&y=$y');

  try {
    http.get(url);
  } catch (e) {
    log('Errore invio comandi: $e');
  }
}

void sendJoystickData(WebSocketChannel channel, x, int y) {
  channel.sink.add("$x,$y");
  log("Invio dati: $x,$y");
}

void sendMessageToESP32(WebSocketChannel channel, {int? x, int? y, bool special = false}) {
  if (special) {
    channel.sink.add("channelsing.ad");
  } else if (x != null && y != null) {
    channel.sink.add("$x,$y");
  }
}

int lastX = 127;
int lastY = 127;

void main() {
  setupLogging(); // ✅ inizializza il logger
  runApp(const JoystickExampleApp());
}

const ballSize = 20.0;
const step = 10.0;


class JoystickExampleApp extends StatelessWidget {
  const JoystickExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Joystick Example'),
        ),
        body: const MainPage(),
      ),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Button(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const JoystickExample()),
              );
            },
            label: 'Joystick',
          ),
          Button(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const JoystickAreaExample()),
              );
            },
            label: 'Joystick Area',
          ),
          Button(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SquareJoystickExample()),
              );
            },
            label: 'Square Joystick',
          ),
          Button(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const JoystickCustomizationExample()),
              );
            },
            label: 'Customization',
          ),
        ],
      ),
    );
  }
}

class JoystickExample extends StatefulWidget {
  const JoystickExample({super.key});

  @override
  State<JoystickExample> createState() => _JoystickExampleState();
}

class _JoystickExampleState extends State<JoystickExample> {
  // ignore: unused_field
  double _x = 100;
  // ignore: unused_field, prefer_final_fields
  double _y = 100;
  JoystickMode _joystickMode = JoystickMode.all;
  

  @override
  void initState() {
  super.initState();
  connectWebSocket();
  }

  @override
  void didChangeDependencies() {
    _x = MediaQuery.of(context).size.width / 2 - ballSize / 2;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Joystick'),
        actions: [
          JoystickModeDropdown(
            mode: _joystickMode,
            onChanged: (JoystickMode value) {
              setState(() {
                _joystickMode = value;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            //Ball(_x, _y),
            Align(
              alignment: const Alignment(0, 0.8),
              child: Joystick(
                mode: _joystickMode,

                listener: (details) {

                  int joyX = ((details.x + 1) * 127.5).toInt();
                  int joyY = ((-details.y + 1) * 127.5).toInt();
                  
                  
                  //commenta
                  // invia solo se cambia abbastanza
                  if ((joyX - lastX).abs() > 5 || (joyY - lastY).abs() > 5) {
                    sendJoystickData(channel, joyX, joyY);
                    
                    lastX = joyX;
                    lastY = joyY;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoystickCustomizationExample extends StatefulWidget {
  const JoystickCustomizationExample({super.key});

  @override
  State<JoystickCustomizationExample> createState() =>
      _JoystickCustomizationExampleState();
}

class _JoystickCustomizationExampleState
    extends State<JoystickCustomizationExample> {
  double _x = 100;
  double _y = 100;
  JoystickMode _joystickMode = JoystickMode.all;
  bool drawArrows = true;
  bool includeInitialAnimation = true;
  bool enableArrowAnimation = false;
  bool isBlueJoystick = false;
  bool withOuterCircle = false;
  Key key = UniqueKey();

  @override
  void didChangeDependencies() {
    _x = MediaQuery.of(context).size.width / 2 - ballSize / 2;
    super.didChangeDependencies();
  }

  void _updateDrawArrows() {
    setState(() {
      drawArrows = !drawArrows;
    });
  }

  void _updateInitialAnimation() {
    setState(() {
      includeInitialAnimation = !includeInitialAnimation;
      key = UniqueKey();
    });
  }

  void _updateBlueJoystick() {
    setState(() {
      isBlueJoystick = !isBlueJoystick;
    });
  }

  void _updateArrowAnimation() {
    setState(() {
      enableArrowAnimation = !enableArrowAnimation;
    });
  }

  void _updateBorderCircle() {
    setState(() {
      withOuterCircle = !withOuterCircle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Customization'),
        actions: [
          JoystickModeDropdown(
            mode: _joystickMode,
            onChanged: (JoystickMode value) {
              setState(() {
                _joystickMode = value;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            //Ball(_x, _y),
            Align(
              alignment: const Alignment(0, 0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Joystick(
                    includeInitialAnimation: includeInitialAnimation,
                    key: key,
                    base: JoystickBase(
                      decoration: JoystickBaseDecoration(
                        color: isBlueJoystick
                            ? Colors.lightBlue.shade600
                            : Colors.black,
                        drawArrows: drawArrows,
                        drawOuterCircle: withOuterCircle,
                      ),
                      arrowsDecoration: JoystickArrowsDecoration(
                        color: isBlueJoystick
                            ? Colors.grey.shade200
                            : Colors.grey.shade400,
                        enableAnimation: enableArrowAnimation,
                      ),
                      mode: _joystickMode,
                    ),
                    stick: JoystickStick(
                      decoration: JoystickStickDecoration(
                          color: isBlueJoystick
                              ? Colors.blue.shade600
                              : Colors.blue.shade700),
                    ),
                    mode: _joystickMode,
                    listener: (details) {
                      setState(() {//-----------------------------------------------------------------------
                        _x = _x + step * details.x;
                        _y = _y + step * details.y;
                      });
                    },
                  ),
                  SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Button(
                          label: 'Initial Animation: $includeInitialAnimation',
                          onPressed: _updateInitialAnimation,
                        ),
                        Button(
                          label: 'Draw Arrows: $drawArrows',
                          onPressed: _updateDrawArrows,
                        ),
                        Button(
                          label: 'Draw Outer Circle: $withOuterCircle',
                          onPressed: _updateBorderCircle,
                        ),
                        Button(
                          label:
                              'Joystick Color: ${isBlueJoystick ? 'Blue' : 'Black'}',
                          onPressed: _updateBlueJoystick,
                        ),
                        Button(
                          label: 'Animated Arrows : $enableArrowAnimation',
                          onPressed: _updateArrowAnimation,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoystickAreaExample extends StatefulWidget {
  const JoystickAreaExample({super.key});

  @override
  State<JoystickAreaExample> createState() => _JoystickAreaExampleState();
}

class _JoystickAreaExampleState extends State<JoystickAreaExample> {
  double _x = 100;
  double _y = 100;
  JoystickMode _joystickMode = JoystickMode.all;

  @override
  void didChangeDependencies() {
    _x = MediaQuery.of(context).size.width / 2 - ballSize / 2;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Joystick Area'),
        actions: [
          JoystickModeDropdown(
            mode: _joystickMode,
            onChanged: (JoystickMode value) {
              setState(() {
                _joystickMode = value;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: JoystickArea(
          mode: _joystickMode,
          initialJoystickAlignment: const Alignment(0, 0.8),
          listener: (details) {
            setState(() {
              _x = _x + step * details.x;
              _y = _y + step * details.y;
            });
          },
          child: Stack(
            children: [
              //Ball(_x, _y),
            ],
          ),
        ),
      ),
    );
  }
}

class SquareJoystickExample extends StatefulWidget {
  const SquareJoystickExample({super.key});

  @override
  State<SquareJoystickExample> createState() => _SquareJoystickExampleState();
}

class _SquareJoystickExampleState extends State<SquareJoystickExample> {
  double _x = 100;
  double _y = 100;
  JoystickMode _joystickMode = JoystickMode.all;

  @override
  void didChangeDependencies() {
    _x = MediaQuery.of(context).size.width / 2 - ballSize / 2;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Square Joystick'),
        actions: [
          JoystickModeDropdown(
            mode: _joystickMode,
            onChanged: (JoystickMode value) {
              setState(() {
                _joystickMode = value;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            //Ball(_x, _y),
            Align(
              alignment: const Alignment(0, 0.8),
              child: Joystick(
                mode: _joystickMode,
                base: JoystickSquareBase(
                  mode: _joystickMode,
                ),
                stickOffsetCalculator: const RectangleStickOffsetCalculator(),
                listener: (details) {
                  setState(() {
                    _x = _x + step * details.x;
                    _y = _y + step * details.y;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoystickModeDropdown extends StatelessWidget {
  final JoystickMode mode;
  final ValueChanged<JoystickMode> onChanged;

  const JoystickModeDropdown(
      {super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: FittedBox(
          child: DropdownButton(
            value: mode,
            onChanged: (v) {
              onChanged(v as JoystickMode);
            },
            items: const [
              DropdownMenuItem(
                  value: JoystickMode.all, child: Text('All Directions')),
              DropdownMenuItem(
                  value: JoystickMode.horizontalAndVertical,
                  child: Text('Vertical And Horizontal')),
              DropdownMenuItem(
                  value: JoystickMode.horizontal, child: Text('Horizontal')),
              DropdownMenuItem(
                  value: JoystickMode.vertical, child: Text('Vertical')),
            ],
          ),
        ),
      ),
    );
  }
}

class Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const Button({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class Ball extends StatelessWidget {
  final double x;
  final double y;

  const Ball(this.x, this.y, {super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: ballSize,
        height: ballSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 2,
              blurRadius: 3,
              offset: Offset(0, 3),
            )
          ],
        ),
      ),
    );
  }
}
