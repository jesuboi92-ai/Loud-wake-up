# Loud Wake Up 🚨

Flutter-herätyskello iOS:lle, jossa on 21 kovaäänistä herätysääntä (sireenit, klaksonit, hälyttimet, wobble, mega-sekoitus…).
Äänet on generoitu synteettisesti (`tools/generate_sounds.py`), joten ne ovat vapaasti käytettäviä.

## Ominaisuudet
- Useita herätyksiä, valinta ääni kerrallaan (esikuuntelu ▶) tai 🎲 satunnainen ääni
- Äänenvoimakkuus pakotetaan maksimiin (`volumeEnforced`), värinä päällä
- Toisto joka päivä, torkku 5 min, pyyhkäise herätys pois listasta
- Toimii taustalla ja lukitulla näytöllä (`alarm`-paketti)

## Käyttöönotto
iOS-sovelluksen rakentaminen vaatii Macin + Xcoden (tai pilvi-CI:n, esim. Codemagic).

```bash
# 1. luo iOS-projekti olemassa olevan koodin ympärille
flutter create --platforms=ios --org fi.example --project-name loud_wake_up .
# 2. lisää taustaäänitila (UIBackgroundModes) ja iOS 14 -minimi
python tools/patch_ios.py
# 3. aja
flutter pub get
flutter run --release
```

Halutessasi voit luoda äänet uudelleen: `python tools/generate_sounds.py` (tarvitsee numpy:n).

## Tärkeää iOS:n rajoituksista
- iOS ei salli kolmannen osapuolen sovelluksille oikeaa herätystä samalla tavalla kuin kellosovellukselle.
  Paketti pitää sovelluksen hengissä taustalla. **Älä pyyhkäise sovellusta pois** moniajosta yöksi.
  Jos sen tappaa, tulee vain tavallinen ilmoitusääni (`warningNotificationOnKill` muistuttaa tästä).
- Hiljainen-tila-kytkin ja Älä häiritse -tila voivat vaimentaa ilmoituksia. Pidä puhelin latauksessa ja testaa herätys ennen kuin luotat siihen (aseta ensin herätys 1–2 min päähän).
- Äänet ovat oikeasti kovia. Älä testaa kuulokkeet korvilla.
