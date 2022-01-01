import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jasmine/basic/methods.dart';
import 'package:jasmine/configs/pager_controller_mode.dart';
import 'package:jasmine/configs/pager_view_mode.dart';
import 'package:jasmine/screens/components/content_builder.dart';

import '../comic_info_screen.dart';
import 'images.dart';

class ComicPager extends StatefulWidget {
  final Future<ComicsResponse> Function(int page) onPage;

  const ComicPager({required this.onPage, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ComicPagerState();
}

class _ComicPagerState extends State<ComicPager> {
  @override
  void initState() {
    currentPagerControllerModeEvent.subscribe(_setState);
    super.initState();
  }

  @override
  void dispose() {
    currentPagerControllerModeEvent.unsubscribe(_setState);
    super.dispose();
  }

  _setState(_) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (currentPagerControllerMode) {
      case PagerControllerMode.stream:
        return _StreamPager(onPage: widget.onPage);
      case PagerControllerMode.pager:
        return _PagerPager(onPage: widget.onPage);
    }
  }
}

class _StreamPager extends StatefulWidget {
  final Future<ComicsResponse> Function(int page) onPage;

  const _StreamPager({Key? key, required this.onPage}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _StreamPagerState();
}

class _StreamPagerState extends State<_StreamPager> {
  bool _over = false;
  int _nextPage = 1;

  var _joining = false;
  var _joinSuccess = true;

  Future<List<ComicSimple>> _next() async {
    var response = await widget.onPage(_nextPage);
    _nextPage++;
    _over = response.content.isEmpty;
    return response.content;
  }

  Future _join() async {
    try {
      setState(() {
        _joining = true;
      });
      _data.addAll(await _next());
      setState(() {
        _joinSuccess = true;
        _joining = false;
      });
    } catch (_) {
      setState(() {
        _joinSuccess = false;
        _joining = false;
      });
    }
  }

  final List<ComicSimple> _data = [];
  late ScrollController _controller;

  @override
  void initState() {
    _controller = ScrollController();
    _controller.addListener(_onScroll);
    _join();
    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_joining || _over) {
      return;
    }
    if (_controller.position.pixels + 100 <
        _controller.position.maxScrollExtent) {
      return;
    }
    _join();
  }

  Widget? _buildLoadingCard() {
    if (_joining) {
      return Card(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: const CupertinoActivityIndicator(
                radius: 14,
              ),
            ),
            const Text('加载中'),
          ],
        ),
      );
    }
    if (!_joinSuccess) {
      return Card(
        child: InkWell(
          onTap: () {
            _join();
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: const Icon(Icons.sync_problem_rounded),
              ),
              const Text('出错, 点击重试'),
            ],
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _PagerComicListView(
      controller: _controller,
      data: _data,
      append: _buildLoadingCard(),
    );
  }
}

class _PagerPager extends StatefulWidget {
  final Future<ComicsResponse> Function(int page) onPage;

  const _PagerPager({Key? key, required this.onPage}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PagerPagerState();
}

class _PagerPagerState extends State<_PagerPager> {
  final TextEditingController _textEditController =
      TextEditingController(text: '');
  late int _currentPage = 1;
  late int _maxPage = 1;
  late final List<ComicSimple> _data = [];
  late Future _pageFuture = _load();

  Future<dynamic> _load() async {
    var response = await widget.onPage(_currentPage);
    setState(() {
      if (_currentPage == 1) {
        if (response.total == 0) {
          _maxPage = 1;
        } else {
          _maxPage = (response.total / response.content.length).ceil();
        }
      }
      _data.clear();
      _data.addAll(response.content);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentBuilder(
      future: _pageFuture,
      onRefresh: () async {
        setState(() {
          _pageFuture = _load();
        });
      },
      successBuilder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        return Scaffold(
          appBar: _buildPagerBar(),
          body: _PagerComicListView(
            data: _data,
          ),
        );
      },
    );
  }

  PreferredSize _buildPagerBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: .5,
              style: BorderStyle.solid,
              color: Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                _textEditController.clear();
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: Card(
                        child: TextField(
                          controller: _textEditController,
                          decoration: const InputDecoration(
                            labelText: "请输入页数：",
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        MaterialButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('取消'),
                        ),
                        MaterialButton(
                          onPressed: () {
                            Navigator.pop(context);
                            var text = _textEditController.text;
                            if (text.isEmpty || text.length > 5) {
                              return;
                            }
                            var num = int.parse(text);
                            if (num == 0 || num > _maxPage) {
                              return;
                            }
                            setState(() {
                              _currentPage = num;
                              _pageFuture = _load();
                            });
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Row(
                children: [
                  Text("第 $_currentPage / $_maxPage 页"),
                ],
              ),
            ),
            Row(
              children: [
                MaterialButton(
                  minWidth: 0,
                  onPressed: () {
                    if (_currentPage > 1) {
                      setState(() {
                        _currentPage = _currentPage - 1;
                        _pageFuture = _load();
                      });
                    }
                  },
                  child: const Text('上一页'),
                ),
                MaterialButton(
                  minWidth: 0,
                  onPressed: () {
                    if (_currentPage < _maxPage) {
                      setState(() {
                        _currentPage = _currentPage + 1;
                        _pageFuture = _load();
                      });
                    }
                  },
                  child: const Text('下一页'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PagerComicListView extends StatefulWidget {
  final List<ComicSimple> data;
  final Widget? append;
  final ScrollController? controller;

  const _PagerComicListView(
      {Key? key, required this.data, this.append, this.controller})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _PagerComicListViewState();
}

class _PagerComicListViewState extends State<_PagerComicListView> {
  @override
  void initState() {
    currentPagerViewModeEvent.subscribe(_setState);
    super.initState();
  }

  @override
  void dispose() {
    currentPagerViewModeEvent.unsubscribe(_setState);
    super.dispose();
  }

  _setState(_) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (currentPagerViewMode) {
      case PagerViewMode.cover:
        return _buildCoverMode();
      case PagerViewMode.info:
        return _buildInfoMode();
    }
  }

  Widget _buildCoverMode() {
    List<Widget> widgets = [];
    for (var i = 0; i < widget.data.length; i++) {
      widgets.add(_buildCoverCard(context, widget.data[i]));
    }
    if (widget.append != null) {
      widgets.add(widget.append!);
    }

    return GridView.count(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10.0),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      crossAxisCount: 4,
      childAspectRatio: 3 / 4,
      children: widgets,
    );
  }

  Widget _buildCoverCard(BuildContext context, ComicSimple data) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) {
            return ComicInfoScreen(data);
          },
        ));
      },
      child: Card(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: [
                JM3x4Cover(
                  comicId: data.id,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoMode() {
    List<Widget> widgets = [];
    for (var i = 0; i < widget.data.length; i++) {
      widgets.add(_buildInfoCard(context, widget.data[i]));
    }
    if (widget.append != null) {
      widgets.add(SizedBox(height: 100, child: widget.append!));
    }
    return ListView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      children: widgets,
    );
  }

  Widget _buildInfoCard(BuildContext context, ComicSimple data) {
    const titleStyle = TextStyle(fontWeight: FontWeight.bold);
    final authorStyle = TextStyle(
      fontSize: 13,
      color: Colors.pink.shade300,
    );
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) {
            return ComicInfoScreen(data);
          },
        ));
      },
      child: Container(
        padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            Card(
              child: JM3x4Cover(
                comicId: data.id,
                width: 100 * 3 / 4,
                height: 100,
              ),
            ),
            Container(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: titleStyle),
                Container(height: 4),
                Text(data.author, style: authorStyle),
              ],
            )),
          ],
        ),
      ),
    );
  }
}