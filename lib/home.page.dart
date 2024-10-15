import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart'; // Importa el paquete de conectividad

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isConnected = true; // Variable para verificar conexión a internet

  final String _apiKey = 'AIzaSyBfWtG6I6Ko1g1uj171eZevIIfOHhwTIXY'; // Tu clave de API de Google

  @override
  void initState() {
    super.initState();
    _checkInternetConnection(); // Comprueba la conexión inicial
  }

  // Verificar si hay conexión a internet
  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;

    setState(() {
      _isConnected = isConnected; // Actualiza el estado de la conexión
    });
  }

  Future<void> _sendMessage() async {
    String message = _controller.text.trim();

    if (message.isNotEmpty) {
      setState(() {
        _messages.add({"sender": "user", "message": message});
        _isLoading = true; // Inicia la espera de respuesta
        _controller.clear();
      });

      String botResponse = await _getBotResponse(message);

      setState(() {
        _messages.add({"sender": "bot", "message": botResponse});
        _isLoading = false; // Finaliza la espera
      });
    }
  }

  Future<String> _getBotResponse(String userMessage) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": userMessage,
              }
            ],
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      try {
        Map<String, dynamic> data = jsonDecode(response.body);
        print('Response data: $data'); // Agregado para depuración

        if (data.containsKey('candidates') && data['candidates'].isNotEmpty) {
          String botMessage = data['candidates'][0]['content']['parts'][0]['text']?.trim() ?? 'No response from bot';
          return botMessage;
        } else {
          return 'No candidates available in response';
        }
      } catch (e) {
        return 'Error parsing response: $e';
      }
    } else {
      return "Error: ${response.statusCode} ${response.body}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage('asset/img/uplogo.jpg'),
                backgroundColor: Colors.transparent,
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                'Chat - bot ',
                style: TextStyle(

                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
             ),
            Center(
              child: Text(
                'Gerardo Jafet Toledo Cañaveral - 211228',
                style: TextStyle(

                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),

            Center(
              child: Text(
                'Universidad Politecnica de Chiapas',
                style: TextStyle(
                  color: Colors.white,


                  fontSize: 11,
                ),
              ),
            ),
            Center(
              child: Text(
                'Ing. en Software  9 - B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        toolbarHeight: 210,
      ),
      backgroundColor: CupertinoColors.darkBackgroundGray,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUserMessage = _messages[index]['sender'] == 'user';
                return Align(
                  alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isUserMessage)
                        const CircleAvatar(
                          radius: 16,
                          backgroundImage: AssetImage('asset/img/chat-bot.png'),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: isUserMessage ? Colors.white : Colors.white60,
                            borderRadius: BorderRadius.circular(9.0),
                          ),
                          child: Text(
                            _messages[index]['message']!,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isUserMessage)
                        const CircleAvatar(
                          radius: 16,
                          backgroundImage: AssetImage('asset/img/user.png'),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.white12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _isConnected ? _sendMessage : null, // Desactiva si no hay internet
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
