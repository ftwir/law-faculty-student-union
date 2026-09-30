import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  final ImagePicker picker = ImagePicker();
  final AudioRecorder recorder = AudioRecorder();
  bool recording = false;
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

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null) return;
    if (!mounted) return;
    final path = result.files.single.path;
    if (path == null) return;
    try {
      await api.sendAttachment(
        roomId: widget.room['id'],
        filePath: path,
      );
      if (mounted) {
        setState(() {
          messages.add({
            'sender_name': 'أنت',
            'body': '📎 ' + p.basename(path),
            'attachment_name': p.basename(path),
          });
        });
        scrollBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الملف: $e')),
        );
      }
    }
  }

  Future<void> pickPhoto() async {
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (photo == null) return;
    try {
      await api.sendAttachment(
        roomId: widget.room['id'],
        filePath: photo.path,
      );
      if (mounted) {
        setState(() {
          messages.add({
            'sender_name': 'أنت',
            'body': '🖼️ صورة',
            'attachment_name': p.basename(photo.path),
            'attachment_type': 'image',
          });
        });
        scrollBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الصورة: $e')),
        );
      }
    }
  }

  Future<void> toggleRecording() async {
    if (recording) {
      final path = await recorder.stop();
      if (mounted) setState(() => recording = false);
      if (path == null) return;
      try {
        await api.sendAttachment(
          roomId: widget.room['id'],
          filePath: path,
        );
        if (mounted) {
          setState(() {
            messages.add({
              'sender_name': 'أنت',
              'body': '🎤 رسالة صوتية',
              'attachment_name': p.basename(path),
              'attachment_type': 'audio/mp4',
            });
          });
          scrollBottom();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إرسال التسجيل: $e')),
          );
        }
      }
      return;
    }
    if (!await recorder.hasPermission()) return;
    final directory = await getTemporaryDirectory();
    final path = p.join(
      directory.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await recorder.start(const RecordConfig(), path: path);
    if (mounted) setState(() => recording = true);
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
          IconButton(onPressed:pickFile,icon:const Icon(Icons.attach_file)),
          IconButton(onPressed:pickPhoto,icon:const Icon(Icons.photo_outlined)),
          Expanded(child:TextField(controller:input,minLines:1,maxLines:4,decoration:InputDecoration(hintText:'اكتب رسالة...'))),
          IconButton(onPressed:toggleRecording,icon:Icon(recording ? Icons.stop_circle : Icons.mic)),
          IconButton.filled(onPressed:send,icon:const Icon(Icons.send)),
        ]))),
      ]));
  }
}
