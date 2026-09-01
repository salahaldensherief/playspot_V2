import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/home/domain/repositories/home_repository.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_screen.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_state.dart';

class RoomDetailsScreen extends StatefulWidget {
  final String roomId;
  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final roomRes = await sl<LoungeDetailsRepository>().getRoomById(widget.roomId);
    
    roomRes.fold(
      (l) => setState(() { _error = l.message; _isLoading = false; }),
      (room) async {
        if (room == null) {
          setState(() { _error = AppStrings.roomNotFound.tr(); _isLoading = false; });
          return;
        }
        
        final loungeRes = await sl<HomeRepository>().getLoungeById(room.loungeId);
        loungeRes.fold(
          (l) => setState(() { _error = l.message; _isLoading = false; }),
          (lounge) {
            if (lounge == null) {
               setState(() { _error = AppStrings.loungeNotFound.tr(); _isLoading = false; });
               return;
            }
            // Successfully got both. Now we can show LoungeDetails with room selected.
            // We use a Navigator.pushReplacement or similar logic if we want to stay in the same stack context.
            // But since this is a screen, we'll just render LoungeDetails inside it or use a BlocProvider.
            
            if (mounted) {
               // We will use the LoungeDetailsScreen directly but with room selection.
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(
                   builder: (context) => BlocProvider(
                     create: (context) => sl<LoungeDetailsCubit>()..init(lounge)..toggleRoomSelection(room.id),
                     child: LoungeDetailsScreen(lounge: lounge),
                   ),
                 ),
               );
            }
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(child: AppText(text: _error!, color: Colors.white)),
      );
    }

    return const SizedBox.shrink();
  }
}
