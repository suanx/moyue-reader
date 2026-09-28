import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage/book_storage.dart';

/// 内置示例书：无需导入即可体验阅读与听书（公共领域文本）
class SampleBooks {
  SampleBooks._();

  static const _uuid = Uuid();

  static const List<Map<String, String>> samples = [
    {
      'title': '桃花源记',
      'author': '陶渊明',
      'desc': '晋太元中，武陵人捕鱼为业——一段关于理想世界的中国式想象。',
    },
    {
      'title': '爱莲说',
      'author': '周敦颐',
      'desc': '予独爱莲之出淤泥而不染，濯清涟而不妖。',
    },
    {
      'title': '岳阳楼记',
      'author': '范仲淹',
      'desc': '先天下之忧而忧，后天下之乐而乐。',
    },
    {
      'title': '赤壁赋',
      'author': '苏轼',
      'desc': '寄蜉蝣于天地，渺沧海之一粟。',
    },
  ];

  static const String _taohua = '''　　晋太元中，武陵人捕鱼为业。缘溪行，忘路之远近。忽逢桃花林，夹岸数百步，中无杂树，芳草鲜美，落英缤纷。渔人甚异之，复前行，欲穷其林。
　　林尽水源，便得一山，山有小口，仿佛若有光。便舍船，从口入。初极狭，才通人。复行数十步，豁然开朗。土地平旷，屋舍俨然，有良田、美池、桑竹之属。阡陌交通，鸡犬相闻。其中往来种作，男女衣着，悉如外人。黄发垂髫，并怡然自乐。
　　见渔人，乃大惊，问所从来。具答之。便要还家，设酒杀鸡作食。村中闻有此人，咸来问讯。自云先世避秦时乱，率妻子邑人来此绝境，不复出焉，遂与外人间隔。问今是何世，乃不知有汉，无论魏晋。此人一一为具言所闻，皆叹惋。余人各复延至其家，皆出酒食。停数日，辞去。此中人语云："不足为外人道也。"
　　既出，得其船，便扶向路，处处志之。及郡下，诣太守，说如此。太守即遣人随其往，寻向所志，遂迷，不复得路。
　　南阳刘子骥，高尚士也，闻之，欣然规往。未果，寻病终。后遂无问津者。''';

  static const String _ailian = '''　　水陆草木之花，可爱者甚蕃。晋陶渊明独爱菊；自李唐来，世人甚爱牡丹；予独爱莲之出淤泥而不染，濯清涟而不妖，中通外直，不蔓不枝，香远益清，亭亭净植，可远观而不可亵玩焉。
　　予谓菊，花之隐逸者也；牡丹，花之富贵者也；莲，花之君子者也。噫！菊之爱，陶后鲜有闻。莲之爱，同予者何人？牡丹之爱，宜乎众矣！''';

  static const String _yueyang = '''　　庆历四年春，滕子京谪守巴陵郡。越明年，政通人和，百废具兴，乃重修岳阳楼，增其旧制，刻唐贤今人诗赋于其上，属予作文以记之。
　　予观夫巴陵胜状，在洞庭一湖。衔远山，吞长江，浩浩汤汤，横无际涯，朝晖夕阴，气象万千，此则岳阳楼之大观也，前人之述备矣。然则北通巫峡，南极潇湘，迁客骚人，多会于此，览物之情，得无异乎？
　　若夫淫雨霏霏，连月不开，阴风怒号，浊浪排空，日星隐曜，山岳潜形，商旅不行，樯倾楫摧，薄暮冥冥，虎啸猿啼。登斯楼也，则有去国怀乡，忧谗畏讥，满目萧然，感极而悲者矣。
　　至若春和景明，波澜不惊，上下天光，一碧万顷，沙鸥翔集，锦鳞游泳，岸芷汀兰，郁郁青青。而或长烟一空，皓月千里，浮光跃金，静影沉璧，渔歌互答，此乐何极！登斯楼也，则有心旷神怡，宠辱偕忘，把酒临风，其喜洋洋者矣。
　　嗟夫！予尝求古仁人之心，或异二者之为，何哉？不以物喜，不以己悲，居庙堂之高则忧其民，处江湖之远则忧其君。是进亦忧，退亦忧。然则何时而乐耶？其必曰"先天下之忧而忧，后天下之乐而乐"乎！噫！微斯人，吾谁与归？''';

  static const String _chibi = '''　　壬戌之秋，七月既望，苏子与客泛舟游于赤壁之下。清风徐来，水波不兴。举酒属客，诵明月之诗，歌窈窕之章。少焉，月出于东山之上，徘徊于斗牛之间。白露横江，水光接天。纵一苇之所如，凌万顷之茫然。浩浩乎如冯虚御风，而不知其所止；飘飘乎如遗世独立，羽化而登仙。
　　于是饮酒乐甚，扣舷而歌之。歌曰："桂棹兮兰桨，击空明兮溯流光。渺渺兮予怀，望美人兮天一方。"客有吹洞箫者，倚歌而和之，其声呜呜然，如怨如慕，如泣如诉，余音袅袅，不绝如缕。舞幽壑之潜蛟，泣孤舟之嫠妇。
　　苏子愀然，正襟危坐而问客曰："何为其然也？"客曰："月明星稀，乌鹊南飞，此非曹孟德之诗乎？西望夏口，东望武昌，山川相缪，郁乎苍苍，此非孟德之困于周郎者乎？方其破荆州，下江陵，顺流而东也，舳舻千里，旌旗蔽空，酾酒临江，横槊赋诗，固一世之雄也，而今安在哉？"
　　况吾与子渔樵于江渚之上，侣鱼虾而友麋鹿，驾一叶之扁舟，举匏樽以相属。寄蜉蝣于天地，渺沧海之一粟。哀吾生之须臾，羡长江之无穷。挟飞仙以遨游，抱明月而长终。知不可乎骤得，托遗响于悲风。
　　苏子曰："客亦知夫水与月乎？逝者如斯，而未尝往也；盈虚者如彼，而卒莫消长也。盖将自其变者而观之，则天地曾不能以一瞬；自其不变者而观之，则物与我皆无尽也，而又何羡乎！"''';

  static String textOf(String title) => switch (title) {
        '桃花源记' => _taohua,
        '爱莲说' => _ailian,
        '岳阳楼记' => _yueyang,
        '赤壁赋' => _chibi,
        _ => _taohua,
      };

  /// 创建一本内置示例书
  static Future<Book> create(String title, String author, String desc) async {
    final id = _uuid.v4();
    final body = textOf(title);
    final parts = body.split('\n').where((e) => e.trim().isNotEmpty).toList();
    final titles = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final fileName = BookStorage.encodeChapterFileName(i);
      await BookStorage.writeChapter(id, fileName, parts[i].replaceAll(RegExp(r'^\s+'), ''));
      titles.add('${['其一', '其二', '其三', '其四', '其五', '其六'][i % 6]}');
    }
    final book = Book(
      id: id,
      title: title,
      author: author,
      format: BookFormat.txt,
      addedAt: DateTime.now(),
      coverIndex: id.hashCode.abs() % 6,
      description: desc,
      charCount: body.length,
      chapterTitles: titles,
    );
    await BookRepository.instance.save(book);
    return book;
  }
}
