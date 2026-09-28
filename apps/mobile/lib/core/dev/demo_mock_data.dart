import 'package:sk_live/core/providers/gift_provider.dart';

class DemoMockData {
  DemoMockData._();

  static const demoRoomId = 'b3000001-0001-4001-8001-000000000001';

  static const _avatarBase = 'https://i.pravatar.cc/200';

  static List<GiftRankingModel> roomContributionRankings() {
    return [
      _user(
        id: 'b1000001-0001-4001-8001-000000000011',
        username: 'A L i Rajput',
        avatar: '$_avatarBase?img=11',
        score: 1900000,
        rank: 1,
        charmLevel: 15,
        wealthLevel: 10,
        userLevel: 10,
      ),
      _user(
        id: 'b1000001-0001-4001-8001-000000000012',
        username: 'Hafsa Ch',
        avatar: '$_avatarBase?img=5',
        score: 126000,
        rank: 2,
        charmLevel: 6,
        wealthLevel: 4,
        userLevel: 6,
      ),
      _user(
        id: 'b1000001-0001-4001-8001-000000000013',
        username: 'Barby',
        avatar: '$_avatarBase?img=9',
        score: 1200,
        rank: 3,
        charmLevel: 5,
        wealthLevel: 3,
        userLevel: 5,
      ),
      _user(
        id: 'b1000001-0001-4001-8001-000000000014',
        username: 'Cute Peri',
        avatar: '$_avatarBase?img=16',
        score: 1100,
        rank: 4,
        charmLevel: 4,
        wealthLevel: 2,
        userLevel: 4,
      ),
      _user(
        id: 'b1000001-0001-4001-8001-000000000015',
        username: 'Balla',
        avatar: '$_avatarBase?img=12',
        score: 980,
        rank: 5,
        charmLevel: 3,
        wealthLevel: 2,
        userLevel: 3,
      ),
      _user(
        id: 'b1000001-0001-4001-8001-000000000016',
        username: 'Sara Khan',
        avatar: '$_avatarBase?img=20',
        score: 750,
        rank: 6,
        charmLevel: 2,
        wealthLevel: 1,
        userLevel: 2,
      ),
    ];
  }

  static GiftRankingModel _user({
    required String id,
    required String username,
    required String avatar,
    required int score,
    required int rank,
    required int charmLevel,
    required int wealthLevel,
    required int userLevel,
  }) {
    return GiftRankingModel(
      userId: id,
      username: username,
      avatarUrl: avatar,
      score: score,
      rank: rank,
      userLevel: userLevel,
      charmLevel: charmLevel,
      wealthLevel: wealthLevel,
    );
  }

  static const demoAgency = DemoAgency(
    id: 'b2000001-0001-4001-8001-000000000001',
    name: 'SK Stars Agency',
    code: 'SKSTAR',
    ownerUsername: 'Agency Boss',
    ownerAvatar: '$_avatarBase?img=33',
  );

  static const demoHost = DemoHost(
    userId: 'b1000001-0001-4001-8001-000000000001',
    username: 'A L i Rajput',
    avatar: '$_avatarBase?img=11',
    roomId: demoRoomId,
    roomTitle: 'VIP Lounge Room',
    roomImage:
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400',
    charmLevel: 15,
    wealthLevel: 10,
  );
}

class DemoAgency {
  const DemoAgency({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerUsername,
    required this.ownerAvatar,
  });

  final String id;
  final String name;
  final String code;
  final String ownerUsername;
  final String ownerAvatar;
}

class DemoHost {
  const DemoHost({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.roomId,
    required this.roomTitle,
    required this.roomImage,
    required this.charmLevel,
    required this.wealthLevel,
  });

  final String userId;
  final String username;
  final String avatar;
  final String roomId;
  final String roomTitle;
  final String roomImage;
  final int charmLevel;
  final int wealthLevel;
}
