import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/core/responsive/app_breakpoints.dart';
import 'lounge_details_screen.dart';
import 'lounge_details_cubit.dart';
import 'widgets/lounge_details_content.dart';

class LoungeDetailsScreenState extends State<LoungeDetailsScreen>
    with WidgetsBindingObserver {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lounge = widget.lounge;
    final id = widget.loungeId;
    final cubit = context.read<LoungeDetailsCubit>();
    if (lounge != null) {
      cubit.init(lounge);
    } else if (id != null && id.isNotEmpty) {
      cubit.initById(id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final cubit = context.read<LoungeDetailsCubit>();
    final id = cubit.state.lounge?.id ?? widget.loungeId;
    if (id != null && id.isNotEmpty) cubit.getLoungeDetails(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBackground,
    body: SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppBreakpoints.isMobileWidth(constraints.maxWidth)
                  ? constraints.maxWidth
                  : 840,
            ),
            child: RepaintBoundary(
              child: LoungeDetailsContent(
                initialLounge: widget.lounge,
                loungeId: widget.loungeId,
                heroTag: widget.heroTag,
                controller: _controller,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
