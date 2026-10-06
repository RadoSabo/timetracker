# Project Time sa medzi Projectmi neodčítava

Tracker má viac zdrojov času naraz (okno v popredí, bežiace Claude Sessions, Meeting), takže dva Projecty môžu byť „v hre" v tom istom okamihu. Rozhodli sme sa, že Project Time každého Projectu je zjednotenie jeho vlastných úsekov a medzi Projectmi sa nič neodčítava: 5 h na klientovi s 2 h osobného projektu uprostred je stále 5 h pre klienta. Alternatívou bola exkluzívna timeline (každý okamih patrí jednému Projectu), ktorá by stratila čas, ktorý Claude reálne odpracoval na klientovi, kým používateľ robil inde.

## Consequences

- Súčet Project Time za deň môže presiahnuť skutočný čas pri Macu; UI to ukazuje ako prekryv, nie ako chybu.
- Fakturácia prekryvu dvoch fakturovateľných Projectov je vec Reportu (Overlap Policy), nie dát. Zmena politiky nikdy nemení uložené Activities.
- Zdvojenie v rámci jedného Projectu nehrozí z definície (zjednotenie), takže dve paralelné Claude Sessions na tom istom Projecte dajú čas len raz.
