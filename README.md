# Active Directory School Manager
### Ez a PowerShell szkript a magyar iskolák Active Directory rendszerének kezelésére szolgál, lehetővé téve a diákok rendszerezését és az évfolyamok léptetését.
Fő jellemzők:
* Diákok hozzáadása, törlése, jelszavak visszaállítása
* Diákok saját mappáinak beállítása
* Osztályok csoportjainak beállítása
* Az *Active Directory: Felhasználók és számítógépek* ablakban a diákok szervezeti egységekben (organizational unit) való rendezése
* **Évfolyamok léptetése**
## Tartalomjegyzék
- [Telepítés](#telepítés)
- [Használat](#használat)
- [Funkciók](#funkciók)
- [Galéria](#galéria)
- [Hibakeresés](#hibakeresés)
- [Támogatás](#támogatás)
## Telepítés
1. Letöltöd a repóból a szkriptet és futtatod. A szkript a [Sebazzz/PSMenu](https://github.com/Sebazzz/PSMenu) kódot használja a menü megjelenítéséhez, és azt, valamint a telepítéshez szükséges NuGet csomagkezelőt magától telepíti.
2. A *Konfiguráció beállítása* segítségével beállítod a konfigurációt. Segítség lejjebb.
3. A szkript alapból 7-12 évfolyamokra, és A; B; C osztályokra van beállítva, és egy D osztályra a 9. évfolyamtól. Ezek egyszerűen átállíthatóak, illetve ha a D osztályos funkcióra nincs szükség, akkor egy nagy számra állítsd át az *Global:OtherClassFrom* változóban. Állíthatod még a konfigurációs fájl nevét, és a diákok kezdőmappájának betűjelét.
4. Generáld le a mappákat, csoportokat, és szervezeti egységeket.
5. Add hozzá a diákokat.
## Használat
A funkciók egy menürendszeren keresztül érhetők el. Indítás után válaszd ki a megfelelőt:
1. Diákok hozzáadása
2. Diák jelszavának visszaállítása
3. Diákok felsőbb évfolyamba léptetése
4. Diák törlése
5. Almenü
6. Kilépés

Az almenüben találhatóak (ezeket csak egyszer kell megcsinálni):
1. Konfiguráció beállítása
2. Mappák generálása
3. Csoportok generálása
4. Szervezeti egységek (OU) generálása

Minden menüponthoz tartozó részletes leírást alább találsz.
## Funkciók

- **Konfiguráció beállítása**: beállítod vele a szkriptnek szükséges dolgokat. Úgymint:
  - Domain: a tartomány domainneve. (pl. iskola.hu)
  - Szervernév: a szerver neve, amin fut a szkript. (pl. DC1)
  - Gyökérmappa: a diákok saját mappáinak a gyökérmappája. (pl. C:\DIAKOK) Ezen belül vannak az évfolyamok (pl. 7-12), és azokon belül az osztályok (pl. A; B; C). A mappa engedélyeit és a megosztást neked kell beállítani, a következők szerint:
    - Tulajdonságok &#8594; Biztonság &#8594; Speciális &#8594; Öröklődés letiltása (*Az örökölt engedélyek kifejezett engedélyekké való konvertálása*); *Felhasználók: Olvasás és végrehajtás* eltávolítása
    - Tulajdonságok &#8594; Megosztás &#8594; Speciális megosztás &#8594; Mappa megosztása &#8594; Engedélyek:
      - Mindenki: Olvasás
      - Tartományfelhasználók: Teljes hozzáférés
    - Ezek biztosítják, hogy a diák csak a saját mappáját láthassa, és a másokét nem.
  - Megosztott gyökérmappa (pl. DIAKOK): az előbb tárgyalt gyökérmappa megosztott neve. Ha nem állítottad át, akkor a gyökérmappa nevét írd be.
  - Csoport: a csoport neve, amiben a diákok lesznek (pl. Diak)
  - Gyökér OU az *Active Directory: Felhasználók és számítógépek* ablakban: az a szervezeti egység (OU), ahol a diákok lesznek tárolva, akárcsak a gyökérmappában. (pl. DIAKOK) Ezt neked kell létrehozni, és kapcsold ki a Véletlen törlés elleni védelmet! Ha rögtön a domainneven belül van, akkor csak a nevét írd be. De ha pl. a VALAMI&#8594;MÁSIK&#8594;DIAKOK az "elérési út", akkor a VALAMI\MÁSIK\DIAKOK-at írd be.
  - Alapértelmezett jelszó: az újonnan regisztrált diákok jelszava, amit az első bejelentkezéskor meg kell változtatniuk. (pl. 12345678). Ha ehhez hasonló jelszót akarsz használni, akkor meg kell változtatni a jelszóházirendet, amit ÍGY------------------------------------------------ tehetsz meg.
- **Mappák generálása**: legenerálja az évfolyam- és osztálymappákat a gyökérmappában.
- **Csoportok generálása**: minden osztálynak csinál saját csoportot, illetve egyet, amiben minden diák benne van.
- **Szervezeti egységek (OU) generálása**: legenerálja a szervezeti egységeket, ahol a diákok lesznek évfolyamonként, azon belül pedig osztályonként.
- **Diákok hozzáadása**: a megadott osztályhoz ad hozzá diákokat. Ha Entert nyomsz (tehát üres nevet írsz be), akkor visszalép a menübe.
- **Diák jelszavának visszaállítása**: a megadott diáknak visszaállítja a jelszavát.
- **Diákok felsőbb évfolyamba léptetése**: eggyel magasabb évfolyamba lépteti a diákokat mindenükkel együtt, a legnagyobbaknak (pl. 12-esek) pedig mindenét törli. Ez talán a leghasznosabb funkció.
- **Diákok törlése csoport alapján**: törli az összes, a megadott csoportban található diákot és mappájukat. A _*_ minden diákot töröl.
- **Diák törlése név alapján**: törli a megadott diákot és mappáját.
## Galéria
## Hibakeresés
A szkript csak helytelen konfiguráció és/vagy helytelen bemeneti adatok esetén ad hibát. Ellenőrizd, hogy a konfiguráció és a bemeneti adatok helyesek-e.
## Támogatás
Ha bármilyen kérdésed van, nyiss egy issue-t, vagy írj emailben: [parancsmester@gmail.com](mailto:parancsmester@gmail.com?subject=Active-Directory-School-Manager).
