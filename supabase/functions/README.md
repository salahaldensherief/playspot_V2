# Canonical PlaySpot Edge Function source

Mobile/Backend owns the server migration and Edge Function source. These functions
were preserved byte-for-byte from Dashboard dev `6113da82da43b8630f042b3be30e3cfeaf2560fd`
during 31 October dev consolidation. Existing Dashboard copies remain historical
references to avoid destructive removal; future server changes belong here.
Dashboard SQL is likewise a frozen legacy reference, enforced by its existing CI
guard. Never apply both repositories' SQL or deploy both copies independently.

Node contract tests exercise extracted handlers with fixtures; they do **not**
prove Deno/runtime deployment, external FCM delivery or hosted compatibility.
The disposable dev stack deliberately has Edge runtime disabled until its module
cache, integration configuration and outbound isolation are independently verified.
Copying this source introduces no hosted deployment command or automatic deploy.
