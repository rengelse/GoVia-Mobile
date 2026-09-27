import 'models.dart';


const primaryTripTransports = <StageTransport>[
  StageTransport.motorcycle,
  StageTransport.car,
  StageTransport.cycling,
  StageTransport.walking,
  StageTransport.train,
];

const roundTripTransports = <StageTransport>[
  StageTransport.motorcycle,
  StageTransport.car,
  StageTransport.cycling,
  StageTransport.walking,
];

class RouteProfileOption {
  const RouteProfileOption({required this.id, required this.label, required this.description});
  final String id;
  final String label;
  final String description;
}

const transportProfiles = <StageTransport, List<RouteProfileOption>>{
  StageTransport.motorcycle: [
    RouteProfileOption(id: 'fastest', label: 'Raskest', description: 'Prioriterer kortest kjøretid.'),
    RouteProfileOption(id: 'balanced', label: 'Balansert', description: 'Balanse mellom tid og interessante veier.'),
    RouteProfileOption(id: 'curvy', label: 'Svingete', description: 'Prioriterer kandidatene med mer kurvatur.'),
    RouteProfileOption(id: 'max_curvy', label: 'Maks svingete', description: 'Prioriterer mest mulig kurvatur blant tilgjengelige kandidater.'),
  ],
  StageTransport.car: [
    RouteProfileOption(id: 'fastest', label: 'Raskest', description: 'Prioriterer kortest kjøretid.'),
    RouteProfileOption(id: 'shortest', label: 'Kortest', description: 'Prioriterer kortest distanse.'),
    RouteProfileOption(id: 'balanced', label: 'Balansert', description: 'Balanse mellom kjøretid og distanse.'),
  ],
  StageTransport.cycling: [
    RouteProfileOption(id: 'fastest', label: 'Raskest', description: 'Prioriterer kortest beregnet tid.'),
    RouteProfileOption(id: 'shortest', label: 'Kortest', description: 'Prioriterer kortest distanse.'),
    RouteProfileOption(id: 'balanced', label: 'Balansert', description: 'Balanse mellom tid og distanse.'),
  ],
  StageTransport.walking: [
    RouteProfileOption(id: 'fastest', label: 'Raskest', description: 'Prioriterer kortest beregnet tid.'),
    RouteProfileOption(id: 'shortest', label: 'Kortest', description: 'Prioriterer kortest distanse.'),
  ],
  StageTransport.train: [
    RouteProfileOption(id: 'fastest', label: 'Raskest', description: 'Prioriterer raskeste tilgjengelige togforbindelse.'),
  ],
  StageTransport.ferry: [
    RouteProfileOption(id: 'ferry', label: 'Ferge', description: 'Fergeetapper bruker terminaler og skal aldri tegnes som falsk veirute.'),
  ],
};

List<RouteProfileOption> profilesForTransport(StageTransport transport) => transportProfiles[transport] ?? const [];

String defaultProfileForTransport(StageTransport transport) => profilesForTransport(transport).first.id;

String routeModeForTransport(StageTransport transport) => switch (transport) {
      StageTransport.motorcycle || StageTransport.car => 'driving',
      StageTransport.walking => 'walking',
      StageTransport.cycling => 'cycling',
      StageTransport.train => 'rail',
      StageTransport.ferry => 'ferry',
    };

bool getTransportUsesRoadCandidates(StageTransport transport) =>
    transport == StageTransport.motorcycle || transport == StageTransport.car || transport == StageTransport.cycling || transport == StageTransport.walking;
