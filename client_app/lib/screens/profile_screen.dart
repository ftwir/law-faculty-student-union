import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final api = ApiClient();
  final name = TextEditingController();
  final bio = TextEditingController();
  final year = TextEditingController();
  Map<String,dynamic>? profile;
  List<dynamic> badges = [];
  bool loading = true, saving = false;

  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String a,String e) => ar ? a : e;

  @override void initState(){ super.initState(); load(); }

  Future<void> load() async {
    try {
      final p = await api.me();
      final b = await api.getBadges();
      name.text=p['display_name']??'';
      bio.text=p['bio']??'';
      year.text=p['academic_year']??'';
      if(mounted)setState((){profile=p;badges=b;loading=false;});
    } catch(_){if(mounted)setState(()=>loading=false);}
  }

  Future<void> save() async {
    setState(()=>saving=true);
    try{
      final p=await api.updateProfile({'display_name':name.text.trim(),'bio':bio.text.trim(),'academic_year':year.text.trim()});
      if(mounted){setState((){profile=p;saving=false;});ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('تم الحفظ','Saved'))));}
    }catch(e){if(mounted){setState(()=>saving=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  }

  @override void dispose(){name.dispose();bio.dispose();year.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar:AppBar(title:Text(t('ملفي الشخصي','My Profile'))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        CircleAvatar(radius:42,backgroundColor:AppColors.primaryPurple,child:Text(
          name.text.isEmpty?'?':name.text.substring(0,1).toUpperCase(),style:const TextStyle(fontSize:30))),
        const SizedBox(height:8),
        Center(child:Text('@'+(profile?['username']??''),style:const TextStyle(color:AppColors.textSecondary))),
        const SizedBox(height:16),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
          _stat(Icons.star,(profile?['points']??0).toString(),t('نقاط','Points')),
          _stat(Icons.workspace_premium,(profile?['level']??1).toString(),t('مستوى','Level')),
          _stat(Icons.shield_outlined,(profile?['role']??'').toString().toUpperCase(),t('الدور','Role')),
        ]))),
        const SizedBox(height:16),
        TextField(controller:name,decoration:InputDecoration(labelText:t('الاسم','Display name'))),
        const SizedBox(height:10),
        TextField(controller:bio,minLines:3,maxLines:5,decoration:InputDecoration(labelText:t('نبذة','Bio'))),
        const SizedBox(height:10),
        TextField(controller:year,decoration:InputDecoration(labelText:t('السنة الدراسية','Academic year'))),
        const SizedBox(height:14),
        ElevatedButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?t('جار الحفظ','Saving'):t('حفظ','Save'))),
        const SizedBox(height:20),
        Text(t('الشارات','Badges'),style:Theme.of(context).textTheme.titleLarge),
        ...badges.map((b)=>Card(child:ListTile(leading:const Icon(Icons.emoji_events,color:AppColors.neonViolet),title:Text(b['badge_name']??''),subtitle:Text(b['awarded_at']??'')))),
      ]),
    );
  }

  Widget _stat(IconData i,String v,String l)=>Column(children:[Icon(i,color:AppColors.neonViolet),Text(v,style:const TextStyle(fontWeight:FontWeight.bold)),Text(l,style:const TextStyle(fontSize:12,color:AppColors.textSecondary))]);
}
