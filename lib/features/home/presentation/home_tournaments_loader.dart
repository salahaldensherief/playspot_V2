import 'package:playspot/art_core/extension/globlX.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import 'package:playspot/core/models/geo_coordinates.dart';
import '../../tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../../tournaments/domain/usecases/get_home_tournament_usecase.dart';
import '../../tournaments/domain/usecases/get_my_active_tournament_usecase.dart';
import '../../tournaments/domain/entities/tournament_entity.dart';
import 'home_state.dart';

class HomeTournamentsLoader {
  final GetTournamentsUseCase _getTournamentsUseCase;
  final GetHomeTournamentUseCase _getHomeTournamentUseCase;
  final GetMyActiveTournamentUseCase _getMyActiveTournamentUseCase;
  final PreferenceManager pref;
  final HomeState Function() readState;
  final void Function(HomeState) update;
  HomeTournamentsLoader(
    this._getTournamentsUseCase,
    this._getHomeTournamentUseCase,
    this._getMyActiveTournamentUseCase,
    this.pref,
    this.readState,
    this.update,
  );
  HomeState get state => readState();
  Future<void> load() async {
    await Future.wait([_loadHomeTournament(), _loadActiveTournament()]);
  }

  Future<void> _loadHomeTournament() async {
    final result = await _getHomeTournamentUseCase();
    await result.fold(
      (_) async {
        final coordinates = GeoCoordinates.fromPair(
          pref.latitude(),
          pref.longitude(),
        );
        final res = await _getTournamentsUseCase(
          latitude: coordinates?.latitude,
          longitude: coordinates?.longitude,
        );
        res.fold((_) {}, (tournaments) {
          final nearest =
              tournaments.firstWhereOrNull(
                (t) =>
                    t.status == TournamentStatus.registrationOpen ||
                    t.status == TournamentStatus.published,
              ) ??
              tournaments.firstOrNull;
          update(
            state.copyWith(
              nearbyTournament: nearest,
              clearNearbyTournament: nearest == null,
            ),
          );
        });
      },
      (t) async => update(
        state.copyWith(nearbyTournament: t, clearNearbyTournament: t == null),
      ),
    );
  }

  Future<void> _loadActiveTournament() async {
    final userId = pref.userId();
    if (userId == null || userId.isEmpty) return;
    final result = await _getMyActiveTournamentUseCase();
    result.fold((_) {}, (p) {
      update(
        state.copyWith(
          activeRegisteredTournament: p?.tournament,
          clearActiveRegisteredTournament: p?.tournament == null,
          activeUserParticipant: p?.participant,
          clearActiveUserParticipant: p?.participant == null,
        ),
      );
    });
  }
}
