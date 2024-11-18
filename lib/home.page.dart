import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isConnected = true;
  String _languageCode = 'es-US'; // Idioma por defecto en español

  final String _apiKey = 'AIzaSyBfWtG6I6Ko1g1uj171eZevIIfOHhwTIXY';

  // Inicializar Speech to Text y Text to Speech
  stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _loadMessages();
    _initializeTextToSpeech();
  }

  // Inicializar configuración de Text to Speech con idiomas
  void _initializeTextToSpeech() async {
    await _flutterTts.setLanguage(_languageCode); // Configura el idioma predeterminado
    await _flutterTts.setSpeechRate(0.5);
  }

  // Función para escuchar y convertir voz a texto
  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      });
    }
  }

  // Función para detener la escucha de voz
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;

    setState(() {
      _isConnected = isConnected;
    });

    if (!isConnected) {
      _showNoConnectionSnackbar();
    }
  }

  void _showNoConnectionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay conexión a Internet'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Función para guardar los mensajes en SharedPreferences
  Future<void> _saveMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('messages', jsonEncode(_messages));
  }

  // Función para cargar los mensajes de SharedPreferences
  Future<void> _loadMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedMessages = prefs.getString('messages');
    if (savedMessages != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(jsonDecode(savedMessages));
      });
    }
  }

  Future<void> _sendMessage() async {
    String message = _controller.text.trim();

    if (message.isNotEmpty) {
      message = message.replaceAllMapped(RegExp(r'(\S+)'), (match) => '${match[0]} ');

      String timestamp = DateTime.now().toString();

      setState(() {
        _messages.add({
          "sender": "user",
          "message": message,
          "timestamp": timestamp,
        });
        _isLoading = true;
        _controller.clear();
      });

      // Aquí pasamos el historial de mensajes para mantener el contexto
      String botResponse = await _getBotResponse(_messages);

      setState(() {
        _messages.add({
          "sender": "bot",
          "message": botResponse,
          "timestamp": DateTime.now().toString(),
        });
        _isLoading = false;
      });

      _saveMessages();
      // Activar Text to Speech para el mensaje del bot
      _flutterTts.speak(botResponse);
    }
  }

  // Modificado para filtrar errores y solo leer el mensaje
  Future<String> _getBotResponse(List<Map<String, dynamic>> contextMessages) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey');

    // Se prepara el contexto con todos los mensajes previos.
    List<Map<String, dynamic>> parts = contextMessages
        .map((msg) => {"text": msg['message']})
        .toList();

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {"parts": parts},
        ],
      }),
    );

    if (response.statusCode == 200) {
      try {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('candidates') && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text']?.trim() ?? 'No response from bot';
        } else {
          return 'No candidates available in response';
        }
      } catch (e) {
        return 'Error parsing response: $e';
      }
    } else if (response.statusCode == 503) {
      // Si hay un error 503, solo leemos el mensaje de error
      return 'Servicio no disponible, por favor intente más tarde.';
    } else {
      return "Error: ${response.statusCode} ${response.body}";
    }
  }

  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/Gerar-do/frontend-ev.git');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'No se pudo abrir el enlace $url';
    }
  }

  String _removeMarkdownSyntax(String text) {
    return text.replaceAll(RegExp(r'\*\*'), '');
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmación"),
          content: const Text("¿Estás seguro de que deseas eliminar todo el chat?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Eliminar"),
              onPressed: () {
                setState(() {
                  _messages.clear();
                });
                _saveMessages();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Todo el chat ha sido eliminado.")),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Chat Bot',
          style: TextStyle(color: Colors.black54),
        ),
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Universidad Politecnica de Chiapas"),
              accountEmail: const Text("Ing. en Software"),
              currentAccountPicture: CircleAvatar(
                child: ClipOval(
                  child: Image.asset(
                    'asset/img/uplogo.jpg',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              decoration: const BoxDecoration(
                color: Colors.blue,
                image: DecorationImage(
                  image: AssetImage('asset/img/foondoN.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined,
              color:Colors.red,
              ),
              title: const Text("Eliminar historial"),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Gerardo Jafet Toledo Cañaveral, 211228"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code,
              color: Colors.indigo,
              ),
              title: const Text("Ir a mi repositorio"),
              onTap: () {
                Navigator.pop(context);
                _launchGitHub();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUserMessage = _messages[index]['sender'] == 'user';
                String timestamp = _messages[index]['timestamp'];
                String message = _removeMarkdownSyntax(_messages[index]['message']);

                return Align(
                  alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUserMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isUserMessage
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isUserMessage)
                            const CircleAvatar(
                              radius: 16,
                              backgroundImage: AssetImage('asset/img/chat-bot.png'),
                            ),
                          if (!isUserMessage) const SizedBox(width: 5),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                              decoration: BoxDecoration(
                                color: isUserMessage ? Color(0xFFC2FFC2) : Color(0xFFF6EFD8),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              child: Column(
                                crossAxisAlignment: isUserMessage
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: const TextStyle(fontSize: 12.0),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    timestamp,
                                    style: const TextStyle(
                                      fontSize: 10.0,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isUserMessage)
                            const CircleAvatar(
                              radius: 16,
                              backgroundImage: AssetImage('asset/img/user.png'),
                            ),
                        ],
                      ),
                      if (_isLoading && index == _messages.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CupertinoActivityIndicator(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.black),
                    maxLines: null,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: const TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.lightGreen),
                  onPressed: _isConnected ? _sendMessage : null,
                ),
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.blue),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
