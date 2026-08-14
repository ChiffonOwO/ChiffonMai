class NearCadeShop {
    
    ///当前页。
    ///
    ///Current page.
    final int currentPage;
    
    ///是否有下一页。
    ///
    ///Whether there is a next page.
    final bool hasNextPage;
    
    ///是否有上一页。
    ///
    ///Whether there is a previous page.
    final bool hasPrevPage;
    
    ///店铺列表。
    ///
    ///Shop list.
    final List<Shop> shops;
    
    ///总数。
    ///
    ///Total count.
    final int totalCount;

    NearCadeShop({
        required this.currentPage,
        required this.hasNextPage,
        required this.hasPrevPage,
        required this.shops,
        required this.totalCount,
    });

    factory NearCadeShop.fromJson(Map<String, dynamic> json) => NearCadeShop(
        currentPage: json['currentPage'] as int? ?? 1,
        hasNextPage: json['hasNextPage'] as bool? ?? false,
        hasPrevPage: json['hasPrevPage'] as bool? ?? false,
        shops: (json['shops'] as List<dynamic>?)
            ?.map((e) => Shop.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
        totalCount: json['totalCount'] as int? ?? 0,
    );

    NearCadeShop copyWith({
        int? currentPage,
        bool? hasNextPage,
        bool? hasPrevPage,
        List<Shop>? shops,
        int? totalCount,
    }) => 
        NearCadeShop(
            currentPage: currentPage ?? this.currentPage,
            hasNextPage: hasNextPage ?? this.hasNextPage,
            hasPrevPage: hasPrevPage ?? this.hasPrevPage,
            shops: shops ?? this.shops,
            totalCount: totalCount ?? this.totalCount,
        );
}

class Shop {
    
    ///MongoDB ID。
    ///
    ///MongoDB ID.
    final String id;
    
    ///店铺地址。
    ///
    ///Shop address.
    final Address address;
    
    ///店铺说明。
    ///
    ///Shop note.
    final String comment;
    
    ///创建时间。
    ///
    ///Creation time.
    final DateTime createdAt;
    
    ///机台。
    ///
    ///Machines/games available at the shop.
    final List<Game> games;
    
    ///店铺 ID。
    ///
    ///Shop ID.
    final int shopId;
    
    ///店铺是否已被认领。
    ///
    ///Whether this shop is claimed by a machine/operator.
    final bool? isClaimed;
    
    ///店铺是否已被管理员锁定。锁定后仅管理员可编辑。
    ///
    ///Whether this shop has been locked by an admin. Only admins can edit locked shops.
    final bool? isLocked;
    
    ///店铺营业状态。
    ///
    ///Whether the shop is currently open.
    final bool? isOpen;
    
    ///店铺坐标。
    ///
    ///Shop coordinates.
    final Location location;
    
    ///店铺名称。
    ///
    ///Shop name.
    final String name;
    
    ///营业时间。仅有 1 个元素时表示整周均为该营业时间；有 7 个元素时每个元素分别代表一周中的一天。
    ///
    ///Opening hours. One item means the same hours for the whole week; seven items map to
    ///weekdays.
    final List<List<OpeningHour>> openingHours;
    
    ///店铺认领者用户 ID。
    ///
    ///User ID of the shop owner (set when the shop is claimed via machine activation).
    final String? ownerId;
    
    ///店铺时区。
    ///
    ///Computed shop timezone.
    final Timezone? timezone;
    
    ///更新时间。
    ///
    ///Update time.
    final DateTime updatedAt;

    Shop({
        required this.id,
        required this.address,
        required this.comment,
        required this.createdAt,
        required this.games,
        required this.shopId,
        this.isClaimed,
        this.isLocked,
        this.isOpen,
        required this.location,
        required this.name,
        required this.openingHours,
        this.ownerId,
        this.timezone,
        required this.updatedAt,
    });

    factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['_id'] as String? ?? '',
        address: Address.fromJson(json['address'] as Map<String, dynamic>? ?? {}),
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        games: (json['games'] as List<dynamic>?)
            ?.map((e) => Game.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
        shopId: json['shopId'] as int? ?? 0,
        isClaimed: json['isClaimed'] as bool?,
        isLocked: json['isLocked'] as bool?,
        isOpen: json['isOpen'] as bool?,
        location: Location.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
        name: json['name'] as String? ?? '',
        openingHours: (json['openingHours'] as List<dynamic>?)
            ?.map((day) => (day as List<dynamic>?)
                ?.map((h) => OpeningHour.fromJson(h as Map<String, dynamic>))
                .toList() ?? [])
            .toList() ?? [],
        ownerId: json['ownerId'] as String?,
        timezone: json['timezone'] != null
            ? Timezone.fromJson(json['timezone'] as Map<String, dynamic>)
            : null,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );

    Shop copyWith({
        String? id,
        Address? address,
        String? comment,
        DateTime? createdAt,
        List<Game>? games,
        int? shopId,
        bool? isClaimed,
        bool? isLocked,
        bool? isOpen,
        Location? location,
        String? name,
        List<List<OpeningHour>>? openingHours,
        String? ownerId,
        Timezone? timezone,
        DateTime? updatedAt,
    }) => 
        Shop(
            id: id ?? this.id,
            address: address ?? this.address,
            comment: comment ?? this.comment,
            createdAt: createdAt ?? this.createdAt,
            games: games ?? this.games,
            shopId: shopId ?? this.shopId,
            isClaimed: isClaimed ?? this.isClaimed,
            isLocked: isLocked ?? this.isLocked,
            isOpen: isOpen ?? this.isOpen,
            location: location ?? this.location,
            name: name ?? this.name,
            openingHours: openingHours ?? this.openingHours,
            ownerId: ownerId ?? this.ownerId,
            timezone: timezone ?? this.timezone,
            updatedAt: updatedAt ?? this.updatedAt,
        );
}


///店铺地址。
///
///Shop address.
class Address {
    
    ///详细地址。
    ///
    ///Detailed street address.
    final String detailed;
    
    ///大致地址，一般为：[国家/地区, 省, 市, 区]。
    ///
    ///General address, usually [country/region, province, city, district].
    final List<String> general;
    
    ///地区 ID 层级。
    ///
    ///Region hierarchy.
    final List<dynamic>? region;

    Address({
        required this.detailed,
        required this.general,
        this.region,
    });

    factory Address.fromJson(Map<String, dynamic> json) => Address(
        detailed: json['detailed'] as String? ?? '',
        general: (json['general'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ?? [],
        region: json['region'] as List<dynamic>?,
    );

    Address copyWith({
        String? detailed,
        List<String>? general,
        List<dynamic>? region,
    }) => 
        Address(
            detailed: detailed ?? this.detailed,
            general: general ?? this.general,
            region: region ?? this.region,
        );
}

class RegionClass {
    final String id;
    final Map<String, String> name;

    RegionClass({
        required this.id,
        required this.name,
    });

    factory RegionClass.fromJson(Map<String, dynamic> json) => RegionClass(
        id: json['id'] as String? ?? '',
        name: (json['name'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)) ?? {},
    );

    RegionClass copyWith({
        String? id,
        Map<String, String>? name,
    }) => 
        RegionClass(
            id: id ?? this.id,
            name: name ?? this.name,
        );
}

class Game {
    
    ///游戏说明。
    ///
    ///Game note.
    final String comment;
    
    ///价格说明。
    ///
    ///Price note.
    final String cost;
    
    ///机台 ID。
    ///
    ///Machine ID.
    final int gameId;
    
    ///游戏名。
    ///
    ///Game name.
    final String name;
    
    ///机台数量。
    ///
    ///Number of machines.
    final int quantity;
    
    ///游戏系列 ID。
    ///
    ///Game series ID.
    final int titleId;
    
    ///游戏版本。
    ///
    ///Game version.
    final String version;

    Game({
        required this.comment,
        required this.cost,
        required this.gameId,
        required this.name,
        required this.quantity,
        required this.titleId,
        required this.version,
    });

    factory Game.fromJson(Map<String, dynamic> json) => Game(
        comment: json['comment'] as String? ?? '',
        cost: json['cost'] as String? ?? '',
        gameId: json['gameId'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        titleId: json['titleId'] as int? ?? 0,
        version: json['version'] as String? ?? '',
    );

    Game copyWith({
        String? comment,
        String? cost,
        int? gameId,
        String? name,
        int? quantity,
        int? titleId,
        String? version,
    }) => 
        Game(
            comment: comment ?? this.comment,
            cost: cost ?? this.cost,
            gameId: gameId ?? this.gameId,
            name: name ?? this.name,
            quantity: quantity ?? this.quantity,
            titleId: titleId ?? this.titleId,
            version: version ?? this.version,
        );
}


///店铺坐标。
///
///Shop coordinates.
class Location {
    
    ///GeoJSON 坐标，顺序为 [经度, 纬度]。
    ///
    ///GeoJSON coordinates in [longitude, latitude] order.
    final List<double> coordinates;
    
    ///GeoJSON 几何类型。
    ///
    ///GeoJSON geometry type.
    final Type type;

    Location({
        required this.coordinates,
        required this.type,
    });

    factory Location.fromJson(Map<String, dynamic> json) => Location(
        coordinates: (json['coordinates'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ?? [],
        type: json['type'] == 'Point' ? Type.POINT : Type.POINT,
    );

    Location copyWith({
        List<double>? coordinates,
        Type? type,
    }) => 
        Location(
            coordinates: coordinates ?? this.coordinates,
            type: type ?? this.type,
        );
}


///GeoJSON 几何类型。
///
///GeoJSON geometry type.
enum Type {
    POINT
}

class OpeningHour {
    
    ///24 小时制本地小时。
    ///
    ///Hour in 24-hour local time.
    final int hour;
    
    ///分钟。
    ///
    ///Minute.
    final int minute;

    OpeningHour({
        required this.hour,
        required this.minute,
    });

    factory OpeningHour.fromJson(Map<String, dynamic> json) => OpeningHour(
        hour: json['hour'] as int? ?? 0,
        minute: json['minute'] as int? ?? 0,
    );

    OpeningHour copyWith({
        int? hour,
        int? minute,
    }) => 
        OpeningHour(
            hour: hour ?? this.hour,
            minute: minute ?? this.minute,
        );
}


///店铺时区。
///
///Computed shop timezone.
class Timezone {
    
    ///时区名称。
    ///
    ///Timezone name.
    final String name;
    
    ///时区偏移，单位：小时。
    ///
    ///Timezone offset in hours.
    final double offset;

    Timezone({
        required this.name,
        required this.offset,
    });

    factory Timezone.fromJson(Map<String, dynamic> json) => Timezone(
        name: json['name'] as String? ?? '',
        offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
    );

    Timezone copyWith({
        String? name,
        double? offset,
    }) => 
        Timezone(
            name: name ?? this.name,
            offset: offset ?? this.offset,
        );
}