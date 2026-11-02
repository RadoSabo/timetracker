# Projekty zakladá len používateľ, priradenie robí AI

Projekty vznikali samé z každého cwd Claude Session a shellu (git root). Vznikol tak Project z domovského priečinka aj z dočasných worktree. Ich názvy sa potom ako Keyword chytali v titulkoch a URL: profil `malt.be/profile/radoslavsabo` tak skončil v Projecte `radoslavsabo`. Git root zároveň nevie zaradiť prácu mimo terminálu, napríklad googlenie infraštruktúry pre migračný Project.

Rozhodli sme sa, že Project zakladá len používateľ v Settings: názov, popis, Keywords a voliteľne priečinok. Isté signály (pravidlo, Keyword, priečinok Projectu) platia hneď. Zvyšok každých 20 minút posúdi Classification cez `claude -p` (sonnet) podľa popisov Projectov a posledných Corrections. Čo nesedí na žiadny Project, zostane bez Projectu: Claude Session ako No Project Task, okná ostanú nepriradené surové dáta (Task „No project · General“ nič nehovorí). `task.project_id`, `draft.project_id` a `manual.project_id` preto môžu byť NULL.

## Consequences

- Volanie `claude -p` každých 20 minút, ale len keď pribudlo niečo nepriradené. Pred prvou Classification je nová práca chvíľu nepriradená.
- Ručne priradená Activity (`user_set`) sa už nikdy automaticky nemení; zmazaný Task jej Project odoberie natrvalo.
- Zmena Projectu (nový, iný popis, Keywords, priečinok) vráti dnešné AI rozhodnutia bez Projectu na nové posúdenie.
- Staré automaticky založené Projecty zostávajú, kým ich používateľ nezmaže; ich čas sa vráti do nepriradeného, Claude Sessions a Manual čas zostanú ako No Project.
- Prázdny popis Projectu sa pred Classification vygeneruje cez `claude -p` z toho, čo o Projecte vieme, a odlíši ho od ostatných Projectov. Nový Project bez dát dostane popis až keď k nemu niečo pribudne, dovtedy ho píše používateľ.
- Návrhy nových Keywords z opakovaných Corrections zatiaľ nie sú; Corrections idú do promptu priamo.
