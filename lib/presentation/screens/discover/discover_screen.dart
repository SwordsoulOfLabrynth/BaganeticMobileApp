import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/travel_place.dart';
import '../../../data/services/travel_place_data_service.dart';
import '../../providers/pagoda_provider.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import 'travel_discovery_screen.dart';

class DiscoverScreen extends StatefulWidget { const DiscoverScreen({super.key,this.travelPlacesFuture}); final Future<List<TravelPlace>>? travelPlacesFuture; @override State<DiscoverScreen> createState()=>_DiscoverScreenState(); }
class _DiscoverScreenState extends State<DiscoverScreen>{
 static const _ivory=Color(0xFFF7F2E9),_ink=Color(0xFF100602),_brown=Color(0xFF2B1D14),_terracotta=Color(0xFFA34A2A);
 late final Future<List<TravelPlace>> _travelPlacesFuture; final _search=TextEditingController(),_focus=FocusNode(); _DiscoverCategory _category=_DiscoverCategory.pagodas; String _query=''; bool _open=false;
 @override void initState(){super.initState();_travelPlacesFuture=widget.travelPlacesFuture??const TravelPlaceDataService().loadPlaces();}
 @override void dispose(){_search.dispose();_focus.dispose();super.dispose();}
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_ivory,body:SafeArea(bottom:false,child:Column(children:[_Header(controller:_search,focus:_focus,open:_open,category:_category,onOpen:(){setState(()=>_open=true);WidgetsBinding.instance.addPostFrameCallback((_)=>_focus.requestFocus());},onClose:(){_search.clear();_focus.unfocus();setState((){_query='';_open=false;});},onChanged:(v)=>setState(()=>_query=v.trim())),_CategoryBar(selected:_category,onSelected:(v)=>setState(()=>_category=v)),const SizedBox(height:12),Expanded(child:FutureBuilder<List<TravelPlace>>(future:_travelPlacesFuture,builder:(c,s)=>Consumer<PagodaProvider>(builder:(c,p,_){if(p.isLoading&&p.allPagodas.isEmpty)return const Center(child:CircularProgressIndicator(color:_terracotta));return _results(p,s.data??const[]);}))) ])));
 Widget _results(PagodaProvider p,List<TravelPlace> all){final places=all.where(_matchPlace).toList()..sort((a,b)=>a.name.compareTo(b.name));final pagodas=p.allPagodas.where(_matchPagoda).toList()..sort((a,b)=>({'ananda':0,'shwesandaw':1,'dhammayangyi':2}[a.id]??99).compareTo(({'ananda':0,'shwesandaw':1,'dhammayangyi':2}[b.id]??99)));return switch(_category){_DiscoverCategory.pagodas=>_pagodaList(pagodas),_DiscoverCategory.stays=>_placeList(places.where((e)=>e.category==TravelPlaceCategory.stay).toList(),'discover.staysSection'),_DiscoverCategory.food=>_placeList(places.where((e)=>e.category==TravelPlaceCategory.food).toList(),'discover.foodSection'),_DiscoverCategory.transport=>_placeList(places.where((e)=>e.category==TravelPlaceCategory.transport).toList(),'map.category.transport'),_DiscoverCategory.scenery=>_placeList(places.where((e)=>e.category==TravelPlaceCategory.scenery).toList(),'map.category.scenery')};}
 Widget _pagodaList(List<Pagoda> p)=>ListView.separated(padding:const EdgeInsets.fromLTRB(30,12,30,116),itemCount:p.length+1,separatorBuilder:(_,i)=>i==0?const SizedBox(height:18):const Divider(height:48,color:Color(0x33C19A49)),itemBuilder:(c,i){if(i==0)return _Title(context.l10n.translate('discover.sacredPlaces'),p.length);final x=p[i-1];return JournalPagodaEntry(pagoda:x,reversed:i.isOdd,imageAsset:x.id=='ananda'?'assets/images/stitch/ananda_postcard.jpg':x.id=='shwesandaw'?'assets/images/pagodas/researched/shwesandaw.jpg':null,onOpen:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>PagodaDetailScreen(pagoda:x))),onToggleFavorite:()async{if(await AuthGate.ensureSignedIn(c,featureName:c.l10n.translate('profile.favorites'))&&mounted)await c.read<PagodaProvider>().toggleFavorite(x.id);});});
 Widget _placeList(List<TravelPlace> p,String key)=>ListView.separated(padding:const EdgeInsets.fromLTRB(20,12,20,116),itemCount:p.length+1,separatorBuilder:(_,i)=>SizedBox(height:i==0?16:12),itemBuilder:(c,i){if(i==0)return _Title(c.l10n.translate(key),p.length,10);final x=p[i-1];return TravelPlaceCard(place:x,onOpen:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>TravelPlaceDetailScreen(place:x))));});
 bool _matchPagoda(Pagoda p)=>_query.isEmpty||[p.name,p.nameMyanmar??'',p.description].any((x)=>x.toLowerCase().contains(_query.toLowerCase())); bool _matchPlace(TravelPlace p)=>_query.isEmpty||[p.name,p.nameMyanmar,p.area,p.summary,p.summaryMyanmar,...p.highlights,...p.highlightsMyanmar].any((x)=>x.toLowerCase().contains(_query.toLowerCase()));
}
class _Header extends StatelessWidget{const _Header({required this.controller,required this.focus,required this.open,required this.category,required this.onOpen,required this.onClose,required this.onChanged});final TextEditingController controller;final FocusNode focus;final bool open;final _DiscoverCategory category;final VoidCallback onOpen,onClose;final ValueChanged<String> onChanged;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.fromLTRB(30,24,30,14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(c.l10n.translate('discover.title'),style:Theme.of(c).textTheme.headlineLarge?.copyWith(color:_DiscoverScreenState._ink,fontSize:34,height:1.08))),if(!open)IconButton(onPressed:onOpen,icon:const Icon(Icons.search_rounded),color:_DiscoverScreenState._terracotta,constraints:const BoxConstraints.tightFor(width:48,height:48))]),const SizedBox(height:6),Text(c.l10n.translate('discover.journalSubtitle'),style:Theme.of(c).textTheme.labelMedium?.copyWith(color:_DiscoverScreenState._brown,fontSize:12,letterSpacing:2.1,fontWeight:FontWeight.w700)),if(open)...[const SizedBox(height:16),TextField(controller:controller,focusNode:focus,onChanged:onChanged,decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),suffixIcon:IconButton(onPressed:onClose,icon:const Icon(Icons.close_rounded)),hintText:c.l10n.translate('discover.searchIn',args:{'category':category.label(c)})))] ]));}
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final _DiscoverCategory selected;
  final ValueChanged<_DiscoverCategory> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30),
    child: SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _DiscoverCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final category = _DiscoverCategory.values[index];
          return Semantics(
            button: true,
            selected: category == selected,
            label: category.label(context),
            child: SizedBox(
              width: 104,
              child: Material(
                color: category == selected
                    ? const Color(0xFFA34A2A)
                    : Colors.white.withValues(alpha: .66),
                child: InkWell(
                  onTap: () => onSelected(category),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category.icon,
                        color: category == selected
                            ? Colors.white
                            : const Color(0xFF4E453F),
                        size: 22,
                      ),
                      Text(
                        category.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: category == selected
                                  ? Colors.white
                                  : const Color(0xFF4E453F),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
class _Title extends StatelessWidget{const _Title(this.title,this.count,[this.inset=0]);final String title;final int count;final double inset;@override Widget build(BuildContext c)=>Padding(padding:EdgeInsets.symmetric(horizontal:inset),child:Row(children:[Expanded(child:Text(title,style:Theme.of(c).textTheme.headlineSmall?.copyWith(color:_DiscoverScreenState._ink,fontSize:28))),Text('$count',style:Theme.of(c).textTheme.labelLarge?.copyWith(color:_DiscoverScreenState._terracotta,fontWeight:FontWeight.w800))]));}
enum _DiscoverCategory{pagodas,stays,food,transport,scenery;IconData get icon=>switch(this){pagodas=>Icons.temple_buddhist_outlined,stays=>Icons.bed_outlined,food=>Icons.restaurant_outlined,transport=>Icons.directions_transit_rounded,scenery=>Icons.photo_camera_outlined};String label(BuildContext c)=>c.l10n.translate(switch(this){pagodas=>'map.category.pagodas',stays=>'map.category.stays',food=>'map.category.food',transport=>'map.category.transport',scenery=>'map.category.scenery'});}
