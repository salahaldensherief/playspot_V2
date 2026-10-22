# Live Operations implementation

**SOURCE REVIEWED / MOCK TESTED.** Dashboard change set:

- `StationOperationalState` builds a read-only, lounge-scoped station projection from existing rooms, bookings and requests. Duplicate active bookings are flagged for manual review, and the grid does not open a cashier action from that conflicted card. It does not grant inventory authority.
- `StationOverviewGrid` adds dense responsive cards, search and attention/availability filters, elapsed/remaining cues, next reservation, payment state and explicit authority notice. It opens the existing station controls instead of inventing new actions.
- `LiveBookingsFeed` supplies room state when available and preserves the session-only fallback where `RoomCubit` is absent.
- Open Time start dialog previews the stored room configuration and says the server owns the final rate; active room card no longer shows a false 0 EGP.
- Expired-session scheduler now alerts only. Previously a paid fixed booking could be moved to `completed` through generic `update_booking_status_admin`, bypassing canonical close. The regression test proves no status mutation by this scheduler.

Audio currently uses one notification asset/service path; meaningful distinct tones and preference/browser permission verification are **NOT IMPLEMENTED**. The room list does not prove physical device connection. These changes should remain draft until visual and integrated tests complete. See [test results](12_TEST_RESULTS.md) and [risks](14_SECURITY_AND_RISK_REGISTER.md).
