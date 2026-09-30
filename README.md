# Loud Wake Up 🚨

Flutter-herätyskello iOS:lle, jossa on 445 kovaäänistä herätysääntä (sireenit, huudot, raapiminen, eläimet, räjähdykset, koneet, soittimet…).
Äänet on generoitu synteettisesti (`tools/generate_sounds.py`), joten ne ovat vapaasti käytettäviä.

## Ominaisuudet
- Useita herätyksiä, valinta ääni kerrallaan (esikuuntelu ▶) tai 🎲 satunnainen ääni
- Äänenvoimakkuus pakotetaan maksimiin (`volumeEnforced`), värinä päällä
- Toisto joka päivä, torkku 5 min, pyyhkäise herätys pois listasta
- 🎼 Äänisarja: 2–5 ääntä peräkkäin (10–45 s kukin), satunnaiset vaiheet arvotaan uudelleen joka aamu
- 🎵 Omat äänet: mp3/m4a/wav/mp4 Tiedostot-sovelluksesta tai Musiikki-kirjastosta (ei DRM-suojattuja Apple Music/Spotify-striimejä)
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

Äänet voi luoda uudelleen: `python tools/generate_sounds.py` ja `python tools/generate_variants.py` ja `python tools/generate_characters.py` (tarvitsevat numpy:n ja scipyn).

## Tärkeää iOS:n rajoituksista
- iOS ei salli kolmannen osapuolen sovelluksille oikeaa herätystä samalla tavalla kuin kellosovellukselle.
  Paketti pitää sovelluksen hengissä taustalla. **Älä pyyhkäise sovellusta pois** moniajosta yöksi.
  Jos sen tappaa, tulee vain tavallinen ilmoitusääni (`warningNotificationOnKill` muistuttaa tästä).
- Hiljainen-tila-kytkin ja Älä häiritse -tila voivat vaimentaa ilmoituksia. Pidä puhelin latauksessa ja testaa herätys ennen kuin luotat siihen (aseta ensin herätys 1–2 min päähän).
- Äänet ovat oikeasti kovia. Älä testaa kuulokkeet korvilla.
