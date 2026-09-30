import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';

class WikiScreen extends StatefulWidget {
  final int hubId;
  const WikiScreen({super.key, required this.hubId});
  @override State<WikiScreen> createState()=>_WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen>{
  final api=ApiClient();
  late Future<List<dynamic>> future;
  bool get ar=>Localizations.localeOf(context).languageCode=='ar';
  String t(String a,String e)=>ar?a:e;

  @override void initState(){super.initState();future=api.getWiki(widget.hubId);}

  Future<void> createPage() async{
    final title=TextEditingController(), body=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:Text(t('صفحة ويكي جديدة','New wiki page')),
      content:SingleChildScrollView(child:Column(children:[
        TextField(controller:title,decoration:InputDecoration(hintText:t('العنوان','Title'))),
        const SizedBox(height:10),
        TextField(controller:body,minLines:5,maxLines:10,decoration:InputDecoration(hintText:t('المحتوى','Content'))),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(t('إلغاء','Cancel'))),
        ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:Text(t('نشر','Publish'))),
      ],
    ));
    if(ok!=true||title.text.trim().isEmpty||body.text.trim().isEmpty)return;
    await api.createWiki(hubId:widget.hubId,title:title.text.trim(),content:body.text.trim());
    if(mounted)setState(()=>future=api.getWiki(widget.hubId));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(t('الويكي','Wiki')),actions:[IconButton(onPressed:createPage,icon:const Icon(Icons.add))]),
    body:FutureBuilder<List<dynamic>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:Text(s.error.toString()));
      final pages=s.data??[];
      if(pages.isEmpty)return Center(child:Text(t('لا توجد صفحات بعد','No wiki pages yet')));
      return ListView.separated(padding:const EdgeInsets.all(12),itemCount:pages.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
        itemBuilder:(_,i){final p=Map<String,dynamic>.from(pages[i]);return Card(child:ListTile(
          leading:const Icon(Icons.menu_book,color:AppColors.neonViolet),
          title:Text(p['title']??''),subtitle:Text((p['summary']??p['content']??'').toString()),
          onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(p['title']??''),content:SingleChildScrollView(child:Text(p['content']??'')))),
        ));});
    }),
  );
}
