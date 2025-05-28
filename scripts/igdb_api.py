import requests
from PIL import Image, ImageDraw, ImageFont
import textwrap
import sys
import os

# Укажите свои данные
CLIENT_ID = "52vmfk8yz2b1l4ieamgm9ybt50yt3i"
CLIENT_SECRET = "1d29ybby34wcbthv4y0hzh6l0e5ioe"
TOKEN_URL = "https://id.twitch.tv/oauth2/token"
API_URL = "https://api.igdb.com/v4"

# Получаем токен
def get_token():
    params = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "client_credentials"
    }
    response = requests.post(TOKEN_URL, params=params)
    response.raise_for_status()
    return response.json()["access_token"]

# Ищем игру по названию
def search_game(title, token):
    headers = {
        "Client-ID": CLIENT_ID,
        "Authorization": f"Bearer {token}"
    }
    query = f'search "{title}"; fields id, name, summary, cover.image_id; limit 1;'
    response = requests.post(f"{API_URL}/games", headers=headers, data=query)
    response.raise_for_status()
    results = response.json()
    return results[0] if results else None

# Скачиваем изображение по ID
def download_cover(image_id, filename):
    url = f"https://images.igdb.com/igdb/image/upload/t_cover_big/{image_id}.jpg"
    response = requests.get(url)
    with open(filename, "wb") as f:
        f.write(response.content)

# Обработка текста
def wrap_text(text, font, max_width):
    words = text.split()
    lines = []
    current_line = []
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = font.getbbox(test_line)
        if bbox[2] - bbox[0] <= max_width:
            current_line.append(word)
        else:
            lines.append(' '.join(current_line))
            current_line = [word]
    if current_line:
        lines.append(' '.join(current_line))
    return lines

# Создаём плейсхолдер
def generate_placeholder(description, width, height, filename):
    img = Image.new("RGB", (width, height), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    margin = 10
    max_text_width = width - 2 * margin
    lines = wrap_text(description, font, max_text_width)
    line_height = font.getbbox('hg')[3] - font.getbbox('hg')[1]
    total_text_height = len(lines) * line_height
    if total_text_height > height - 2 * margin:
        max_lines = (height - 2 * margin) // line_height
        lines = lines[:max_lines]
        lines[-1] += "..."
    y = margin
    for line in lines:
        draw.text((margin, y), line, fill=(0, 0, 0), font=font)
        y += line_height
    img.save(filename)

def sanitize_title(title):
    return "".join(c for c in title if c.isalnum() or c in (' ', '_')).replace(' ', '_')

def main():
    if len(sys.argv) < 2:
        print("Usage: python get_game_cover_igdb.py \"Game Title\"")
        return
    title = sys.argv[1]
    token = get_token()
    game = search_game(title, token)
    if not game:
        print(f"Игра '{title}' не найдена.")
        return
    game_name = game["name"]
    overview = game.get("summary", "Описание отсутствует.")
    image_id = game.get("cover", {}).get("image_id")

    filename_base = sanitize_title(game_name)
    if image_id:
        cover_filename = f"{filename_base}_cover.jpg"
        download_cover(image_id, cover_filename)
        print(f"Обложка сохранена как {cover_filename}")
        # Примерные размеры IGDB cover_big — 264x374
        width, height = 1056, 1496
    else:
        print("Обложка не найдена.")
        cover_filename = f"{filename_base}_placeholder.jpg"
        width, height = 1056, 1496

    if not image_id:
        generate_placeholder(overview, width, height, cover_filename)
        print(f"Плейсхолдер сохранён как {cover_filename}")

if __name__ == "__main__":
    main()
