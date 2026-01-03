import customtkinter as ctk
from tkinter import filedialog, messagebox
from PIL import Image
import os
import threading
from google import genai
from google.genai import types

# --- CONFIGURATION ---
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class IncityGeneratorApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("INCITY Widget Generator - Gemini 3 Pro")
        self.geometry("1100x750")

        self.reference_image_path = None
        self.pil_image = None

        # --- LAYOUT ---
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # 1. SIDEBAR
        self.sidebar = ctk.CTkFrame(self, width=300, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")

        self.logo_label = ctk.CTkLabel(
            self.sidebar,
            text="INCITY\nWidget Generator",
            font=ctk.CTkFont(size=22, weight="bold")
        )
        self.logo_label.pack(pady=25)

        # API Key
        self.api_group = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        self.api_group.pack(fill="x", padx=10)
        ctk.CTkLabel(self.api_group, text="Clé API Google:", anchor="w").pack(fill="x", padx=15)
        self.api_entry = ctk.CTkEntry(self.api_group, show="*", placeholder_text="Collez la clé ici...")
        self.api_entry.pack(pady=5, padx=15, fill="x")

        # Image Reference
        ctk.CTkLabel(self.sidebar, text="Image Référence (Incity):", anchor="w").pack(fill="x", padx=15, pady=(20,0))
        self.load_btn = ctk.CTkButton(
            self.sidebar,
            text="Charger incity.png",
            command=self.load_image,
            fg_color="#2563EB",
            hover_color="#1D4ED8"
        )
        self.load_btn.pack(pady=10, padx=15, fill="x")

        self.img_preview = ctk.CTkLabel(
            self.sidebar,
            text="[Aucune image]",
            width=200,
            height=200,
            fg_color="#1a1a1a",
            corner_radius=8
        )
        self.img_preview.pack(pady=10, padx=15)

        # Options Modèle
        self.settings_frame = ctk.CTkFrame(self.sidebar)
        self.settings_frame.pack(pady=20, padx=15, fill="x")
        ctk.CTkLabel(self.settings_frame, text="Paramètres", font=ctk.CTkFont(weight="bold")).pack(pady=5)
        ctk.CTkLabel(self.settings_frame, text="Modèle: gemini-3-pro-image-preview").pack(pady=2)
        ctk.CTkLabel(self.settings_frame, text="Format: 1:1 (carré)").pack(pady=2)
        ctk.CTkLabel(self.settings_frame, text="Résolution: 2K").pack(pady=2)

        # Console
        ctk.CTkLabel(self.sidebar, text="Logs:", anchor="w").pack(fill="x", padx=15, side="bottom", pady=(0,5))
        self.log_box = ctk.CTkTextbox(self.sidebar, height=150, font=("Consolas", 11))
        self.log_box.pack(pady=(0, 20), padx=10, fill="x", side="bottom")

        # 2. MAIN PANEL
        self.main_panel = ctk.CTkScrollableFrame(self, label_text="INCITY WIDGET - 29 VARIATIONS")
        self.main_panel.grid(row=0, column=1, sticky="nsew", padx=20, pady=20)

        self.create_buttons()
        self.log("Système prêt.")
        self.log("Charger incity.png comme référence.")

    def log(self, message):
        self.log_box.insert("end", f"> {message}\n")
        self.log_box.see("end")

    def load_image(self):
        try:
            file_path = filedialog.askopenfilename(
                title="Choisir l'image de référence Incity",
                filetypes=[("Images", "*.png"), ("Images", "*.jpg"), ("Images", "*.jpeg")]
            )
            if not file_path: return

            self.reference_image_path = file_path
            self.pil_image = Image.open(file_path).convert('RGB')

            # Preview carré
            preview_img = ctk.CTkImage(
                light_image=self.pil_image,
                dark_image=self.pil_image,
                size=(200, 200)
            )
            self.img_preview.configure(image=preview_img, text="")
            self.log(f"Image chargée : {os.path.basename(file_path)}")

        except Exception as e:
            self.log(f"ERREUR CHARGEMENT: {e}")

    def generate_task(self, filename, prompt_details):
        """Génération en arrière-plan"""
        api_key = self.api_entry.get().strip()

        try:
            client = genai.Client(api_key=api_key)
        except Exception as e:
            self.log(f"Erreur Client: {e}")
            return

        # PROMPT DE BASE - Préserve la structure de la tour Incity
        base_prompt = (
            "Using the provided image of the Incity tower in Lyon, modify ONLY the atmosphere and lighting. "
            f"{prompt_details}. "
            "CRITICAL: Keep the EXACT same tower geometry, proportions, camera angle, and claymorphism 3D style. "
            "The tower structure, windows pattern, and architectural details must remain IDENTICAL. "
            "Only change: sky color, lighting direction, weather effects, and LED colors on the tower facade."
        )

        self.log(f"Génération: {filename}...")

        output_dir = os.path.join(os.getcwd(), "output_incity")
        os.makedirs(output_dir, exist_ok=True)
        final_path = os.path.join(output_dir, filename)

        try:
            response = client.models.generate_content(
                model="gemini-3-pro-image-preview",
                contents=[base_prompt, self.pil_image],
                config=types.GenerateContentConfig(
                    response_modalities=['IMAGE'],
                    image_config=types.ImageConfig(
                        aspect_ratio="1:1",  # FORMAT CARRÉ
                        image_size="2K"
                    )
                )
            )

            image_saved = False

            if response.parts:
                for part in response.parts:
                    if part.inline_data:
                        img_bytes = part.inline_data.data

                        try:
                            if hasattr(part, "as_image"):
                                img = part.as_image()
                                img.save(final_path)
                                image_saved = True
                                break
                        except:
                            pass

                        if not image_saved:
                            import base64
                            if isinstance(img_bytes, str):
                                img_data = base64.b64decode(img_bytes)
                            else:
                                img_data = img_bytes

                            with open(final_path, "wb") as f:
                                f.write(img_data)
                            image_saved = True

            if image_saved:
                self.log(f"OK: {filename}")
            else:
                self.log(f"Pas d'image retournée pour {filename}")
                print(response)

        except Exception as e:
            self.log(f"ERREUR: {e}")

    def trigger_generation(self, filename, prompt_add):
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        threading.Thread(target=self.generate_task, args=(filename, prompt_add)).start()

    # --- BUTTONS FACTORY ---
    def add_group(self, title, color="#2563EB"):
        lbl = ctk.CTkLabel(
            self.main_panel,
            text=title,
            font=ctk.CTkFont(size=16, weight="bold"),
            anchor="w",
            text_color=color
        )
        lbl.pack(fill="x", pady=(25, 10))
        frame = ctk.CTkFrame(self.main_panel)
        frame.pack(fill="x", pady=5)
        return frame

    def add_btn(self, parent, text, filename, prompt_add, color=None):
        btn_color = color if color else "#2563EB"
        btn = ctk.CTkButton(
            parent,
            text=text,
            height=45,
            fg_color=btn_color,
            hover_color="#1E40AF",
            command=lambda: self.trigger_generation(filename, prompt_add)
        )
        btn.pack(side="left", padx=5, pady=8, expand=True, fill="x")

    def create_buttons(self):
        # ============================================
        # A. MÉTÉO JOUR (6 images)
        # ============================================
        f1 = self.add_group("A. MÉTÉO JOUR (6 variations)", "#F59E0B")

        # Row 1: Clear weather
        row1 = ctk.CTkFrame(f1, fg_color="transparent")
        row1.pack(fill="x", pady=5)

        self.add_btn(
            row1,
            "Golden Hour",
            "incity_clear_golden.png",
            "Golden hour lighting, warm orange and pink sunset sky, "
            "soft golden light reflecting on the tower glass facade, "
            "dramatic long shadows, romantic warm atmosphere, "
            "the tower lit by beautiful sunset colors",
            color="#F97316"
        )

        self.add_btn(
            row1,
            "Jour Ensoleillé",
            "incity_clear_day.png",
            "Bright sunny midday, clear vivid blue sky, "
            "strong direct sunlight, sharp shadows on the tower, "
            "bright cheerful atmosphere, summer vibes, "
            "the glass facade reflecting the blue sky",
            color="#3B82F6"
        )

        # Row 2: Partly Cloudy & Cloudy
        row2 = ctk.CTkFrame(f1, fg_color="transparent")
        row2.pack(fill="x", pady=5)

        self.add_btn(
            row2,
            "Partiellement Nuageux",
            "incity_partly_cloudy_day.png",
            "Partly cloudy sky, mix of blue sky and white fluffy clouds, "
            "sun visible between clouds, dynamic lighting with soft shadows, "
            "pleasant weather, some clouds drifting across the sky, "
            "the tower with alternating sun and cloud shadows",
            color="#60A5FA"
        )

        self.add_btn(
            row2,
            "Nuageux",
            "incity_cloudy_day.png",
            "Overcast grey sky, flat diffused lighting, "
            "no direct shadows, soft grey clouds covering the sky, "
            "muted colors, typical Lyon grey day atmosphere, "
            "the tower under cloudy weather",
            color="#6B7280"
        )

        # Row 3: Rain
        row3 = ctk.CTkFrame(f1, fg_color="transparent")
        row3.pack(fill="x", pady=5)

        self.add_btn(
            row3,
            "Pluie",
            "incity_rain_day.png",
            "Rainy weather, dark grey stormy clouds, "
            "visible rain drops falling, wet reflections on surfaces, "
            "puddles on the ground, moody rainy atmosphere, "
            "the tower during rainfall with glistening wet facade",
            color="#1E40AF"
        )

        # Row 4: Snow & Storm
        row4 = ctk.CTkFrame(f1, fg_color="transparent")
        row4.pack(fill="x", pady=5)

        self.add_btn(
            row4,
            "Neige",
            "incity_snow_day.png",
            "Snowy winter day, white overcast sky, "
            "snow falling gently, snow accumulation on surfaces, "
            "cold blue-white atmosphere, winter wonderland, "
            "the tower covered with snow on ledges",
            color="#94A3B8"
        )

        self.add_btn(
            row4,
            "Orage",
            "incity_storm_day.png",
            "Dramatic thunderstorm, very dark ominous clouds, "
            "lightning bolt visible in the sky, intense atmosphere, "
            "dramatic contrast between dark sky and occasional light, "
            "the tower during a powerful storm",
            color="#4C1D95"
        )

        # ============================================
        # B. EASTER EGGS - JOUR (décorations discrètes)
        # ============================================
        f2 = self.add_group("B. EASTER EGGS - JOUR (6 événements)", "#10B981")

        easter_eggs_day = [
            (
                "Fête des Lumières",
                "incity_fete_lumieres_day.png",
                "Early december day, pale winter sunlight, "
                "sky with subtle purple and blue gradient hues, "
                "the tower with faint colorful LED lights visible on facade even in daylight, "
                "magical anticipation atmosphere, crisp cold air feeling",
                "#7B68EE"
            ),
            (
                "Noël",
                "incity_noel_day.png",
                "Christmas day, soft golden winter light, light snow falling, "
                "sky with warm peachy pink winter clouds, "
                "the tower with subtle green and red LED lights glowing softly on facade, "
                "cozy magical Christmas morning atmosphere",
                "#228B22"
            ),
            (
                "Nouvel An",
                "incity_nouvel_an_day.png",
                "New Year's day morning, bright crisp winter light, "
                "sky with golden and champagne colored clouds, "
                "the tower with faint golden sparkle LED lights on facade, "
                "fresh hopeful new beginning atmosphere",
                "#FFD700"
            ),
            (
                "14 Juillet",
                "incity_14_juillet_day.png",
                "Bastille Day, bright summer sun, "
                "vivid blue sky with subtle white clouds forming tricolor effect, "
                "the tower with faint blue white red LED accent lights on facade, "
                "patriotic celebratory summer atmosphere",
                "#0055A4"
            ),
            (
                "Halloween",
                "incity_halloween_day.png",
                "Halloween day, dramatic orange and purple sunset sky, "
                "moody clouds with eerie autumn colors, "
                "the tower with faint orange and purple LED lights glowing on facade, "
                "mysterious spooky but fun atmosphere",
                "#FF7518"
            ),
            (
                "Saint-Valentin",
                "incity_saint_valentin_day.png",
                "Valentine's day, soft romantic pink golden hour light, "
                "sky with delicate pink and rose colored clouds, "
                "the tower with subtle pink heart-shaped LED patterns glowing softly on facade, "
                "romantic dreamy love atmosphere",
                "#FF69B4"
            ),
        ]

        for event_name, filename, prompt, color in easter_eggs_day:
            row = ctk.CTkFrame(f2, fg_color="transparent")
            row.pack(fill="x", pady=3)

            self.add_btn(
                row,
                f"{event_name}",
                filename,
                prompt,
                color=color
            )

        # ============================================
        # C. EASTER EGGS - NUIT AVEC LED SPÉCIALES (6 images)
        # ============================================
        f3 = self.add_group("C. EASTER EGGS - NUIT AVEC LED (6 événements)", "#EC4899")

        easter_eggs = [
            (
                "Fête des Lumières",
                "incity_fete_lumieres_night.png",
                "Night scene, dark blue sky with stars, "
                "the Incity tower displaying SPECTACULAR COLORFUL LED LIGHT SHOW, "
                "animated rainbow colors flowing on the facade, purple blue pink lights, "
                "artistic light projections, Lyon Festival of Lights celebration, "
                "magical luminous atmosphere, the tower as a beacon of colored lights",
                "#8B5CF6"
            ),
            (
                "Noël",
                "incity_noel_night.png",
                "Christmas night, dark starry sky, light snow falling, "
                "the Incity tower displaying FESTIVE RED AND GREEN LED LIGHTS, "
                "Christmas tree pattern made of green LEDs, red accents, "
                "warm golden fairy lights, holiday spirit, "
                "magical cozy Christmas atmosphere on the tower",
                "#DC2626"
            ),
            (
                "Nouvel An",
                "incity_nouvel_an_night.png",
                "New Year's Eve night, fireworks exploding in the sky, "
                "the Incity tower displaying GOLDEN AND WHITE SPARKLING LED ANIMATION, "
                "shimmering golden lights cascading down the facade, "
                "champagne gold and silver sparkles, celebratory atmosphere, "
                "the tower glowing with festive golden light",
                "#FBBF24"
            ),
            (
                "14 Juillet",
                "incity_14_juillet_night.png",
                "Bastille Day night, fireworks in the background, "
                "the Incity tower displaying FRENCH FLAG COLORS in LED lights, "
                "blue white red vertical stripes illuminating the facade, "
                "patriotic tricolor lighting, national celebration, "
                "the tower proudly showing bleu blanc rouge",
                "#1D4ED8"
            ),
            (
                "Halloween",
                "incity_halloween_night.png",
                "Halloween night, full moon visible, spooky atmosphere, "
                "the Incity tower displaying ORANGE AND PURPLE LED LIGHTS, "
                "jack-o-lantern face pattern in orange LEDs, purple accents, "
                "eerie glow, bats silhouettes near the tower, "
                "spooky but fun Halloween lighting",
                "#EA580C"
            ),
            (
                "Saint-Valentin",
                "incity_saint_valentin_night.png",
                "Valentine's night, romantic starry sky, "
                "the Incity tower displaying PINK AND RED HEART-SHAPED LED PATTERNS, "
                "multiple hearts made of pink LEDs flowing up the facade, "
                "romantic rose-colored glow, love atmosphere, "
                "the tower as a symbol of love with heart lights",
                "#DB2777"
            ),
        ]

        for event_name, filename, prompt, color in easter_eggs:
            row = ctk.CTkFrame(f3, fg_color="transparent")
            row.pack(fill="x", pady=3)

            self.add_btn(
                row,
                f"{event_name}",
                filename,
                prompt,
                color=color
            )

        # ============================================
        # D. NUIT - 5 COULEURS LED QUALITÉ AIR
        # ============================================
        f4 = self.add_group("D. NUIT - LED Qualité Air (5 couleurs)", "#0EA5E9")

        # Base prompt pour la nuit (structure identique à l'image de référence)
        night_base = (
            "Night scene, dark blue night sky with soft 3D claymorphism clouds, "
            "crescent moon visible in the sky, "
            "the Incity tower with its rectangular top section displaying HORIZONTAL LED LIGHT LINES, "
            "the cylindrical lower section with warm orange lit windows, "
            "calm peaceful night atmosphere"
        )

        night_colors = [
            ("Cyan (Bon)", "incity_night_cyan.png", "#50F0E6", "bright cyan turquoise"),
            ("Vert (Moyen)", "incity_night_green.png", "#50CCAA", "mint green teal"),
            ("Jaune (Dégradé)", "incity_night_yellow.png", "#F0E641", "bright yellow"),
            ("Rouge (Mauvais)", "incity_night_red.png", "#E63A52", "vivid red coral"),
            ("Violet (Très Mauvais)", "incity_night_purple.png", "#872181", "deep purple magenta"),
        ]

        row_night = ctk.CTkFrame(f4, fg_color="transparent")
        row_night.pack(fill="x", pady=5)

        for color_name, filename, btn_color, led_color in night_colors:
            prompt = f"{night_base}, the LED lines glowing in {led_color} color"
            self.add_btn(row_night, color_name, filename, prompt, color=btn_color)

        # ============================================
        # E. PLEINE LUNE - 5 COULEURS LED QUALITÉ AIR
        # ============================================
        f5 = self.add_group("E. PLEINE LUNE - LED Qualité Air (5 couleurs)", "#8B5CF6")

        # Base prompt pour pleine lune
        fullmoon_base = (
            "Night scene, dark blue night sky with soft 3D claymorphism clouds, "
            "LARGE BRIGHT FULL MOON prominently visible in the sky casting silver moonlight, "
            "the Incity tower with its rectangular top section displaying HORIZONTAL LED LIGHT LINES, "
            "the cylindrical lower section with warm orange lit windows, "
            "magical mystical full moon night atmosphere, moon reflecting on tower surface"
        )

        fullmoon_colors = [
            ("Cyan (Bon)", "incity_fullmoon_cyan.png", "#50F0E6", "bright cyan turquoise"),
            ("Vert (Moyen)", "incity_fullmoon_green.png", "#50CCAA", "mint green teal"),
            ("Jaune (Dégradé)", "incity_fullmoon_yellow.png", "#F0E641", "bright yellow"),
            ("Rouge (Mauvais)", "incity_fullmoon_red.png", "#E63A52", "vivid red coral"),
            ("Violet (Très Mauvais)", "incity_fullmoon_purple.png", "#872181", "deep purple magenta"),
        ]

        row_fullmoon = ctk.CTkFrame(f5, fg_color="transparent")
        row_fullmoon.pack(fill="x", pady=5)

        for color_name, filename, btn_color, led_color in fullmoon_colors:
            prompt = f"{fullmoon_base}, the LED lines glowing in {led_color} color"
            self.add_btn(row_fullmoon, color_name, filename, prompt, color=btn_color)

        # ============================================
        # F. GÉNÉRATION GROUPÉE
        # ============================================
        f6 = self.add_group("F. GÉNÉRATION GROUPÉE", "#6366F1")

        row_batch1 = ctk.CTkFrame(f6, fg_color="transparent")
        row_batch1.pack(fill="x", pady=5)

        btn_all_day = ctk.CTkButton(
            row_batch1,
            text="Météo JOUR (7)",
            height=45,
            fg_color="#F59E0B",
            hover_color="#D97706",
            command=self.generate_all_day
        )
        btn_all_day.pack(side="left", padx=5, expand=True, fill="x")

        btn_all_easter_day = ctk.CTkButton(
            row_batch1,
            text="Easter JOUR (6)",
            height=45,
            fg_color="#10B981",
            hover_color="#059669",
            command=self.generate_all_easter_day
        )
        btn_all_easter_day.pack(side="left", padx=5, expand=True, fill="x")

        btn_all_easter_night = ctk.CTkButton(
            row_batch1,
            text="Easter NUIT (6)",
            height=45,
            fg_color="#EC4899",
            hover_color="#BE185D",
            command=self.generate_all_easter_night
        )
        btn_all_easter_night.pack(side="left", padx=5, expand=True, fill="x")

        row_batch2 = ctk.CTkFrame(f6, fg_color="transparent")
        row_batch2.pack(fill="x", pady=5)

        btn_all_night = ctk.CTkButton(
            row_batch2,
            text="NUIT LED (5)",
            height=45,
            fg_color="#0EA5E9",
            hover_color="#0284C7",
            command=self.generate_all_night
        )
        btn_all_night.pack(side="left", padx=5, expand=True, fill="x")

        btn_all_fullmoon = ctk.CTkButton(
            row_batch2,
            text="PLEINE LUNE (5)",
            height=45,
            fg_color="#8B5CF6",
            hover_color="#7C3AED",
            command=self.generate_all_fullmoon
        )
        btn_all_fullmoon.pack(side="left", padx=5, expand=True, fill="x")

        btn_all_everything = ctk.CTkButton(
            row_batch2,
            text="TOUT (29)",
            height=45,
            fg_color="#DC2626",
            hover_color="#B91C1C",
            command=self.generate_all_everything
        )
        btn_all_everything.pack(side="left", padx=5, expand=True, fill="x")

    def generate_all_day(self):
        """Génère toutes les images météo jour"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        day_configs = [
            ("incity_clear_golden.png", "Golden hour lighting, warm orange and pink sunset sky, soft golden light reflecting on the tower glass facade, dramatic long shadows, romantic warm atmosphere, the tower lit by beautiful sunset colors"),
            ("incity_clear_day.png", "Bright sunny midday, clear vivid blue sky, strong direct sunlight, sharp shadows on the tower, bright cheerful atmosphere, summer vibes, the glass facade reflecting the blue sky"),
            ("incity_partly_cloudy_day.png", "Partly cloudy sky, mix of blue sky and white fluffy clouds, sun visible between clouds, dynamic lighting with soft shadows, pleasant weather, some clouds drifting across the sky, the tower with alternating sun and cloud shadows"),
            ("incity_cloudy_day.png", "Overcast grey sky, flat diffused lighting, no direct shadows, soft grey clouds covering the sky, muted colors, typical Lyon grey day atmosphere, the tower under cloudy weather"),
            ("incity_rain_day.png", "Rainy weather, dark grey stormy clouds, visible rain drops falling, wet reflections on surfaces, puddles on the ground, moody rainy atmosphere, the tower during rainfall with glistening wet facade"),
            ("incity_snow_day.png", "Snowy winter day, white overcast sky, snow falling gently, snow accumulation on surfaces, cold blue-white atmosphere, winter wonderland, the tower covered with snow on ledges"),
            ("incity_storm_day.png", "Dramatic thunderstorm, very dark ominous clouds, lightning bolt visible in the sky, intense atmosphere, dramatic contrast between dark sky and occasional light, the tower during a powerful storm"),
        ]

        self.log("Génération batch MÉTÉO JOUR (7 images)...")
        for filename, prompt in day_configs:
            threading.Thread(target=self.generate_task, args=(filename, prompt)).start()

    def generate_all_easter_day(self):
        """Génère tous les easter eggs jour"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        easter_day_configs = [
            ("incity_fete_lumieres_day.png", "Early december day, pale winter sunlight, sky with subtle purple and blue gradient hues, the tower with faint colorful LED lights visible on facade even in daylight, magical anticipation atmosphere, crisp cold air feeling"),
            ("incity_noel_day.png", "Christmas day, soft golden winter light, light snow falling, sky with warm peachy pink winter clouds, the tower with subtle green and red LED lights glowing softly on facade, cozy magical Christmas morning atmosphere"),
            ("incity_nouvel_an_day.png", "New Year's day morning, bright crisp winter light, sky with golden and champagne colored clouds, the tower with faint golden sparkle LED lights on facade, fresh hopeful new beginning atmosphere"),
            ("incity_14_juillet_day.png", "Bastille Day, bright summer sun, vivid blue sky with subtle white clouds forming tricolor effect, the tower with faint blue white red LED accent lights on facade, patriotic celebratory summer atmosphere"),
            ("incity_halloween_day.png", "Halloween day, dramatic orange and purple sunset sky, moody clouds with eerie autumn colors, the tower with faint orange and purple LED lights glowing on facade, mysterious spooky but fun atmosphere"),
            ("incity_saint_valentin_day.png", "Valentine's day, soft romantic pink golden hour light, sky with delicate pink and rose colored clouds, the tower with subtle pink heart-shaped LED patterns glowing softly on facade, romantic dreamy love atmosphere"),
        ]

        self.log("Génération batch EASTER EGGS JOUR (6 images)...")
        for filename, prompt in easter_day_configs:
            threading.Thread(target=self.generate_task, args=(filename, prompt)).start()

    def generate_all_easter_night(self):
        """Génère tous les easter eggs nuit"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        easter_night_configs = [
            ("incity_fete_lumieres_night.png", "Night scene, dark blue sky with stars, the Incity tower displaying SPECTACULAR COLORFUL LED LIGHT SHOW, animated rainbow colors flowing on the facade, purple blue pink lights, artistic light projections, Lyon Festival of Lights celebration, magical luminous atmosphere, the tower as a beacon of colored lights"),
            ("incity_noel_night.png", "Christmas night, dark starry sky, light snow falling, the Incity tower displaying FESTIVE RED AND GREEN LED LIGHTS, Christmas tree pattern made of green LEDs, red accents, warm golden fairy lights, holiday spirit, magical cozy Christmas atmosphere on the tower"),
            ("incity_nouvel_an_night.png", "New Year's Eve night, fireworks exploding in the sky, the Incity tower displaying GOLDEN AND WHITE SPARKLING LED ANIMATION, shimmering golden lights cascading down the facade, champagne gold and silver sparkles, celebratory atmosphere, the tower glowing with festive golden light"),
            ("incity_14_juillet_night.png", "Bastille Day night, fireworks in the background, the Incity tower displaying FRENCH FLAG COLORS in LED lights, blue white red vertical stripes illuminating the facade, patriotic tricolor lighting, national celebration, the tower proudly showing bleu blanc rouge"),
            ("incity_halloween_night.png", "Halloween night, full moon visible, spooky atmosphere, the Incity tower displaying ORANGE AND PURPLE LED LIGHTS, jack-o-lantern face pattern in orange LEDs, purple accents, eerie glow, bats silhouettes near the tower, spooky but fun Halloween lighting"),
            ("incity_saint_valentin_night.png", "Valentine's night, romantic starry sky, the Incity tower displaying PINK AND RED HEART-SHAPED LED PATTERNS, multiple hearts made of pink LEDs flowing up the facade, romantic rose-colored glow, love atmosphere, the tower as a symbol of love with heart lights"),
        ]

        self.log("Génération batch EASTER EGGS NUIT (6 images)...")
        for filename, prompt in easter_night_configs:
            threading.Thread(target=self.generate_task, args=(filename, prompt)).start()

    def generate_all_night(self):
        """Génère toutes les images nuit avec LED couleurs"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        night_base = "Night scene, dark blue night sky with soft 3D claymorphism clouds, crescent moon visible in the sky, the Incity tower with its rectangular top section displaying HORIZONTAL LED LIGHT LINES, the cylindrical lower section with warm orange lit windows, calm peaceful night atmosphere"

        night_configs = [
            ("incity_night_cyan.png", f"{night_base}, the LED lines glowing in bright cyan turquoise color"),
            ("incity_night_green.png", f"{night_base}, the LED lines glowing in mint green teal color"),
            ("incity_night_yellow.png", f"{night_base}, the LED lines glowing in bright yellow color"),
            ("incity_night_red.png", f"{night_base}, the LED lines glowing in vivid red coral color"),
            ("incity_night_purple.png", f"{night_base}, the LED lines glowing in deep purple magenta color"),
        ]

        self.log("Génération batch NUIT LED (5 images)...")
        for filename, prompt in night_configs:
            threading.Thread(target=self.generate_task, args=(filename, prompt)).start()

    def generate_all_fullmoon(self):
        """Génère toutes les images pleine lune avec LED couleurs"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        fullmoon_base = "Night scene, dark blue night sky with soft 3D claymorphism clouds, LARGE BRIGHT FULL MOON prominently visible in the sky casting silver moonlight, the Incity tower with its rectangular top section displaying HORIZONTAL LED LIGHT LINES, the cylindrical lower section with warm orange lit windows, magical mystical full moon night atmosphere, moon reflecting on tower surface"

        fullmoon_configs = [
            ("incity_fullmoon_cyan.png", f"{fullmoon_base}, the LED lines glowing in bright cyan turquoise color"),
            ("incity_fullmoon_green.png", f"{fullmoon_base}, the LED lines glowing in mint green teal color"),
            ("incity_fullmoon_yellow.png", f"{fullmoon_base}, the LED lines glowing in bright yellow color"),
            ("incity_fullmoon_red.png", f"{fullmoon_base}, the LED lines glowing in vivid red coral color"),
            ("incity_fullmoon_purple.png", f"{fullmoon_base}, the LED lines glowing in deep purple magenta color"),
        ]

        self.log("Génération batch PLEINE LUNE (5 images)...")
        for filename, prompt in fullmoon_configs:
            threading.Thread(target=self.generate_task, args=(filename, prompt)).start()

    def generate_all_everything(self):
        """Génère TOUTES les 29 images"""
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        self.log("Génération TOTALE (29 images)...")
        self.generate_all_day()
        self.generate_all_easter_day()
        self.generate_all_easter_night()
        self.generate_all_night()
        self.generate_all_fullmoon()


if __name__ == "__main__":
    app = IncityGeneratorApp()
    app.mainloop()
