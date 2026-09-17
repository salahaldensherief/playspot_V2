// bracket_match_node.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../domain/entities/tournament_entity.dart';

class BracketMatchNode extends StatefulWidget {
  final TournamentMatchEntity match;
  final VoidCallback onTap;

  const BracketMatchNode({
    super.key,
    required this.match,
    required this.onTap,
  });

  @override
  State<BracketMatchNode> createState() => _BracketMatchNodeState();
}

class _BracketMatchNodeState extends State<BracketMatchNode> {
  bool _showPlayer1Name = false;
  bool _showPlayer2Name = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final bool hasWinner = match.winnerId != null && match.winnerId!.isNotEmpty;
    final bool p1IsWinner = hasWinner && match.winnerId == match.player1Id;
    final bool p2IsWinner = hasWinner && match.winnerId == match.player2Id;
    final bool p1IsLoser = hasWinner && match.player1Id != null && !p1IsWinner;
    final bool p2IsLoser = hasWinner && match.player2Id != null && !p2IsWinner;
    final bool isInProgress = match.status == MatchStatus.inProgress;

    return GestureDetector(
      onLongPress: widget.onTap,
      child: Column(
        // spaceBetween بيثبّت الصورة الأولى في أعلى الصندوق والتانية في أسفله بالظبط
        // (بدل ما تتمركز حرة وتختلف مكانها حسب ارتفاع كتلة VS)
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player 1 (Top)
          _buildAvatarWidget(
            name: match.player1Name,
            avatar: match.player1Avatar,
            score: match.player1Score,
            isWinner: p1IsWinner,
            isLoser: p1IsLoser,
            showName: _showPlayer1Name,
            isTopPlayer: true,
            onTap: () {
              setState(() {
                _showPlayer1Name = !_showPlayer1Name;
              });
            },
          ),
          // VS / LIVE indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isInProgress ? AppColors.neonPurple.withValues(alpha: 0.4) : AppColors.neonBlue.withValues(alpha: 0.2),
                  isInProgress ? AppColors.neonBlue.withValues(alpha: 0.4) : AppColors.neonPurple.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isInProgress ? AppColors.neonPurple : AppColors.neonBlue.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              isInProgress ? 'LIVE' : 'VS',
              style: TextStyle(
                color: isInProgress ? AppColors.neonPurple : AppColors.neonBlue,
                fontSize: 7,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          // Player 2 (Bottom)
          _buildAvatarWidget(
            name: match.player2Name,
            avatar: match.player2Avatar,
            score: match.player2Score,
            isWinner: p2IsWinner,
            isLoser: p2IsLoser,
            showName: _showPlayer2Name,
            isTopPlayer: false,
            onTap: () {
              setState(() {
                _showPlayer2Name = !_showPlayer2Name;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget({
    required String? name,
    required String? avatar,
    required int? score,
    required bool isWinner,
    required bool isLoser,
    required bool showName,
    required bool isTopPlayer,
    required VoidCallback onTap,
  }) {
    final displayName = name ?? 'bye'.tr();

    final Color borderColor = isWinner
        ? AppColors.success
        : isLoser
            ? AppColors.danger
            : AppColors.neonBlue;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardBackground,
                  border: Border.all(
                    color: borderColor,
                    width: isWinner || isLoser ? 2.5 : 1.5,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isWinner || isLoser ? 1.5 : 0),
                  child: ClipOval(
                    child: avatar != null && avatar.isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                ),
              ),
              if (score != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isWinner
                          ? AppColors.success
                          : isLoser
                              ? AppColors.danger
                              : AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black, width: 0.8),
                    ),
                    child: Text(
                      '$score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showName)
          Positioned(
            bottom: isTopPlayer ? 42 : null,
            top: !isTopPlayer ? 42 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isWinner
                        ? AppColors.success
                        : isLoser
                            ? AppColors.danger
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: isWinner
                        ? AppColors.success
                        : isLoser
                            ? AppColors.danger
                            : AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.mutedBackground,
      child: const Icon(
        TablerIcons.user,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}
