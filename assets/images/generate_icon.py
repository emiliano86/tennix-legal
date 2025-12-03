#!/usr/bin/env python3
"""
Script per generare l'icona dell'app Tennix
Richiede: pip install pillow
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Dimensioni
SIZE = 1024
FOREGROUND_SIZE = 1024

def create_main_icon():
    """Crea l'icona principale con sfondo nero e pallina verde"""
    # Crea immagine con sfondo nero
    img = Image.new('RGB', (SIZE, SIZE), '#000000')
    draw = ImageDraw.Draw(img)
    
    # Centro dell'immagine
    center = SIZE // 2
    
    # Disegna la pallina da tennis (cerchio verde)
    ball_radius = SIZE // 3
    ball_bbox = [
        center - ball_radius,
        center - ball_radius,
        center + ball_radius,
        center + ball_radius
    ]
    
    # Sfondo verde della pallina
    draw.ellipse(ball_bbox, fill='#00E676', outline='#00E676')
    
    # Linea curva bianca tipica della pallina da tennis
    line_width = SIZE // 40
    
    # Prima curva
    draw.arc(
        [center - ball_radius + line_width, center - ball_radius//2, 
         center + ball_radius - line_width, center + ball_radius//2],
        start=200, end=340, fill='#FFFFFF', width=line_width
    )
    
    # Seconda curva (speculare)
    draw.arc(
        [center - ball_radius + line_width, center - ball_radius//2, 
         center + ball_radius - line_width, center + ball_radius//2],
        start=20, end=160, fill='#FFFFFF', width=line_width
    )
    
    # Aggiungi il testo "T" al centro
    try:
        # Prova a usare un font di sistema
        font_size = SIZE // 3
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()
    
    text = "T"
    
    # Calcola la posizione del testo per centrarlo
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = center - text_width // 2
    text_y = center - text_height // 2 - SIZE // 20
    
    # Disegna il testo bianco con ombra
    shadow_offset = SIZE // 100
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text, fill='#000000', font=font)
    draw.text((text_x, text_y), text, fill='#FFFFFF', font=font)
    
    return img

def create_foreground_icon():
    """Crea l'icona foreground per Android (pallina trasparente)"""
    # Crea immagine trasparente
    img = Image.new('RGBA', (FOREGROUND_SIZE, FOREGROUND_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Centro dell'immagine
    center = FOREGROUND_SIZE // 2
    
    # Disegna la pallina da tennis (cerchio verde)
    ball_radius = FOREGROUND_SIZE // 3
    ball_bbox = [
        center - ball_radius,
        center - ball_radius,
        center + ball_radius,
        center + ball_radius
    ]
    
    # Sfondo verde della pallina
    draw.ellipse(ball_bbox, fill='#00E676', outline='#00E676')
    
    # Linea curva bianca tipica della pallina da tennis
    line_width = FOREGROUND_SIZE // 40
    
    # Prima curva
    draw.arc(
        [center - ball_radius + line_width, center - ball_radius//2, 
         center + ball_radius - line_width, center + ball_radius//2],
        start=200, end=340, fill='#FFFFFF', width=line_width
    )
    
    # Seconda curva (speculare)
    draw.arc(
        [center - ball_radius + line_width, center - ball_radius//2, 
         center + ball_radius - line_width, center + ball_radius//2],
        start=20, end=160, fill='#FFFFFF', width=line_width
    )
    
    # Aggiungi il testo "T" al centro
    try:
        font_size = FOREGROUND_SIZE // 3
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()
    
    text = "T"
    
    # Calcola la posizione del testo per centrarlo
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = center - text_width // 2
    text_y = center - text_height // 2 - FOREGROUND_SIZE // 20
    
    # Disegna il testo bianco con ombra
    shadow_offset = FOREGROUND_SIZE // 100
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text, fill=(0, 0, 0, 128), font=font)
    draw.text((text_x, text_y), text, fill='#FFFFFF', font=font)
    
    return img

if __name__ == "__main__":
    # Directory corrente
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("🎾 Generazione icona Tennix...")
    
    # Crea l'icona principale
    print("  → Creazione app_icon.png...")
    main_icon = create_main_icon()
    main_icon.save(os.path.join(current_dir, 'app_icon.png'), 'PNG')
    
    # Crea l'icona foreground
    print("  → Creazione app_icon_foreground.png...")
    foreground_icon = create_foreground_icon()
    foreground_icon.save(os.path.join(current_dir, 'app_icon_foreground.png'), 'PNG')
    
    print("✅ Icone generate con successo!")
    print("\nPassi successivi:")
    print("1. cd /Users/emi/Desktop/tennix")
    print("2. flutter pub get")
    print("3. dart run flutter_launcher_icons")
