import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';

class ChatScreen extends StatefulWidget{
  final Map<String,dynamic> room;
  const ChatScreen({super.key,required this.room});
  @override State<ChatScreen> createState()=>_ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  final api=ApiClient(), input=TextEditingController(), scroll=ScrollController();
  final messages=<Map<String,dynamic>>[];
  WebSocketChannel? channel;
  StreamSubscription? sub;
  bool loading=true;

  @override void initState(){super.initState();open();}

  Future<void> open() async{
    try{
      final old=await api.getMessages(widget.room['id']);
      messages.addAll(old.map((e)=>Map<String,dynamic>.from(e)));
      final token=await api.authToken();
      final url='wss://law-union-backend.onrender.com/ws/chat/'+widget.room['id'].toString()+'/?token='+token.toString();
      channel=WebSocketChannel.connect(Uri.parse(url));
      sub=channel!.stream.listen((event){
        final d=Map<String,dynamic>.from(jsonDecode(event.toString()));
        if(mounted){setState(()=>messages.add(d));scrollBottom();}
      },onError:(_){});
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }

  void send(){
    final body=input.text.trim();if(body.isEmpty)return;
    input.clear();
    try{channel?.sink.add(jsonEncode({'message':body}));}catch(_){api.sendMessage(widget.room['id'],body);}
  }

  void scrollBottom(){WidgetsBinding.instance.addPostFrameCallback((_){if(scroll.hasClients)scroll.animateTo(scroll.position.maxScrollExtent,duration:const Duration(milliseconds:180),curve:Curves.easeOut);});}

  @override void dispose(){sub?.cancel();channel?.sink.close();input.dispose();scroll.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final ar=Localizations.localeOf(context).languageCode=='ar';
    return Scaffold(appBar:AppBar(title:Text(widget.room['name']??(ar?'محادثة':'Chat'))),
      body:Column(children:[
        Expanded(child:loading?const Center(child:CircularProgressIndicator()):ListView.builder(controller:scroll,padding:const EdgeInsets.all(12),itemCount:messages.length,
          itemBuilder:(_,i){final m=messages[i];return Card(child:ListTile(title:Text(m['sender_name']??''),subtitle:Text(m['body']??m['message']??'')));})),
        SafeArea(child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
          Expanded(child:TextField(controller:input,minLines:1,maxLines:4,decoration:InputDecoration(hintText:ar?'اكتب رسالة...':'Message...'))),
          IconButton.filled(onPressed:send,icon:const Icon(Icons.send)),
        ]))),
      ]));
  }
}
