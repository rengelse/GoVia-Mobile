import '../../../domain/models.dart';

class DiscoveryCategory {
  const DiscoveryCategory(this.id, this.label, {this.routeTags = const [],
    this.poiCategory, this.poiType = 'all', this.poiTypes = const [], this.osmFilters = const [], this.strictOsm = false});
  final String id;
  final String label;
  final List<String> routeTags;
  final String? poiCategory;
  final String poiType;
  final List<String> poiTypes;
  final List<String> osmFilters;
  final bool strictOsm;

  bool matchesRoute(PublishedRoute route) => id == 'all' || route.tags.any((tag) =>
    routeTags.map(normalizeTag).contains(normalizeTag(tag)));

  static String normalizeTag(String value) => value.trim().toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), ' ');
}

StageTransport discoveryTransport(StageTransport transport) =>
    transport == StageTransport.ferry ? StageTransport.car : transport;

const _all = DiscoveryCategory('all', 'Alle');
const _food = DiscoveryCategory('food', 'Mat og kafé', routeTags: ['mat','mat og kafé','food','cafe','kafe','kafé'],
    poiCategory: 'Mat & drikke', poiTypes: ['restaurant', 'cafe'], osmFilters: [r'["amenity"~"^(restaurant|cafe|fast_food)$"]']);
const _sights = DiscoveryCategory('sights', 'Severdigheter', routeTags: ['severdighet','severdigheter','attraction','sightseeing'],
    poiCategory: 'Severdigheter', poiType: 'attraction', osmFilters: [r'["tourism"~"^(attraction|museum|gallery)$"]','["historic"]']);
const _stay = DiscoveryCategory('stay', 'Overnatting', routeTags: ['overnatting','accommodation','hotel','hotell'],
    poiCategory: 'Overnatting', poiTypes: ['hotel', 'camping'], osmFilters: [r'["tourism"~"^(hotel|motel|guest_house|hostel|camp_site|chalet)$"]']);
const _views = DiscoveryCategory('views', 'Utsiktspunkter', routeTags: ['utsikt','utsiktspunkter','viewpoint','scenic'],
    poiCategory: 'Severdigheter', poiType: 'viewpoint', osmFilters: ['["tourism"="viewpoint"]']);
const _nature = DiscoveryCategory('nature', 'Natur', routeTags: ['natur','nature','national park','nasjonalpark'],
    poiCategory: 'Natur', strictOsm: true, osmFilters: [r'["natural"~"^(peak|beach)$"]','["waterway"="waterfall"]']);

List<DiscoveryCategory> discoveryCategories(StageTransport raw) => switch (discoveryTransport(raw)) {
  StageTransport.motorcycle => const [_all,
    DiscoveryCategory('curves', 'Svingete veier', routeTags: ['svingete','svingete veier','kurver','kurvekombinasjoner','twisty','curvy']),
    DiscoveryCategory('passes', 'Fjelloverganger', routeTags: ['fjellpass','fjelloverganger','fjellovergang','mountain_pass','mountain pass'],
      poiCategory: 'Natur', poiType: 'mountain_pass', strictOsm: true, osmFilters: ['["mountain_pass"="yes"]']),
    DiscoveryCategory('mc_hotel', 'MC-hotell', routeTags: ['mc-hotell','mc hotel','motorcycle friendly','motorcycle hotel'],
      poiCategory: 'Overnatting', poiType: 'hotel', strictOsm: true,
      osmFilters: ['["tourism"="hotel"]["motorcycle_friendly"="yes"]']),
    _views, _food, _stay],
  StageTransport.car => const [_all,
    DiscoveryCategory('scenic', 'Naturskjønne veier', routeTags: ['scenic','naturskjønn','naturskjønne veier','panoramarute']),
    _sights,
    DiscoveryCategory('family', 'Familieaktiviteter', routeTags: ['familie','family'],
      poiCategory: 'Severdigheter', strictOsm: true, osmFilters: ['["tourism"="theme_park"]','["leisure"="playground"]']),
    _stay, _food],
  StageTransport.walking => const [_all,
    DiscoveryCategory('trails', 'Turstier', routeTags: ['tursti','turstier','trail','hiking','fottur']),
    _views, _nature, _food, _stay],
  StageTransport.cycling => const [_all,
    DiscoveryCategory('cycle_routes', 'Sykkelruter', routeTags: ['sykkelrute','sykkelruter','cycle route','cycling']),
    DiscoveryCategory('quiet', 'Lite trafikk', routeTags: ['lite trafikk','quiet','low traffic']),
    DiscoveryCategory('bike_stay', 'Sykkelvennlig overnatting', routeTags: ['sykkelvennlig','sykkelvennlig overnatting','bicycle friendly','bike hotel'],
      poiCategory: 'Overnatting', strictOsm: true, osmFilters: [r'["tourism"~"^(hotel|guest_house|hostel)$"]["bicycle_friendly"="yes"]']),
    DiscoveryCategory('repair', 'Sykkelverksted', routeTags: ['sykkelverksted','bicycle repair'],
      poiCategory: 'Service & verksted', poiType: 'bicycle_repair', osmFilters: ['["shop"="bicycle"]','["service:bicycle:repair"="yes"]']),
    _views, _food],
  StageTransport.train => const [_all,
    DiscoveryCategory('stations', 'Stasjoner', routeTags: ['stasjon','station'],
      poiCategory: 'Praktisk', strictOsm: true, osmFilters: ['["railway"="station"]']),
    _sights, _food, _stay],
  StageTransport.ferry => const [_all],
};

List<PublishedRoute> filterDiscoveryRoutes(List<PublishedRoute> routes,
    StageTransport transport, DiscoveryCategory category) => routes.where((route) =>
      route.status == 'published' && route.visibility == 'public' &&
      route.transport == discoveryTransport(transport) && category.matchesRoute(route)).toList(growable: false);
