import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'hub_detail_screen.dart';
import 'hub_list_screen.dart';
import 'profile_screen.dart';
import 'wiki_screen.dart';
import 'login_screen.dart';

class CommunityHomeScreen extends StatefulWidget{
  const CommunityHomeScreen({super.key});
  @override State<CommunityHomeScreen> createState()=>_CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen>{
  final api=ApiClient();
  int index=0;
  List<dynamic> hubs=[],rooms=[];
  Map<String,dynamic>? profile;
  bool loading=true;

  bool get ar=>Localizations.localeOf(context).languageCode=='ar';
  String t(String a,String e)=>ar?a:e;

  @override void initState(){super.initState();load();}
  Future<void> load() async{
    try{
      final r=await Future.wait([api.getHubs(),api.getChatRooms(),api.me()]);
      if(mounted)setState(()=>{hubs=r[0] as List<dynamic>,rooms=r[1] as List<dynamic>,profile=r[2] as Map<String,dynamic>,loading=false});
    }catch(_){if(mounted)setState(()=>loading=false);}
  }

  Hub? get hub{
    if(hubs.isEmpty)return null;
    final h=Map<String,dynamic>.from(hubs.first);
    return Hub(id:h['id'],name:h['name']??'',description:h['description']??'',coverImageUrl:h['cover_image_url']??'',memberCount:h['member_count']??0);
  }

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final current=hub;
    return Scaffold(
      appBar:AppBar(title:Text(t('اتحاد طلبة كلية القانون','Law Faculty Student Union'))),
      drawer:Drawer(child:SafeArea(child:ListView(children:[
        UserAccountsDrawerHeader(
          decoration:const BoxDecoration(color:AppColors.surface),
          accountName:Text(profile?['display_name']??''),
          accountEmail:Text('@'+(profile?['username']??'')),
          currentAccountPicture:CircleAvatar(backgroundColor:AppColors.primaryPurple,child:Text(
            ((profile?['display_name']??'?').toString().isEmpty?'?':(profile?['display_name']??'?').toString().substring(0,1)).toUpperCase())),
        ),
        ListTile(leading:const Icon(Icons.person),title:Text(t('الملف الشخصي','Profile')),onTap:(){Navigator.pop(context);Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProfileScreen()));}),
        ListTile(leading:const Icon(Icons.groups),title:Text(t('المجتمعات','Communities')),onTap:(){Navigator.pop(context);setState(()=>index=0);}),
        ListTile(leading:const Icon(Icons.menu_book),title:Text(t('الويكي','Wiki')),onTap:(){Navigator.pop(context);if(current!=null)Navigator.push(context,MaterialPageRoute(builder:(_)=>WikiScreen(hubId:current.id)));}),
        ListTile(leading:const Icon(Icons.chat),title:Text(t('المحادثات','Chats')),onTap:(){Navigator.pop(context);setState(()=>index=2);}),
        ListTile(leading:const Icon(Icons.emoji_events),title:Text(t('النقاط والشارات','Gamification')),onTap:(){Navigator.pop(context);Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProfileScreen()));}),
        if(profile?['role']=='agent'||profile?['role']=='admin')
          ListTile(leading:const Icon(Icons.shield),title:Text(t('الإشراف','Moderation')),onTap:(){Navigator.pop(context);_moderation();}),
        const Divider(),
        ListTile(leading:const Icon(Icons.logout),title:Text(t('تسجيل الخروج','Sign out')),onTap:()async{await api.logout();if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const LoginScreen()),(_)=>false);}),
      ]))),
      body:IndexedStack(index:index,children:[
        current==null?const HubListScreen():HubDetailScreen(hub:current),
        current==null?Center(child:Text(t('لا يوجد مجتمع','No community'))):WikiScreen(hubId:current.id),
        _chatList(),
      ]),
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:[
        NavigationDestination(icon:const Icon(Icons.dynamic_feed_outlined),selectedIcon:const Icon(Icons.dynamic_feed),label:t('الخلاصة','Feed')),
        NavigationDestination(icon:const Icon(Icons.menu_book_outlined),selectedIcon:const Icon(Icons.menu_book),label:t('ويكي','Wiki')),
        NavigationDestination(icon:const Icon(Icons.chat_bubble_outline),selectedIcon:const Icon(Icons.chat_bubble),label:t('الدردشة','Chat')),
      ]),
    );
  }

  Widget _chatList(){
    if(rooms.isEmpty)return Center(child:ElevatedButton.icon(onPressed:_createRoom,icon:const Icon(Icons.add_comment),label:Text(t('إنشاء غرفة دردشة','Create chat room'))));
    return ListView.separated(padding:const EdgeInsets.all(12),itemCount:rooms.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){
      final room=Map<String,dynamic>.from(rooms[i]);
      return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.chat)),title:Text(room['name']??t('محادثة','Chat')),subtitle:Text((room['participant_count']??0).toString()),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(room:room)))));
    });
  }

  Future<void> _createRoom()async{
    final name=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:Text(t('غرفة جديدة','New room')),
      content:TextField(controller:name,decoration:InputDecoration(hintText:t('اسم الغرفة','Room name'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(t('إلغاء','Cancel'))),ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:Text(t('إنشاء','Create')))],
    ));
    if(ok!=true||name.text.trim().isEmpty)return;
    final room=await api.createChatRoom(hubId:hub?.id,name:name.text.trim());
    if(mounted){setState(()=>rooms=[...rooms,room]);Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(room:room)));}
  }

  void _moderation(){
    showDialog(context:context,builder:(_)=>AlertDialog(title:Text(t('الإشراف','Moderation')),content:Text(
      t('للوكيل صلاحية إدارة الأعضاء وترقيتهم ومنح صلاحيات الإدارة. لوحة الإشراف التفصيلية ستستخدم واجهات RBAC في الخادم.','Agents can manage members, promote administrators and grant permissions through the RBAC API.'),
    )));
  }
}
