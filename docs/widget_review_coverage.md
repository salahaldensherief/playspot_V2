# Widget review coverage — 2026-10-07

This records **automated inventory** separately from **targeted manual review**. It does not certify a widget-by-widget review or issue-free runtime behavior.

Baseline `45d967b`: 566 Dart files under `lib`; 262 classes explicitly extending StatelessWidget/StatefulWidget. Counts use text patterns, not an AST, and exclude other widget base classes. They describe the baseline, not runtime builds or final class counts.

Every feature received automated checks for widget/state declarations, setState, periodic timers, network images, shrink-wrapped lists, intrinsic layout and local controller creation. No flags does not prove correctness.

| Feature | Dart files | Widget classes | Coverage |
| --- | ---: | ---: | --- |
| active_session | 55 | 17 | Automated inventory plus targeted manual paths; not the whole feature |
| app_status | 18 | 7 | Automated inventory plus targeted manual paths; not the whole feature |
| auth | 35 | 17 | Automated inventory plus targeted manual paths; not the whole feature |
| booking | 37 | 10 | Automated inventory; no complete manual feature review claimed |
| checkout | 14 | 15 | Automated inventory plus targeted manual paths; not the whole feature |
| core/shared | 154 | 60 | Automated inventory plus targeted manual paths; not the whole feature |
| favorites | 6 | 1 | Automated inventory; no complete manual feature review claimed |
| home | 37 | 19 | Automated inventory plus targeted manual paths; not the whole feature |
| lounge_details | 78 | 58 | Automated inventory; no complete manual feature review claimed |
| main | 1 | 1 | Automated inventory; no complete manual feature review claimed |
| my_bookings | 34 | 13 | Automated inventory plus targeted manual paths; not the whole feature |
| notifications | 9 | 3 | Automated inventory; no complete manual feature review claimed |
| onboarding | 1 | 1 | Automated inventory; no complete manual feature review claimed |
| profile | 36 | 21 | Automated inventory; no complete manual feature review claimed |
| search | 3 | 1 | Automated inventory; no complete manual feature review claimed |
| splash | 1 | 1 | Automated inventory; no complete manual feature review claimed |
| tournaments | 47 | 17 | Automated inventory plus targeted manual paths; not the whole feature |

## Candidate contexts inspected

The following flagged construction/layout contexts were inspected. This is not complete screen/data-flow review. Dynamic nested lists still need large-data profiling; a shrinkWrap flag alone is not justification for replacing a layout with Expanded. Fixed KPI grids, capped top lounges/review cards and constrained scrollable dialogs were retained. Intrinsic timeline/schedule rows equalize neighboring heights; their cost needs measurement.

| Path | Original inventory flags |
| --- | --- |
| `lib/features/auth/presentation/forgot_password/otp_verification_screen.dart` | timer_rebuild |
| `lib/features/tournaments/presentation/tournament_details/widgets/tournament_rules_card.dart` | shrink_wrap |
| `lib/features/tournaments/presentation/tournament_details/widgets/tournament_prizes_tab.dart` | shrink_wrap |
| `lib/features/home/presentation/widgets/promo_card.dart` | network_decode_size |
| `lib/features/home/presentation/widgets/tournament_promo_card.dart` | network_decode_size |
| `lib/features/profile/presentation/profile/widgets/loyalty_missions_section.dart` | shrink_wrap |
| `lib/features/my_bookings/presentation/widgets/booking_card.dart` | timer_rebuild |
| `lib/features/my_bookings/presentation/widgets/booking_timeline_widget.dart` | intrinsic_layout, shrink_wrap |
| `lib/features/my_bookings/presentation/widgets/booking_receipt_dialog.dart` | network_decode_size |
| `lib/features/checkout/presentation/widgets/checkout_voucher_picker_tile.dart` | shrink_wrap |
| `lib/features/app_status/presentation/widgets/announcement_dialog.dart` | network_decode_size |

## Follow-up fixes

Fill-width thumbnails now use bounded parent width for decode sizing, including explicit double.infinity. Home promotion, tournament promotion, announcement and receipt thumbnails reuse AppImage. Outer clipping, placeholders/errors and uncapped receipt zoom are preserved. A decode regression tests bounded fallback, finite overrides and invalid widths. BookingCard upcoming state was traced to server status; its timer already cancels on booking change/disposal, so it was retained. OTP timer/controller cleanup and checkout voucher/hold ownership were also traced.

## Verification limits

Flutter CI runs analysis, the full automated tests and release compilation. Physical-device/browser CPU/GPU profiling and retained-heap measurements are unavailable locally. Every screen's appearance, every live role/backend flow and all duplicated UI have **not** been exhaustively verified. See [performance_architecture_audit.md](performance_architecture_audit.md) for the profiling procedure and earlier changes.
