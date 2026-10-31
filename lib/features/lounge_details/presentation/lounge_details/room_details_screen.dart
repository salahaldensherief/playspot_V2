import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/buttons/back_button_widget.dart';
import 'package:playspot/art_core/widgets/layout/app_state_view.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/lounge_details/domain/repositories/lounge_details_repository.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/domain/repositories/home_repository.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';
import 'package:playspot/features/lounge_details/presentation/lounge_details/lounge_details_screen.dart';

class RoomDetailsScreen extends StatefulWidget {
  final String roomId;
  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  LoungeModel? _lounge;
  String? _roomIdToSelect;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final roomRes = await sl<LoungeDetailsRepository>().getRoomById(
      widget.roomId,
    );
    if (!mounted) return;
    await roomRes.fold<Future<void>>(
      (failure) async => _showError(failure.message),
      (room) async {
        if (room == null) {
          _showError(AppStrings.roomNotFound.tr());
          return;
        }

        final loungeRes = await sl<HomeRepository>().getLoungeById(
          room.loungeId,
        );
        if (!mounted) return;
        loungeRes.fold((failure) => _showError(failure.message), (lounge) {
          if (lounge == null) {
            _showError(AppStrings.loungeNotFound.tr());
            return;
          }
          setState(() {
            _lounge = lounge;
            _roomIdToSelect = room.id;
            _isLoading = false;
          });
          final cubit = context.read<LoungeDetailsCubit>();
          cubit.init(lounge);
          if (_roomIdToSelect != null) {
            cubit.toggleRoomSelection(_roomIdToSelect!);
          }
        });
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: AppLoader(size: 40),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const BackButtonWidget(),
        ),
        body: AppStateView.error(title: _error!, onRetry: _loadData),
      );
    }

    if (_lounge != null) {
      return LoungeDetailsScreen(lounge: _lounge!);
    }

    return const SizedBox.shrink();
  }
}
