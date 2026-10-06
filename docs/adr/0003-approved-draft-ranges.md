# Schválený AI draft určuje čas Tasku, nie priradenie Activities

Activity patrí vždy len jednému Tasku. Keď sa dva drafty časovo prekrývajú (súbežná práca: agent robí na A, používateľ medzitým na B), schválenie oboch cez priradenie Activities nefungovalo: neskôr schválený draft si Activities prevzal a prvý Task o svoj čas prišiel. Rozhodli sme sa, že schválením sa rozsahy draftu uložia k Tasku (`task_range`) a do momentu schválenia (`task.ranges_until`) sú jeho jediným nameraným časom. Po tomto momente sa Task ďalej počíta zo živých dát (Activities, behy Claude Session, Meetingy), aby sa nestratila práca, ktorá pokračuje. Activities sa pri schválení naďalej priraďujú, ale už len kvôli projektu a zvýrazneniu v Memory.

## Consequences

- Súbežné Tasky si držia svoj čas; ich prekryv v rámci jedného Projectu sa v Project Time zjednotí, medzi Projectmi rieši Overlap Policy.
- Nové „Summarize day“ a schválenie rozsahy Tasku prepíše; staré rozsahy sa nesčítavajú.
- Task schválený pred touto zmenou rozsahy nemá a počíta sa ako predtým, kým sa deň znova neschváli.
