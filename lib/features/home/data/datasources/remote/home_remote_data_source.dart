import '../../models/lounge_model.dart';
import '../../models/promo_model.dart';
import '../../models/category_model.dart';
import '../../models/home_params.dart';
export 'home_remote_data_source_impl.dart';

abstract class HomeRemoteDataSource {
  Future<List<LoungeModel>> getLounges(GetLoungesParams params);
  Future<List<Map<String, dynamic>>> getAvailableCities();
  Future<List<PromoModel>> getPromotions({String? loungeId});
  Future<List<CategoryModel>> getCategories();
  Future<int> getUserPoints(String userId);
  Future<LoungeModel?> getLoungeById(String id);
}
