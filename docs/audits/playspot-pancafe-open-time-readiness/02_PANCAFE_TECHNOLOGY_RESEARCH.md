# PanCafe technology research

Sources: [official features](https://www.pancafepro.com/?page=features), [official download](https://www.pancafepro.com/?page=download), [official changelog](https://go.pancafepro.com/?page=changelog), [terms](https://go.pancafepro.com/?page=terms). Public pages were reviewed on 2026-10-22. These are vendor claims, not a lab validation.

| Claim | Evidence | Classification |
| --- | --- | --- |
| Current public download is PanCafe Pro 3.3.2; Windows 7/8.1/10/11, 32/64 bit listed | Download page | CONFIRMED as published |
| Separate server/client software, terminal control, timed and indefinite sessions, tariffs, cashier accounts, stock and reports | Features/download pages | CONFIRMED as published |
| PC monitoring, restrictions, Wake-on-LAN and messaging | Features page | CONFIRMED as published; precise enforcement not lab tested |
| Local Windows/LAN operation | Server/client descriptions and download requirements | STRONGLY INDICATED; topology and offline guarantees UNKNOWN |
| PlayStation tariff support | Changelog | CONFIRMED as published; console/electrical control UNKNOWN |
| Free base license | Download page | CONFIRMED as published; premium feature terms vary |
| Programming language, framework, database, wire protocol, encryption, authenticated API, webhook/SDK | No specification in reviewed official pages | UNKNOWN |
| Public documented integration API | None found in reviewed official resources | UNKNOWN; no public API documented in reviewed pages |
| Electrical monitor/console power control | No verified supported hardware/control contract | UNSUPPORTED as an implementation claim |

The download page lists a default administrator credential; deployment procedures should replace defaults, without reproducing the value here. The published translation list includes Arabic and English. The public information does not establish multi-cashier concurrency semantics, shift reconciliation guarantees, or inventory synchronization contracts. A vendor inquiry, written API documentation, sandbox, permission model and terms review are prerequisites to a PanCafe adapter. Proprietary assets and private protocols are out of scope.

Open-source references (concepts only; no code was copied):

| Project | License and maintenance | Architecture/relevance | Reuse decision |
| --- | --- | --- | --- |
| [cool-cafe](https://github.com/imransaadullah/cool-cafe) | README says MIT; repository metadata did not confirm license; latest observed default-branch commit 2026-07-21 | FastAPI/Prisma/Postgres server, Vue UI, PyQt6 client, WebSocket; useful local/client separation | LICENSE verification and security audit needed; no reuse now |
| [Posnic/POS](https://github.com/Posnic/POS) | AGPL-3.0; observed commit 2026-10-21 | Node/Mongo/Electron offline-first cashier pattern, not terminal enforcement | AGPL compliance and technical review required; no reuse |
| [simple-cybercafe-server](https://github.com/farizluqman/simple-cybercafe-server) / [client](https://github.com/farizluqman/simple-cybercafe-client) | Apache-2.0 listed; server observed 2014 commit | VB.NET server/client example; README notes incomplete modules | Historical concept only; not a maintained foundation |
| [Mkahawa](https://mkahawa.sourceforge.net/index.php) | Project site; historical C/C++ cybercafe system | Server/client and billing concepts | License/dependencies/current security must be verified before reuse |

No official PanCafe GitHub repository was verified in this review. Security limitations above are due-diligence gaps, not claims of a vulnerability in those projects. See [feature comparison](03_PANCAFE_FEATURE_COMPARISON.md).
