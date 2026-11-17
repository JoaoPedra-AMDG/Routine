from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
base = Image.new('RGB', (1024, 1024), '#f6f3ec')
d = ImageDraw.Draw(base)
d.rounded_rectangle((184, 224, 840, 834), radius=85, fill='#a35b3d')
d.rounded_rectangle((228, 363, 796, 790), radius=40, fill='#f6f3ec')
for x in (351, 673):
    d.rounded_rectangle((x-24, 165, x+24, 293), radius=24, fill='#a35b3d')
d.line([(344, 568), (456, 675), (677, 463)], fill='#65806a', width=48, joint='curve')
for name, size in [('Icon-192.png',192), ('Icon-512.png',512), ('Icon-maskable-192.png',192), ('Icon-maskable-512.png',512)]:
    base.resize((size,size),Image.Resampling.LANCZOS).save(root/'web/icons'/name)
base.resize((64,64),Image.Resampling.LANCZOS).save(root/'web/favicon.png')
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    base.resize((size,size),Image.Resampling.LANCZOS).save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
base.save(root/'windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
import json
icons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((icons/'Contents.json').read_text())['images']:
    if 'filename' not in entry: continue
    size=round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
    base.resize((size,size),Image.Resampling.LANCZOS).save(icons/entry['filename'])
