# Mobile profile localization

User-reported untranslated profile screen: Mobile.

Corrected hardcoded English in My Rewards: free-hour/discount labels, used,
expired and valid-until dates and remaining days. Dates use current locale;
missing dates no longer throw. Copy feedback uses the application's toast.

Points history uses localized canonical transaction titles instead of treating
an English server description as the translated title. Explicit localized
description fields still take precedence; unknown custom user content is
preserved. Standard loyalty level names translate in both directions without
changing server identifiers or reward amounts.

Validation: profile analyze has no issues; five focused tests passed, including
Arabic/English voucher rendering and preservation of fractional discounts.
Additional assertions verify switching locale while the screen is mounted,
unknown custom descriptions and absent expiry dates.

Audit of AppStrings references in profile presentation found their Arabic and
English keys present (continueText is an alias rather than a missing key).
This is not a claim that arbitrary server-authored content has been translated
or that all production profile flows were tested on an emulator.
