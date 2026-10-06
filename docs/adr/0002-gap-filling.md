# Diery v Project Time sa zatvárajú na úrovni Projectu, nie Tasku

Striedanie okien, krátke odbočky a chvíle bez istého signálu robia v dni samé diery, hoci práca prebiehala súvisle. Rozhodli sme sa, že Project Time sa tvaruje až pri výpočte: Gap (< 30 min) sa zavrie sám, Break (30–90 min) sa ponúkne a fakturuje len na pokyn, Day Start natiahne prvý úsek dozadu. Všetko sa deje nad zjednotením úsekov Projectu; namerané intervaly Taskov, Activities ani Sessions sa nemenia a v DB ostávajú presné. Alternatívou bolo prideliť dorovnaný čas predchádzajúcemu Tasku, čo by ale zmiešalo namerané s odhadnutým v hodinách Tasku.

## Consequences

- Súčet hodín Taskov je menší než Project Time dňa; Report fakturuje Project Time, Tasky sú opis práce.
- Prahy 30 a 90 minút sú konštanty v `Settings`; Break je identifikovaný začiatkom, posun diery po novej aktivite zabudne voľbu fakturácie.
- Vo Ribbone je dorovnaný čas bledý (30 % farby Projectu), namerané bloky ostávajú plné.
