import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_background/flutter_background.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Reply',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const MyHomePage(title: 'AI Reply'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebViewController controller;
  final androidConfig = const FlutterBackgroundAndroidConfig(
    notificationTitle: "AI Reply",
    notificationText:
        "Background notification for keeping the example app running in the background",
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon:
        AndroidResource(name: 'background_icon', defType: 'drawable'),
  );
  late bool bgPermsInitsuccess;

  void startBgService() async {
    bgPermsInitsuccess =
        await FlutterBackground.initialize(androidConfig: androidConfig);
    bool success = await FlutterBackground.enableBackgroundExecution();
  }

  bool serverRunning = false;
  bool inReqProcess = false;

  void startServer(BuildContext context) async {
    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 6969);
    serverRunning = true;

    await for (var request in server) {
      try {
        if (!inReqProcess) {
          inReqProcess = true;
          Map req = json.decode(await utf8.decodeStream(request));
          if (!req.containsKey("senderMessage")) {
            throw ArgumentError();
          }
          String msg = req["senderMessage"];
          if (msg.toLowerCase().startsWith("gpt, ") &&
              msg
                  .substring(msg.indexOf(',') + 1, msg.length)
                  .trim()
                  .isNotEmpty) {
            msg = msg.substring(msg.indexOf(',') + 1, msg.length).trim();
            msg = json.encode(msg);
            controller.runJavascript(
                "document.getElementsByClassName('w-full resize-none focus:ring-0 focus-visible:ring-0 p-0 pr-7 m-0 border-0 bg-transparent dark:bg-transparent')[0].value = $msg");
            controller.runJavascript(
                "document.getElementsByClassName('absolute p-1 rounded-md text-gray-500 bottom-1.5 right-1 md:bottom-2.5 md:right-2 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent')[0].click()");
            while (true) {
              var str = await controller.runJavascriptReturningResult(
                  "document.querySelector('.result-streaming')");
              if (str == "null") break;
              await Future.delayed(const Duration(milliseconds: 100));
            }
            String reply = await controller.runJavascriptReturningResult(
                'document.querySelectorAll(".flex.flex-col.items-center > div")[document.querySelectorAll(".flex.flex-col.items-center > div").length - 2].innerText');
            request.response
              ..headers.contentType =
                  ContentType("application", "json", charset: "utf-8")
              ..write(json.encode({
                "data": [
                  {"message": json.decode(reply)}
                ]
              }))
              ..close();
          } else {
            request.response
              ..headers.contentType =
                  ContentType("application", "json", charset: "utf-8")
              ..write(json.encode({"data": []}))
              ..close();
          }
          inReqProcess = false;
        } else {
          request.response
            ..headers.contentType =
                ContentType("application", "json", charset: "utf-8")
            ..write(json.encode({
              "data": [
                {"message": "Hold on! I'm already answering!"}
              ]
            }))
            ..close();
        }
      } catch (e) {
        try {
          rethrow;
        } on JsonUnsupportedObjectError {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error decoding request!")));
        } on ArgumentError {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Invalid response!")));
        }
        request.response.statusCode = 400;
        request.response.close();
        inReqProcess = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    startBgService();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        showDialog(
            context: context,
            builder: (context) => const AlertDialog(
                  title: Text("How to use"),
                  content: Text(
                      "1.Login\n2.Set website to dark mode\n3.Click the button to start the automation\n"),
                ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WebView(
        initialUrl: "https://chat.openai.com/chat",
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: ((controller) {
          this.controller = controller;
        }),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(
          Icons.start,
          size: 32,
        ),
        onPressed: () async {
          if (serverRunning) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Server is already running!")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Server has started.")));
            startServer(context);
          }
        },
      ),
    );
  }
}
