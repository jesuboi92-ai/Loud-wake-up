"""Ajetaan `flutter create`-komennon jälkeen: lisää iOS-asetukset alarm-pluginia varten.

Käyttö (projektin juuresta):  python tools/patch_ios.py
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "ios"

plist = root / "Runner" / "Info.plist"
text = plist.read_text(encoding="utf-8")
if "UIBackgroundModes" not in text:
    block = (
        "\t<key>UIBackgroundModes</key>\n\t<array>\n"
        "\t\t<string>audio</string>\n\t\t<string>fetch</string>\n\t</array>\n"
    )
    idx = text.rindex("</dict>")
    text = text[:idx] + block + text[idx:]
    plist.write_text(text, encoding="utf-8")
    print("Info.plist: UIBackgroundModes lisätty")
else:
    print("Info.plist: jo kunnossa")

podfile = root / "Podfile"
if podfile.exists():
    p = podfile.read_text(encoding="utf-8")
    p2 = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '14.0'", p, count=1)
    if p2 != p:
        podfile.write_text(p2, encoding="utf-8")
        print("Podfile: platform :ios, '14.0'")
