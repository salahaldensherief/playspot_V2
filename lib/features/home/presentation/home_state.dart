import 'package:equatable/equatable.dart';
import '../../tournaments/domain/entities/tournament_entity.dart';
import '../data/models/lounge_model.dart';
import '../data/models/promo_model.dart';
import '../data/models/category_model.dart';

enum HomeStatus { initial, loading, refreshing, success, failure, loadingMore }

enum LoungeSortType { nearest, topRated }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<LoungeModel> nearestLounges;
  final List<LoungeModel> topRatedLounges;
  final List<PromoModel> promotions;
  final List<CategoryModel> categories;
  final List<Map<String, dynamic>> availableCities;
  final int pointsBalance;
  final String? selectedCity;
  final List<String> selectedCategoryIds;
  final String? currentAddress;
  final String? errorMessage;
  final int currentPage;
  final bool hasReachedMax;
  final LoungeSortType sortType;
  final TournamentEntity? nearbyTournament;
  final TournamentEntity? activeRegisteredTournament;
  final TournamentParticipantEntity? activeUserParticipant;

  final bool isLoungesLoading;
  final bool isPromosLoading;
  final bool isCategoriesLoading;

  const HomeState({
    this.status = HomeStatus.initial,
    this.isLoungesLoading = false,
    this.isPromosLoading = false,
    this.isCategoriesLoading = false,
    this.nearestLounges = const [],
    this.topRatedLounges = const [],
    this.promotions = const [],
    this.categories = const [],
    this.availableCities = const [],
    this.pointsBalance = 0,
    this.selectedCity,
    this.selectedCategoryIds = const [],
    this.currentAddress,
    this.errorMessage,
    this.currentPage = 0,
    this.hasReachedMax = false,
    this.sortType = LoungeSortType.nearest,
    this.nearbyTournament,
    this.activeRegisteredTournament,
    this.activeUserParticipant,
  });

  HomeState copyWith({
    HomeStatus? status,
    bool? isLoungesLoading,
    bool? isPromosLoading,
    bool? isCategoriesLoading,
    List<LoungeModel>? nearestLounges,
    List<LoungeModel>? topRatedLounges,
    List<PromoModel>? promotions,
    List<CategoryModel>? categories,
    List<Map<String, dynamic>>? availableCities,
    int? pointsBalance,
    String? selectedCity,
    List<String>? selectedCategoryIds,
    String? currentAddress,
    String? errorMessage,
    int? currentPage,
    bool? hasReachedMax,
    LoungeSortType? sortType,
    bool clearCity = false,
    TournamentEntity? nearbyTournament,
    bool clearNearbyTournament = false,
    TournamentEntity? activeRegisteredTournament,
    bool clearActiveRegisteredTournament = false,
    TournamentParticipantEntity? activeUserParticipant,
    bool clearActiveUserParticipant = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      isLoungesLoading: isLoungesLoading ?? this.isLoungesLoading,
      isPromosLoading: isPromosLoading ?? this.isPromosLoading,
      isCategoriesLoading: isCategoriesLoading ?? this.isCategoriesLoading,
      nearestLounges: nearestLounges ?? this.nearestLounges,
      topRatedLounges: topRatedLounges ?? this.topRatedLounges,
      promotions: promotions ?? this.promotions,
      categories: categories ?? this.categories,
      availableCities: availableCities ?? this.availableCities,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      currentAddress: currentAddress ?? this.currentAddress,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      sortType: sortType ?? this.sortType,
      nearbyTournament: clearNearbyTournament ? null : (nearbyTournament ?? this.nearbyTournament),
      activeRegisteredTournament: clearActiveRegisteredTournament
          ? null
          : (activeRegisteredTournament ?? this.activeRegisteredTournament),
      activeUserParticipant: clearActiveUserParticipant
          ? null
          : (activeUserParticipant ?? this.activeUserParticipant),
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLoungesLoading,
    isPromosLoading,
    isCategoriesLoading,
    nearestLounges,
    topRatedLounges,
    promotions,
    categories,
    availableCities,
    pointsBalance,
    selectedCity,
    selectedCategoryIds,
    currentAddress,
    errorMessage,
    currentPage,
    hasReachedMax,
    sortType,
    nearbyTournament,
    activeRegisteredTournament,
    activeUserParticipant,
  ];
}
