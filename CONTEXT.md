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
Jedna veta o tom, čo je jadrom celej Claude Session. Ignoruje úvodné odbočky aj záverečné meta-prompty („urob review", „commitni"). Jedna session má jednu vetu, ktorá sa s pribúdajúcimi Promptami spresňuje.
_Avoid_: názov session, titulok

**Branch**:
Git vetva v cwd v čase udalosti. Len slabá nápoveda pre Task, lebo vetvy často vznikajú až na konci práce.

**Shell Command**:
Príkaz spustený v termináli, s cwd a časom.

**Meeting**:
Úsek, počas ktorého prebieha hovor v Teams alebo udalosť z pracovného kalendára. Počíta sa ako práca aj bez vstupu používateľa a patrí fakturovateľnému Projectu.

**Idle**:
Stav bez vstupu z klávesnice a myši dlhší než nastavená hranica, keď zároveň nebeží žiadna Claude Session ani Meeting. Čas v Idle sa nepočíta nikomu.
_Avoid_: nečinnosť, AFK

### Priradenie

**Project**:
Kontext, do ktorého sa čas priraďuje; Activity ho dostane len z istého signálu (pravidlo, názov Projectu alebo Keyword v titulku či URL), inak ostáva Unassigned pre AI zhrnutie; stotožnený s koreňom git repozitára (cwd v podpriečinku patrí tomu istému Projectu). Fakturovateľný Project má Rate, ostatné sú osobné.
_Avoid_: workspace, repo, klient

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
Pomenovaná skupina Activities a Promptov v jednom Projecte („import súboru", „autentifikácia"). Vzniká až pri tvorbe Reportu, používateľ ju môže premenovať alebo presunúť.
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
