
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
     //Uri.parse('ws://192.168.1.16:81'), //hotspot computer scuola
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
  setupLogging(); //inizializza il logger
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
        backgroundColor: const Color(0xff181f2a),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 39, 37, 37),
          leadingWidth: 20,
          toolbarHeight: 40,
            title: const Text(
              'I/O LOCK ||||||||| S 34ms',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
          ),//piu avanti metti un vero contatre di connessione 
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
    // ignore: sized_box_for_whitespace
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        alignment: Alignment.center,
        width: 450,
        color: Color(0xff2f4e63),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: Button(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const JoystickExample()),
                    );
                  }, 
                label: 'Joystick',
              ),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 300,
              height: 300,
              child: Button(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const JoystickAreaExample()),
                  );
                },
                label: 'Drone',
                child: Image.asset(
                'images/GUI_drone.png',
                fit: BoxFit.cover,
          ),
              ),
            ),
            SizedBox(height: 40),
            //non lo tolgo nel caso voglio personalizzare
            SizedBox(
              width: 300,
              height: 150,
              child: Button(
                
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const JoystickCustomizationExample()),
                  );
                },
                
                label: 'Customization',
              ),
            ),
          ],
        ),       
      ),
    );
  }
}

class JoystickExample extends StatefulWidget {
  const JoystickExample({super.key});

  @override
  State<JoystickExample> createState() => _JoystickExampleState();
}

class _JoystickExampleState extends State<JoystickExample> {//----------------------------------------

  final JoystickMode _joystickMode = JoystickMode.all;
  

  @override
  void initState() {
  super.initState();
  connectWebSocket();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Color(0x00181f2a),
      appBar: AppBar(
        title: const Text('Joystick'),
        actions: [

        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, 0.8),
              child: Joystick(//--------------------------------------------------------------------
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
                includeInitialAnimation: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

 //non lo tolgo nel caso voglio personalizzare
class JoystickCustomizationExample extends StatefulWidget {
  const JoystickCustomizationExample({super.key});

  @override
  State<JoystickCustomizationExample> createState() =>
    _JoystickCustomizationExampleState();
}

//questo nell a customizzazione che rimuoverò
class _JoystickCustomizationExampleState
    extends State<JoystickCustomizationExample> {

  final JoystickMode _joystickMode = JoystickMode.all;
  
  bool includeInitialAnimation = false;
  bool enableArrowAnimation = false;
  bool isBlueJoystick = false;

  Key key = UniqueKey();



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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Customization'),
        actions: [

        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
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

  final JoystickMode _joystickMode = JoystickMode.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Joystick Area'),
        actions: [

        ],
      ),
      body: SafeArea(
        child: JoystickArea(
          mode: _joystickMode,
          initialJoystickAlignment: const Alignment(0, 0.8),
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
          child: Stack(
            children: [
            ],
          ),
        ),
      ),
    );
  }
}


class Button extends StatelessWidget {
  final String label;// questi sono gli attributi
  final VoidCallback? onPressed;
  final Widget? child;

  const Button({super.key, required this.label, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          backgroundColor: Color(0x0004288d)
        ),
        child:child ?? Text( // vuoldire child (ovvero l'immagino) o il testo
          label,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        )
      );
  }
}
/*

child: Image.asset(
          'images/GUI_drone.png',
          fit: BoxFit.cover,
          /*
          label,
          style: TextStyle(
            color: Colors.white,
            */
          ),

          */