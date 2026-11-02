# Timetracker

Menu bar appka pre macOS, ktorá automaticky zaznamenáva, na čom kontraktor práve pracuje, a z toho skladá výkaz pre fakturáciu.

## Language

### Zber

**Activity**:
Súvislý časový úsek, počas ktorého bolo v popredí to isté okno (appka + titulok okna + URL v Chrome). Surové dáta, nič sa v nich neinterpretuje.
_Avoid_: segment, event, záznam, memory

**Claude Session**:
Jedna konverzácia s Claude Code, identifikovaná session id a cwd. Beží od promptu po Stop; kým beží, čas sa počíta jej Projectu aj bez vstupu používateľa.
_Avoid_: inštancia, agent

**Prompt**:
Text, ktorý používateľ poslal do Claude Session. Najsilnejšia nápoveda o tom, čo sa v Projecte rieši.

**Session Summary**:
Jedna veta o tom, čo je jadrom celej Claude Session. Ignoruje úvodné odbočky aj záverečné meta-prompty („urob review", „commitni"). Jedna session má jednu vetu, ktorá sa s pribúdajúcimi Promptami spresňuje. Titulok Claude Code z prvého Promptu sa použije len keď niečo hovorí (aspoň 3 slová, nie otázka ani „Attached screenshot", nemenuje iný Project), inak vetu napíše on-device model zo všetkých správ.
_Avoid_: názov session, titulok

**Branch**:
Git vetva v cwd v čase udalosti. Len slabá nápoveda pre Task, lebo vetvy často vznikajú až na konci práce.

**Shell Command**:
Príkaz spustený v termináli, s cwd a časom.

**Meeting**:
Úsek, počas ktorého prebieha hovor v Teams alebo udalosť z pracovného kalendára. Počíta sa ako práca aj bez vstupu používateľa. Project dostane z Keywordu alebo názvu Projectu v názve meetingu, inak podľa toho, kam používateľ presunul skorší meeting s rovnakým názvom, inak je to jediný fakturovateľný Project; pri viacerých fakturovateľných Projectoch ostáva No Project, kým ho používateľ nepriradí. Udalosť z pracovného kalendára, ktorú tracker nezachytil (osobný meeting, Mac idle alebo uspaný), sa ponúkne ako draft na potvrdenie.

**Idle**:
Stav bez vstupu z klávesnice a myši dlhší než nastavená hranica, keď zároveň nebeží žiadna Claude Session ani Meeting. Čas v Idle sa nepočíta nikomu.
_Avoid_: nečinnosť, AFK

### Priradenie

**Project**:
Kontext, do ktorého sa čas priraďuje. Zakladá ho len používateľ v Settings (názov, popis, Keywords, voliteľne priečinok). Prázdny popis appka vygeneruje z README priečinka, Taskov, okien a Corrections; používateľ ho môže prepísať alebo vygenerovať znova. Activity ho dostane z istého signálu (pravidlo, názov Projectu alebo Keyword v titulku či URL), Claude Session z priečinka Projectu (worktree patrí hlavnému repu); zvyšok rozhodne Classification. Fakturovateľný Project má Rate, ostatné sú osobné.
_Avoid_: workspace, repo, klient

**Classification**:
Priebežné (každých 20 minút) priradenie Activities a Claude Sessions bez istého signálu k Projectom cez AI podľa názvu, popisu, Keywords, priečinka a Corrections. Výsledok je Project, práca bez Projectu alebo osobné; okná bez Projectu ostávajú nepriradené, Claude Session bez Projectu je No Project Task. Ručne priradené nikdy nemení.
_Avoid_: guess, auto-assign

**Correction**:
Ručné priradenie Activity alebo Tasku k Projectu (alebo „No project“). Najnovšie Corrections dostáva Classification aj AI zhrnutie ako vzory, takže sa priraďovanie učí z používateľa. Presun Tasku Claude Session platí aj pre ďalšie Sessions s rovnakým Session Summary a presun meetingu pre ďalšie meetingy s rovnakým názvom.
_Avoid_: feedback, training

**No Project**:
Task Claude Session (alebo draftu) bez Projectu: práca, ktorej Project sa nedal určiť. Okná bez Projectu Task netvoria. Sessions v systémovom temp priečinku (headless `claude -p` iných appiek, napr. Superset) sa ignorujú. Používateľ mu Project priradí ručne; opakovaný No Project je signál, že Project treba založiť.
_Avoid_: Unassigned task, General

**Keyword**:
Slovo, ktoré jednoznačne identifikuje Project v titulku okna, URL, názve konverzácie alebo meetingu (napr. „acme", „Jane"). Istý signál rovnocenný s názvom Projectu.

**Project Time**:
Zjednotenie všetkých úsekov, počas ktorých bol Project „v hre" (okno v popredí, bežiaca Claude Session, Meeting). Časy rôznych Projectov sa môžu prekrývať a neodčítavajú sa.

**Gap**:
Diera medzi dvoma úsekmi Project Time toho istého Projectu kratšia než 30 minút. Zavrie sa automaticky: Project Time ju počíta, Tasky nie.
_Avoid_: pauza, medzera

**Break**:
Diera v Project Time dlhá 30 až 90 minút (obed). Appka ju ponúkne a používateľ rozhodne, či sa fakturuje; predvolene nie. Dlhšia diera je koniec práce a nič sa s ňou nerobí.
_Avoid_: prestávka, lunch, gap

**Day Start**:
Používateľom zadaný čas začiatku práce na Projecte v daný deň. Prvý úsek Project Time sa natiahne dozadu k nemu; nameraný čas Taskov sa nemení.
_Avoid_: start time, začiatok

**Task**:
Pomenovaná skupina Activities a Promptov v jednom Projecte („import súboru", „autentifikácia"). Vzniká až pri tvorbe Reportu, používateľ ju môže premenovať alebo presunúť. Zmazanie Tasku znamená „toto nie je práca“: jeho Activities stratia Project natrvalo a jeho Claude Session už Task nevytvorí.
_Avoid_: ticket, issue, feature

**Tracked**:
Čas, ktorý appka nameria sama z Activities, Claude Sessions a Meetingov. Predvolený pôvod každého času.
_Avoid_: automatický, z dát, z appky

**Manual**:
Čas, ktorý vznikol zásahom používateľa: Manual Entry alebo Adjustment. Appka ho vždy zobrazuje odlíšený od Tracked, Report ich sčíta bez rozlíšenia.
_Avoid_: ručný, edited, upravený

**Manual Entry**:
Úsek času, ktorý používateľ zadal ručne (od–do, Project, popis). Je už interpretovaný, AI ho nepreskupuje.

**Adjustment**:
Ručná zmena hodín Tasku o kladný alebo záporný rozdiel (z 5 h na 7 h = +2 h), s voliteľnou poznámkou. V appke je viditeľný ako odlíšený od nameraného času, v Reporte je už len výsledná hodnota.
_Avoid_: korekcia, natiahnutie, override

### Zobrazenie

**Memory**:
Ľavý stĺpec Day: jedna karta = jedna appka v jednom Projecte počas súvislého úseku, aj keď sa medzitým prepínalo inam. Karty prekrývajúce sa v čase stoja vedľa seba, krátke sa skryjú. Nič sa v ňom neinterpretuje, len priraďuje.
_Avoid_: history, log, aktivity

**Agent**:
Stredný stĺpec Day na tej istej časovej osi: kedy pracoval agent Claude Session a na akom Tasku, aj keď bolo v popredí iné okno.
_Avoid_: lane, swimlane

**Timesheet**:
Pravý stĺpec Day na tej istej časovej osi: Tasky, AI drafty a Breaky, teda to, čo pôjde do Reportu. Task je rozdelený na úseky podľa skutočného času (medzery do 10 min sa spoja), súbežné úseky stoja vedľa seba. Čakajúci draft nahrádza Task, ktorý by prepísal. Výber Tasku zvýrazní jeho Memory.
_Avoid_: entries, zoznam

### Výkaz

**Rate**:
Hodinová sadzba fakturovateľného Projectu v EUR.

**Overlap Policy**:
Nastavenie, ako Report naloží s časom, keď sa prekrývajú dva fakturovateľné Projecty: „Bill both" (každý dostane plný čas, predvolené) alebo „Exclusive" (prekryv dostane Project v popredí).

**Rounding**:
Zaokrúhlenie hodín vo výkaze (15 alebo 30 minút). Uložené dáta zostávajú presné.

**Report**:
Výkaz za obdobie: dni → Tasky s hodinami → súčet hodín a suma podľa Rate.
_Avoid_: timesheet, faktúra, výpis

**Excel Export**:
Report všetkých fakturovateľných Projectov za obdobie ako .xlsx pre klienta: riadok = deň × Project (dátum, deň v týždni, zaokrúhlené hodiny, Project, Work performed), súčet na konci. Work performed sú názvy 1–3 najdlhších Taskov dňa; „General" len keď nie je nič iné.
_Avoid_: xlsx report, sheet
