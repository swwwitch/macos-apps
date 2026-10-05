from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = "outputs/AppStore/QuickIcon-Exporter-Screenshot.png"
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT, size=size, index=1 if bold else 0)


def centered(draw, y, text, f, fill):
    box = draw.textbbox((0, 0), text, font=f)
    draw.text(((1280 - (box[2] - box[0])) / 2, y), text, font=f, fill=fill)


img = Image.new("RGB", (1280, 800), "#eaf5ff")
d = ImageDraw.Draw(img)
for y in range(800):
    t = y / 799
    color = (int(238 - 20*t), int(248 - 9*t), 255)
    d.line((0, y, 1280, y), fill=color)
d.ellipse((980, -150, 1340, 210), fill="#f8fcff")
d.ellipse((-110, 590, 260, 960), fill="#f5fbff")
centered(d, 52, "アイコンを、すぐに透過PNGへ", font(44, True), "#17334d")
centered(d, 112, "アプリやファイルをドラッグ＆ドロップするだけ", font(20), "#55728b")

shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((286, 180, 994, 688), radius=24, fill=(45, 95, 136, 55))
shadow = shadow.filter(ImageFilter.GaussianBlur(24))
img.paste(shadow, (0, 14), shadow)
d = ImageDraw.Draw(img)
d.rounded_rectangle((300, 175, 980, 675), radius=20, fill="#f4f4f4")
d.rounded_rectangle((300, 175, 980, 220), radius=20, fill="#e8e8e8")
d.rectangle((300, 198, 980, 220), fill="#e8e8e8")
for x, c in ((325, "#ff5f57"), (348, "#febc2e"), (371, "#28c840")):
    d.ellipse((x-7, 191, x+7, 205), fill=c)
centered(d, 188, "QuickIcon Exporter", font(14, True), "#777777")
d.rectangle((300, 220, 980, 302), fill="white")
d.rounded_rectangle((328, 242, 368, 282), radius=10, outline="#168bf0", width=3)
d.text((384, 238), "QuickIcon Exporter", font=font(20, True), fill="#252525")
d.text((384, 269), "ファイルのアイコンを最大サイズのPNGに", font=font(13), fill="#777777")
d.text((908, 251), "設定", font=font(14), fill="#666666")

d.rounded_rectangle((326, 328, 954, 602), radius=24, fill="white", outline="#d3d3d3", width=3)
d.rounded_rectangle((606, 378, 674, 446), radius=17, outline="#70b8f8", width=5)
d.line((640, 394, 640, 425), fill="#0789f4", width=5)
d.line((625, 412, 640, 428, 655, 412), fill="#0789f4", width=5, joint="curve")
centered(d, 475, "アプリやファイルをここにドロップ", font(22, True), "#222222")
centered(d, 520, "複数のファイルもまとめて書き出せます", font(15), "#777777")
d.text((334, 628), "書き出し先: デスクトップ", font=font(14), fill="#666666")
d.rounded_rectangle((875, 620, 953, 650), radius=15, fill="white", outline="#c8c8c8")
d.text((891, 625), "変更…", font=font(13, True), fill="#444444")
centered(d, 733, "最大サイズ・透過PNG・複数ファイル対応", font(18, True), "#356787")
img.save(OUT, "PNG", optimize=True)
