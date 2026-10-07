# Performance and lifecycle review

This review inspected rebuild boundaries, image decoding, timer/subscription ownership and asynchronous races. It is not a physical-device CPU, GPU or retained-heap measurement.

| Area | Finding and change | Verification |
| --- | --- | --- |
| Home/session countdowns | Replace independent periodic timers with `AppClock` and `AppClockBuilder`; nested scopes share one active timer. Stop when `TickerMode` disables the screen or the app leaves the foreground. | Widget tests count clock reads and static/live builds, exercise hide/resume and disposal. |
| Session rendering | Keep the countdown update inside its repaint boundary. Remove timer state and Bloc listener side effects from `TimerSection`. The home banner listens only to fields it renders. | Existing session visual/domain tests plus clock tests. |
| Network images | Decode network thumbnails using bounded layout width and actual device pixel ratio, capped at 2048 pixels wide. Set only width to preserve image aspect ratio; zoom opens an uncapped image. | Pure decode-size boundary tests. This caps width, not total image bytes or an unusually tall image's height. |
| Connectivity | Initialization is idempotent. Late initial checks cannot overwrite a newer network event or a disposed service. | Delayed-response regression tests. The service reports network interfaces, not verified internet reachability. |
| Referral links | Remove the unused authentication subscription and Supabase dependency. URI/referral parsing remains in its own service. | Analyze and existing authentication/router tests. |
| Live session ownership | Extract `ActiveSessionWatcher` from the remote data source. Serialize refresh/channel replacement, invalidate old-account results and stop channel creation after cancellation. Resources start on listening. | Cancel-during-fetch regression with a late session response. |

The architectural changes apply single responsibility and injected dependencies at real boundaries: clock ownership versus clock consumers, image decode policy versus presentation, and subscription ownership versus RPC hydration. Existing Cubit/repository contracts and server authority remain intact. No universal repository or placeholder strategy was introduced.

Other inspected paths include home location listeners, active-session Cubit cleanup, notification subscriptions and lazy lounge/room lists. A singleton lasting for the application's lifetime is not by itself a leak. Large files such as tournament details, menu editing and payment proof UI still contain distinct concerns; their size alone is not evidence that an additional interface or pattern would improve them. This change does not claim that every duplicate across the repository has been removed.

## Physical-device verification still required

Run `flutter run --profile` on a representative Android device. In DevTools, record repeated home → lounge → session → home navigation, a long image list scroll, image zoom, app background/resume and session end/extension. Inspect frame build/raster durations and the widget rebuild tracker separately. Take memory snapshots after warm-up and after repeated navigation; compare retained controllers, channel listeners and image allocations after GC. Record device, Flutter version, image set, route sequence and sample duration before claiming an FPS or memory reduction.

Use the repository's Flutter CI for analysis, the complete test suite and Android release compilation. `Dart formatting review` produces a formatting patch without writing to the branch, which supports environments where the local Dart VM cannot run.
