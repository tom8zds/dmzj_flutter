import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:common_utils/common_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dmzj/helper/api.dart';
import 'package:flutter_dmzj/helper/config_helper.dart';
import 'package:flutter_dmzj/helper/user_helper.dart';
import 'package:flutter_dmzj/provider/user_info_provider.dart';
import 'package:flutter_dmzj/helper/utils.dart';
import 'package:flutter_dmzj/models/comic/comic_detail_model.dart';
import 'package:flutter_dmzj/models/comic/comic_related_model.dart';
import 'package:flutter_dmzj/database/comic_history.dart';
import 'package:flutter_dmzj/views/download/comic_download.dart';
import 'package:flutter_dmzj/views/other/comment_widget.dart';
import 'package:flutter_dmzj/widgets/collapse_header.dart';
import 'package:flutter_dmzj/widgets/comic_chapter_widget.dart';
import 'package:flutter_dmzj/widgets/error_pages.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

const Map<int, Color> tagColor = {8: Colors.pink, 13: Colors.lightBlue};

class ComicDetailPageV2 extends StatefulWidget {
  final int comicId;
  final String coverUrl;
  final bool isLocal;
  ComicDetailPageV2(this.comicId, this.coverUrl, {Key key, this.isLocal})
      : super(key: key);

  @override
  _ComicDetailPageState createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPageV2>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  TabController _tabController;
  double detailExpandHeight = 150 + kToolbarHeight + 24;
  @override
  bool get wantKeepAlive => true;
  bool _indebug = true;
  String _coverUrl;
  ViewState _state = ViewState.loading;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.coverUrl ?? "";
    loadData();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double getSafebar() {
    return MediaQuery.of(context).padding.top;
  }

  double getWidth() {
    return (MediaQuery.of(context).size.width - 24) / 3 - 32;
  }

  ComicDetail _detail;
  ComicRelated _related;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: RefreshIndicator(
          onRefresh: () async {
            await loadData();
          },
          displacement: 40 + getSafebar(),
          child: createPage()),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: FloatingActionButton(
          heroTag: "comic_float",
          child: Icon(Icons.play_arrow),
          onPressed: () {
            setState(() {
              openRead(Provider.of<ComicHistoryProvider>(context, listen: false)
                  .history);
            });
          }),
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Row(
          children: [
            TextButton(
              child: Text("评论"),
              onPressed: _state == ViewState.fail
                  ? null
                  : () {
                      showCupertinoModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Material(
                              child: CommentWidget(4, widget.comicId),
                            );
                          });
                    },
            ),
            TextButton(
              child: Text("相关"),
              onPressed: _state == ViewState.fail
                  ? null
                  : () {
                      showCupertinoModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Material(
                              child: CustomScrollView(
                                slivers: [
                                  SliverAppBar(
                                    title: Text('相关'),
                                  ),
                                  SliverToBoxAdapter(
                                    child: createRelate(),
                                  )
                                ],
                              ),
                            );
                          });
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget createPage() {
    switch (_state) {
      case ViewState.loading:
        return _detail != null ? idlePage2() : loadingPage(context);
      case ViewState.noCopyright:
        return noCopyrightPage(context);
      case ViewState.fail:
        return failPage(context, loadData);
      case ViewState.idle:
        return idlePage2();
      default:
        return failPage(context, loadData);
    }
  }

  Widget createHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 12,
        ),
        _coverUrl.isNotEmpty
            ? Utils.createCover(_coverUrl, 100, 0.75, context)
            : Container(),
        SizedBox(
          width: 24,
        ),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _detail.title,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              "作者:" + tagsToString(_detail.authors ?? []),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            Text(
              "点击:" + _detail.hot_num.toString(),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            Text(
              "订阅:" + _detail.subscribe_num.toString(),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            Text(
              "状态:" + tagsToString(_detail.status ?? []),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            Text(
              "最后更新:" +
                  DateUtil.formatDate(
                      DateTime.fromMillisecondsSinceEpoch(
                          _detail.last_updatetime * 1000),
                      format: "yyyy-MM-dd"),
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        )),
        SizedBox(
          width: 12,
        ),
      ],
    );
  }

  Widget idlePage2() {
    {
      double height = MediaQuery.of(context).size.shortestSide * 0.56;
      double paddingPerfix = 0.06;
      double safeArea = MediaQuery.of(context).padding.top;
      double padding = height * paddingPerfix;
      Color bgColor = Theme.of(context).accentColor;
      print(_detail.types.toString());
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: height + safeArea + kToolbarHeight,
                child: Stack(children: [
                  Container(
                    height: height + safeArea + kToolbarHeight / 2,
                    padding: EdgeInsets.fromLTRB(padding, padding + safeArea,
                        padding, padding + kToolbarHeight / 2),
                    color: Theme.of(context).accentColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: (height - padding * 2) * 0.75,
                          height: height - padding * 2,
                          padding: EdgeInsets.all(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(
                              image: Utils.createCachedImageProvider(
                                  _detail.cover),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: padding),
                            child: Container(
                              height: height - padding * 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _detail.title,
                                    style: TextStyle(
                                        fontSize: 24, color: Colors.white),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      tagsToString(_detail.authors),
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.white),
                                    ),
                                  ),
                                  Wrap(
                                    children: _detail.types
                                        .map<Widget>((f) =>
                                            createTagItem(f.tag_name, f.tag_id))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: kToolbarHeight,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Card(
                        elevation: 4,
                        child: Row(
                          children: [
                            Expanded(
                                child: Provider.of<AppUserInfoProvider>(context)
                                            .isLogin &&
                                        _isSubscribe
                                    ? FlatButton.icon(
                                        onPressed: () async {
                                          var result =
                                              await UserHelper.comicSubscribe(
                                                  widget.comicId,
                                                  cancel: true);
                                          if (result) {
                                            setState(() {
                                              _isSubscribe = false;
                                            });
                                          }
                                        },
                                        icon: Icon(Icons.favorite),
                                        label: Text('已订阅'))
                                    : FlatButton.icon(
                                        onPressed: () async {
                                          var result =
                                              await UserHelper.comicSubscribe(
                                                  widget.comicId);
                                          if (result) {
                                            setState(() {
                                              _isSubscribe = true;
                                            });
                                          }
                                        },
                                        icon: Icon(Icons.favorite_border),
                                        label: Text('订阅'),
                                        height: kToolbarHeight,
                                      )),
                            Expanded(
                                child: FlatButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.cloud_download),
                              label: Text('下载'),
                              height: kToolbarHeight,
                            )),
                            Expanded(
                                child: FlatButton.icon(
                              highlightColor: Colors.transparent,
                              onPressed: () {
                                Share.share(
                                    "${_detail.title}\r\nhttp://m.dmzj.com/info/${_detail.comic_py}.html");
                              },
                              icon: Icon(Icons.share),
                              label: Text('下载'),
                              height: kToolbarHeight,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${tagsToString(_detail.status)}'),
                        ),
                        Expanded(
                          child: Text(
                            '${_detail.last_update_chapter_name}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text('${_detail.last_update_chapter_name}',
                              textAlign: TextAlign.end),
                        )
                      ],
                    ),
                    SizedBox(
                      height: padding,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text('❤️${_detail.subscribe_num}'),
                        ),
                        Expanded(
                          child: Text(
                              DateUtil.formatDate(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      _detail.last_updatetime * 1000),
                                  format: "yyyy-MM-dd"),
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: padding,
                    ),
                    Divider()
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: ComicChapterView(
                  widget.comicId,
                  _detail,
                  Provider.of<ComicHistoryProvider>(context).history,
                  isSubscribe: _isSubscribe,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget idlePage() {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: ComicHeaderDelegate(
                avatar: null,
                label: InkWell(
                  onTap: () {},
                  child: Text(
                    _detail.title,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                maxHeight: MediaQuery.of(context).size.shortestSide * 0.68,
                minHeight: kToolbarHeight,
                safeOffset: getSafebar(),
                image: Utils.createCachedImageProvider(_detail.cover),
                colorFilterTween: ColorTween(
                    begin: Colors.black.withOpacity(0.32),
                    end: Theme.of(context).accentColor),
                actions: [
                  //屏蔽下载功能
                  _indebug
                      ? IconButton(
                          icon: Icon(Icons.cloud_download, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        ComicDownloadPage(_detail)));
                          })
                      : Container(),
                  Provider.of<AppUserInfoProvider>(context).isLogin &&
                          _isSubscribe
                      ? IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            var result = await UserHelper.comicSubscribe(
                                widget.comicId,
                                cancel: true);
                            if (result) {
                              setState(() {
                                _isSubscribe = false;
                              });
                            }
                          })
                      : IconButton(
                          icon:
                              Icon(Icons.favorite_border, color: Colors.white),
                          onPressed: () async {
                            var result =
                                await UserHelper.comicSubscribe(widget.comicId);
                            if (result) {
                              setState(() {
                                _isSubscribe = true;
                              });
                            }
                          }),
                  IconButton(
                      icon: Icon(Icons.share, color: Colors.white),
                      onPressed: () {
                        Share.share(
                            "${_detail.title}\r\nhttp://m.dmzj.com/info/${_detail.comic_py}.html");
                      }),
                ],
              ),
            ),
          ),
        ];
      },
      body: Builder(builder: (context) {
        return CustomScrollView(
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverList(
                delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text("简介", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      _detail.description,
                      style: TextStyle(color: Colors.grey),
                    ),
                    Container(
                      child: Wrap(
                        children: _detail.types
                            .map<Widget>(
                                (f) => createTagItem(f.tag_name, f.tag_id))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              _detail.copyright == 1
                  ? Column(
                      children: <Widget>[
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: Theme.of(context).cardColor,
                          padding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text("作者公告",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text(
                                _detail.author_notice != null &&
                                        _detail.author_notice != ""
                                    ? _detail.author_notice
                                    : "无",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  : Container(),
              ComicChapterView(
                widget.comicId,
                _detail,
                Provider.of<ComicHistoryProvider>(context).history,
                isSubscribe: _isSubscribe,
              ),
            ]))
          ],
        );
      }),
    );
  }

  Widget createRelate() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          children: _related.author_comics
              .map<Widget>((f) => _getItem(f.author_name + "的其他作品", f.data,
                      icon: Icon(Icons.chevron_right),
                      //ratio: getWidth() / ((getWidth() * (360 / 270)) + 36),
                      ontap: () {
                    Utils.openPage(context, f.author_id, 8);
                  }))
              .toList(),
        ),
        _getItem(
          "同类题材作品",
          _related.theme_comics,
          //ratio: getWidth() / ((getWidth() * (360 / 270)) + 36),
        ),
        _related.novels != null && _related.novels.length != 0
            ? _getItem(
                "相关小说",
                _related.novels,
                type: 2,
                //ratio: getWidth() / ((getWidth() * (360 / 270)) + 36),
              )
            : Container()
      ],
    );
  }

  Widget createTagItem(String text, int id) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ButtonTheme(
        minWidth: 20,
        height: 24,
        child: RaisedButton(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: tagColor[id],
          textColor: Colors.white,
          //borderSide: BorderSide(color: Theme.of(context).accentColor),
          child: Text(
            text,
            style: TextStyle(fontSize: 12),
          ),
          onPressed: () {
            Utils.openPage(context, id, 11, title: text);
          },
        ),
      ),
    );
  }

  void openRead(historyChapter) async {
    if (_state == ViewState.idle ||
        _detail.chapters == null ||
        _detail.chapters.length == 0 ||
        _detail.chapters[0].data.length == 0) {
      Fluttertoast.showToast(msg: '没有可读的章节');
      return;
    }
    if (historyChapter != 0) {
      ComicDetailChapterItem _item;
      ComicDetailChapter chpters;
      for (var item in _detail.chapters) {
        var first = item.data.firstWhere((f) => f.chapter_id == historyChapter,
            orElse: () => null);
        if (first != null) {
          chpters = item;
          _item = first;
        }
      }
      if (_item != null) {
        await Utils.openComicReader(context, widget.comicId, _detail.title,
            _isSubscribe, chpters.data, _item);
        return;
      }
    }
    var _chapters = _detail.chapters[0].data;
    _chapters.sort((x, y) => x.chapter_order.compareTo(y.chapter_order));
    await Utils.openComicReader(context, widget.comicId, _detail.title,
        _isSubscribe, _chapters, _chapters.first);
  }

  Widget _getItem(String title, List items,
      {Icon icon,
      Function ontap,
      bool needSubTitle = true,
      int count = 3,
      int type = 1,
      double ratio = 3 / 5.2,
      double imgWidth = 270,
      double imgHeight = 360}) {
    return Offstage(
        offstage: items == null || items.length == 0,
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: Theme.of(context).cardColor,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _getTitle(title, icon: icon, ontap: ontap),
                  SizedBox(
                    height: 4.0,
                  ),
                  GridView.builder(
                    padding: EdgeInsets.all(4),
                    shrinkWrap: true,
                    physics: ScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                        childAspectRatio: ratio),
                    itemBuilder: (context, i) => Utils.createCoverWidget(
                        items[i].id,
                        type,
                        items[i].cover,
                        items[i].name,
                        context,
                        author: needSubTitle ? items[i].status : "",
                        width: imgWidth,
                        height: imgHeight),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 8.0,
            ),
          ],
        ));
  }

  Widget _getTitle(String title, {Icon icon, Function ontap}) {
    return ListTile(
      title: Text(title),
      trailing: Offstage(
        offstage: icon == null,
        child: Material(
            color: Theme.of(context).cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: ontap,
              child: icon ?? Icon(Icons.refresh),
            )),
      ),
    );
  }

  String tagsToString(List<ComicDetailTagItem> items) {
    var str = "";
    for (var item in items) {
      str += item.tag_name + " ";
    }
    return str;
  }

  bool _isSubscribe = false;
  DefaultCacheManager _cacheManager = DefaultCacheManager();
  Future loadData() async {
    setState(() {
      _state = ViewState.loading;
    });
    Provider.of<ComicHistoryProvider>(context, listen: false)
        .updateHistory(widget.comicId);
    if (widget.isLocal) {
      Future.wait([loadDetail()]).then((value) {
        setState(() {
          _state = value[0];
        });
      });
    } else
      await Future.wait([
        loadDetail(),
        checkSubscribe(),
        loadRelated(),
      ]).then((value) {
        if (value.any((element) => element == ViewState.fail)) {
          setState(() {
            _state = ViewState.idle;
          });
        }
        setState(() {
          _state = value[0];
        });
      }).catchError((e) {
        print(e);
        setState(() {
          _state = ViewState.fail;
        });
      });
  }

  Future<ViewState> loadDetail() async {
    try {
      var jsonMap;
      if (widget.isLocal) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        var _comicMetaPath =
            appDocDir.absolute.path + '/downloads/${widget.comicId}/metadata';
        var _comicMeta = File(_comicMetaPath);
        jsonMap = jsonDecode(_comicMeta.readAsStringSync());
      } else {
        var api = Api.comicDetail(widget.comicId);
        Uint8List responseBody;
        var response = await http.get(Api.comicDetail(widget.comicId));
        responseBody = response.bodyBytes;
        if (response.body == "漫画不存在!!!") {
          var file = await _cacheManager
              .getFileFromCache('http://comic.cache/${widget.comicId}');
          if (file == null) {
            return ViewState.noCopyright;
          }
          responseBody = await file.file.readAsBytes();
        }

        var responseStr = utf8.decode(responseBody);
        jsonMap = jsonDecode(responseStr);
        await _cacheManager.putFile(
            'http://comic.cache/${widget.comicId}', responseBody,
            eTag: api, maxAge: Duration(days: 7), fileExtension: 'json');
      }

      ComicDetail detail = ComicDetail.fromJson(jsonMap);

      if (detail.title == null || detail.title == "") {
        setState(() {
          _state = ViewState.noCopyright;
        });
        return ViewState.noCopyright;
      }

      _coverUrl = detail.cover;
      _detail = detail;
      return ViewState.idle;
    } catch (e) {
      print(e);
      return ViewState.fail;
    }
  }

  Future<ViewState> loadRelated() async {
    try {
      var response = await http.get(Api.comicRelated(widget.comicId));

      var jsonMap = jsonDecode(response.body);

      ComicRelated detail = ComicRelated.fromJson(jsonMap);

      _related = detail;
      return ViewState.idle;
    } catch (e) {
      print(e);
      return ViewState.fail;
    }
  }

  Future<ViewState> checkSubscribe() async {
    try {
      if (!ConfigHelper.getUserIsLogined() ?? false) {
        return ViewState.idle;
      }
      var response = await http.get(Api.comicCheckSubscribe(
          widget.comicId,
          Provider.of<AppUserInfoProvider>(context, listen: false)
              .loginInfo
              .uid));
      var jsonMap = jsonDecode(response.body);

      _isSubscribe = jsonMap["code"] == 0;

      return ViewState.idle;
    } catch (e) {
      print(e);
      return ViewState.fail;
    }
  }
}
