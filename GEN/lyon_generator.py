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

class LyonGeminiV3App(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Lyon Weather - Gemini 3 Pro (Nano Banana Pro)")
        self.geometry("1250x900")
        
        self.reference_image_path = None
        self.pil_image = None
        
        # --- LAYOUT ---
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # 1. SIDEBAR
        self.sidebar = ctk.CTkFrame(self, width=300, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        
        self.logo_label = ctk.CTkLabel(self.sidebar, text="LYON GEN\nGemini 3 Pro", font=ctk.CTkFont(size=22, weight="bold"))
        self.logo_label.pack(pady=25)

        # API Key
        self.api_group = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        self.api_group.pack(fill="x", padx=10)
        ctk.CTkLabel(self.api_group, text="Clé API Google (New SDK):", anchor="w").pack(fill="x", padx=15)
        self.api_entry = ctk.CTkEntry(self.api_group, show="*", placeholder_text="Collez la clé ici...")
        self.api_entry.pack(pady=5, padx=15, fill="x")

        # Image Reference
        ctk.CTkLabel(self.sidebar, text="Image Source (Lyon):", anchor="w").pack(fill="x", padx=15, pady=(20,0))
        self.load_btn = ctk.CTkButton(self.sidebar, text="Charger Image Référence", command=self.load_image, fg_color="#E37400", hover_color="#A95700")
        self.load_btn.pack(pady=10, padx=15, fill="x")
        
        self.img_preview = ctk.CTkLabel(self.sidebar, text="[Aucune image]", width=250, height=140, fg_color="#1a1a1a", corner_radius=8)
        self.img_preview.pack(pady=10, padx=15)

        # Options Modèle
        self.settings_frame = ctk.CTkFrame(self.sidebar)
        self.settings_frame.pack(pady=20, padx=15, fill="x")
        ctk.CTkLabel(self.settings_frame, text="Paramètres Modèle", font=ctk.CTkFont(weight="bold")).pack(pady=5)
        ctk.CTkLabel(self.settings_frame, text="Modèle: gemini-3-pro-image-preview").pack(pady=2)
        ctk.CTkLabel(self.settings_frame, text="Résolution: 2K (High Res)").pack(pady=2)
        ctk.CTkLabel(self.settings_frame, text="Ratio: 16:9").pack(pady=2)

        # Console
        ctk.CTkLabel(self.sidebar, text="Logs:", anchor="w").pack(fill="x", padx=15, side="bottom", pady=(0,5))
        self.log_box = ctk.CTkTextbox(self.sidebar, height=180, font=("Consolas", 11))
        self.log_box.pack(pady=(0, 20), padx=10, fill="x", side="bottom")

        # 2. MAIN PANEL
        self.main_panel = ctk.CTkScrollableFrame(self, label_text="MATRICE MÉTÉO (39 VARIABLES)")
        self.main_panel.grid(row=0, column=1, sticky="nsew", padx=20, pady=20)

        self.create_buttons()
        self.log("Système prêt. SDK 'google-genai' chargé.")
        self.log("En attente de l'image de référence...")

    def log(self, message):
        self.log_box.insert("end", f"> {message}\n")
        self.log_box.see("end")

    def load_image(self):
        try:
            # Compatible Mac/Windows
            file_path = filedialog.askopenfilename(
                title="Choisir l'image de référence",
                filetypes=[("Images", "*.png"), ("Images", "*.jpg"), ("Images", "*.jpeg")]
            )
            if not file_path: return

            self.reference_image_path = file_path
            self.pil_image = Image.open(file_path).convert('RGB')
            
            # Preview
            aspect = self.pil_image.width / self.pil_image.height
            h = 140
            w = int(h * aspect)
            preview_img = ctk.CTkImage(light_image=self.pil_image, dark_image=self.pil_image, size=(w, h))
            self.img_preview.configure(image=preview_img, text="")
            self.log(f"Image chargée : {os.path.basename(file_path)}")

        except Exception as e:
            self.log(f"ERREUR CHARGEMENT: {e}")

    def generate_task(self, filename, prompt_details):
        """La fonction qui s'exécute en arrière-plan pour ne pas figer l'interface"""
        api_key = self.api_entry.get().strip()
        
        # --- 1. SETUP CLIENT (NOUVEAU SDK) ---
        try:
            client = genai.Client(api_key=api_key)
        except Exception as e:
            self.log(f"❌ Erreur Client: {e}")
            return

        # --- 2. CONSTRUCTION DU PROMPT (Editing Strategy) ---
        # Selon la doc : "Using the provided image, change..."
        base_prompt = (
            "Using the provided image of Lyon city, modify the scene to match this weather condition: "
            f"{prompt_details}. "
            "Keep the exact same buildings geometry, camera angle, and claymorphism style. "
            "Only change the lighting, sky, ground texture, and foliage colors."
        )

        self.log(f"⏳ Gemini 3 Pro travaille sur : {filename}...")

        output_dir = os.path.join(os.getcwd(), "output_lyon_gemini3")
        os.makedirs(output_dir, exist_ok=True)
        final_path = os.path.join(output_dir, filename)

        try:
            # --- 3. APPEL API (DOCUMENTATION EXACTE) ---
            # Modèle: gemini-3-pro-image-preview (Nano Banana Pro)
            # Contents: [Prompt Text, PIL Image]
            
            response = client.models.generate_content(
                model="gemini-3-pro-image-preview",
                contents=[base_prompt, self.pil_image],
                config=types.GenerateContentConfig(
                    response_modalities=['IMAGE'], # On veut juste l'image
                    image_config=types.ImageConfig(
                        aspect_ratio="16:9",
                        image_size="2K" # Haute résolution comme demandé
                    )
                )
            )

            # --- 4. RÉCUPÉRATION ---
            image_saved = False
            
            if response.parts:
                for part in response.parts:
                    # Le SDK peut renvoyer l'image directement via inline_data ou une méthode helper
                    if part.inline_data:
                        # Conversion manuelle si besoin, ou via helper
                        img_bytes = part.inline_data.data # C'est déjà des bytes déchiffrés souvent
                        
                        # Si c'est un objet Image PIL direct (feature du SDK):
                        try:
                            # Tentative via la méthode pratique si disponible dans cette version
                            if hasattr(part, "as_image"):
                                img = part.as_image()
                                img.save(final_path)
                                image_saved = True
                                break
                        except:
                             pass
                             
                        # Sauvegarde brute si méthode helper absente
                        if not image_saved:
                            import base64
                            # Parfois c'est du raw bytes, parfois b64 string
                            if isinstance(img_bytes, str):
                                img_data = base64.b64decode(img_bytes)
                            else:
                                img_data = img_bytes
                                
                            with open(final_path, "wb") as f:
                                f.write(img_data)
                            image_saved = True

            if image_saved:
                self.log(f"✅ SUCCÈS : {filename} sauvegardé (2K) !")
            else:
                self.log(f"⚠️ API a répondu mais pas d'image. Vérifiez la console.")
                print(response)

        except Exception as e:
            self.log(f"❌ ERREUR API : {e}")

    def trigger_generation(self, filename, prompt_add):
        if not self.reference_image_path:
            messagebox.showerror("Erreur", "Chargez l'image d'abord !")
            return
        if not self.api_entry.get().strip():
            messagebox.showerror("Erreur", "Clé API manquante !")
            return

        # Lancer dans un thread pour ne pas bloquer l'interface (Mac friendly)
        threading.Thread(target=self.generate_task, args=(filename, prompt_add)).start()

    # --- BUTTONS FACTORY ---
    def add_group(self, title):
        lbl = ctk.CTkLabel(self.main_panel, text=title, font=ctk.CTkFont(size=16, weight="bold"), anchor="w", text_color="#E37400")
        lbl.pack(fill="x", pady=(25, 5))
        frame = ctk.CTkFrame(self.main_panel)
        frame.pack(fill="x", pady=5)
        return frame

    def add_btn(self, parent, text, filename, prompt_add, color=None):
        btn_color = color if color else ["#E37400", "#A95700"]
        btn = ctk.CTkButton(parent, text=text, height=35, fg_color=btn_color, 
                            command=lambda: self.trigger_generation(filename, prompt_add))
        btn.pack(side="left", padx=5, pady=8, expand=True, fill="x")

    def create_buttons(self):
        # 1. BEAU TEMPS
        f1 = self.add_group("A. BEAU TEMPS (Ciel Dégagé)")
        seasons = [
            ("Printemps", "spring, light green trees, pink cherry blossoms, flowers", "spring"),
            ("Été", "summer, vibrant dark green trees, blue sky", "summer"),
            ("Automne", "autumn, orange red yellow trees, fall foliage", "autumn"),
            ("Hiver", "winter, naked trees, brown branches", "winter")
        ]
        times = [
            ("Jour", "bright sunlight, clear blue sky, sharp shadows", "day"),
            ("Golden", "golden hour sunset, warm orange sky", "golden"),
            ("Nuit", "night time, dark blue sky, street lights glowing", "night")
        ]
        for s_name, s_p, s_f in seasons:
            row = ctk.CTkFrame(f1, fg_color="transparent")
            row.pack(fill="x", pady=2)
            ctk.CTkLabel(row, text=s_name, width=80).pack(side="left")
            for t_name, t_p, t_f in times:
                self.add_btn(row, t_name, f"A_{s_f}_{t_f}.png", f"{s_p}, {t_p}")

        # 2. GRIS
        f2 = self.add_group("B. GRIS / NUAGEUX")
        for s_name, s_p, s_f in seasons:
            row = ctk.CTkFrame(f2, fg_color="transparent")
            row.pack(fill="x", pady=2)
            ctk.CTkLabel(row, text=s_name, width=80).pack(side="left")
            self.add_btn(row, "Jour", f"B_{s_f}_grey_day.png", f"{s_p}, overcast grey sky, flat lighting", color="gray")
            self.add_btn(row, "Nuit", f"B_{s_f}_grey_night.png", f"{s_p}, night, cloudy sky", color="#333")

        # 3. PLUIE
        f3 = self.add_group("C. PLUIE")
        for s_name, s_p, s_f in seasons:
            row = ctk.CTkFrame(f3, fg_color="transparent")
            row.pack(fill="x", pady=2)
            ctk.CTkLabel(row, text=s_name, width=80).pack(side="left")
            self.add_btn(row, "Jour", f"C_{s_f}_rain_day.png", f"{s_p}, rainy weather, wet ground reflections", color="#4285F4")
            self.add_btn(row, "Nuit", f"C_{s_f}_rain_night.png", f"{s_p}, rainy night, wet streets", color="#0F3678")

        # 4. NEIGE & AUTRES
        f4 = self.add_group("D. NEIGE & AUTRES")
        row_s = ctk.CTkFrame(f4, fg_color="transparent")
        row_s.pack(fill="x")
        ctk.CTkLabel(row_s, text="Neige:", width=80).pack(side="left")
        
        snow_p = "heavy snow covering the city, white roof tops, frozen river, winter"
        self.add_btn(row_s, "Jour", "D_snow_day.png", f"{snow_p}, daylight", color="#AEC6CF")
        self.add_btn(row_s, "Golden", "D_snow_golden.png", f"{snow_p}, sunset light", color="#D4AF37")
        self.add_btn(row_s, "Nuit", "D_snow_night.png", f"{snow_p}, night time", color="#2C3E50")

        # Orages
        row_o = ctk.CTkFrame(f4, fg_color="transparent")
        row_o.pack(fill="x", pady=5)
        ctk.CTkLabel(row_o, text="Orages:", width=80).pack(side="left")
        for s_name, s_p, s_f in seasons:
             self.add_btn(row_o, s_name[:3], f"E_storm_{s_f}.png", f"{s_p}, thunderstorm, lightning, dark sky", color="#5E35B1")

        # ============================================
        # F. EASTER EGGS - ÉVÉNEMENTS SPÉCIAUX LYON
        # ============================================
        f5 = self.add_group("F. EASTER EGGS - ÉVÉNEMENTS SPÉCIAUX")

        easter_eggs = [
            # (Nom affiché, nom_fichier, prompt_jour, prompt_nuit, couleur_jour, couleur_nuit)
            (
                "✨ Fête des Lumières (8-11 déc)",
                "fete_lumieres",
                # JOUR: Préparatifs, installations visibles, ciel d'hiver dégagé, PAS DE NEIGE
                "early december, clear pale blue winter sky, bright cold daylight, "
                "no snow on ground, bare trees, festive banners hanging on lampposts, "
                "colorful light installations visible on buildings but turned off during day, "
                "projection screens being set up, anticipation atmosphere, crisp winter air",
                # NUIT: Le spectacle ! Projections, lumières partout
                "winter night, spectacular light projections on Basilique de Fourvière, "
                "colorful artistic illuminations on buildings, glowing light installations, "
                "purple blue pink lights reflecting on Saône river, magical atmosphere, "
                "Lyon Fête des Lumières festival, no snow",
                "#7B68EE",  # Medium slate blue (jour)
                "#4B0082"   # Indigo (nuit)
            ),
            (
                "🎄 Noël (24-25 déc)",
                "noel",
                # JOUR: Ambiance hivernale festive, décorations, marchés
                "winter, light snow on rooftops, clear cold sky, bright winter sun, "
                "Christmas decorations on streets, festive garlands, "
                "Christmas market stalls with red roofs, decorated Christmas trees, "
                "warm cozy atmosphere, holiday spirit",
                # NUIT: Magie de Noël, lumières chaudes
                "Christmas Eve night, clear starry sky, gentle snow falling, "
                "warm glowing Christmas lights on buildings, illuminated Christmas trees, "
                "golden fairy lights garlands, cozy warm windows glowing, "
                "magical peaceful Christmas atmosphere, stars twinkling",
                "#228B22",  # Forest green (jour)
                "#8B0000"   # Dark red (nuit)
            ),
            (
                "🎆 Nouvel An (31 déc - 1er jan)",
                "nouvel_an",
                # JOUR: Dernier jour de l'année, préparatifs
                "winter, clear bright sky, festive decorations still up, "
                "New Year preparations, champagne bottles visible, "
                "party atmosphere building up, end of year vibes, "
                "people preparing celebrations",
                # NUIT: Feux d'artifice, célébrations
                "New Year's Eve midnight, spectacular fireworks over Fourvière, "
                "colorful explosions in clear night sky, golden sparkles, "
                "confetti falling, champagne celebration, "
                "crowds cheering, Bonne Année banners, magical night",
                "#FFD700",  # Gold (jour)
                "#FF4500"   # Orange red (nuit)
            ),
            (
                "🇫🇷 14 Juillet (Fête Nationale)",
                "14_juillet",
                # JOUR: Défilé, drapeaux, fête nationale
                "summer, bright sunny day, clear blue sky, "
                "French tricolor flags bleu blanc rouge everywhere, "
                "Bastille Day celebration, military parade atmosphere, "
                "patriotic decorations, festive national holiday",
                # NUIT: Feux d'artifice tricolores
                "Bastille Day night, spectacular fireworks in blue white red colors, "
                "French flag colors illuminating the sky over Lyon, "
                "tricolor lights on buildings, national celebration, "
                "clear summer night, crowds watching fireworks",
                "#0055A4",  # French blue (jour)
                "#EF4135"   # French red (nuit)
            ),
            (
                "🎃 Halloween (31 oct)",
                "halloween",
                # JOUR: Ambiance automnale mystérieuse, décorations
                "late autumn, overcast mysterious sky with dramatic clouds, "
                "orange and brown fall colors, Halloween decorations, "
                "carved pumpkins on doorsteps, spider webs, "
                "eerie but playful atmosphere, bare trees",
                # NUIT: Nuit d'Halloween, lune, ambiance spooky
                "Halloween night, full moon in clear dark sky, "
                "spooky orange glow from jack-o-lanterns, "
                "mysterious fog in streets, bats silhouettes, "
                "purple and orange lights, haunted atmosphere but whimsical",
                "#FF7518",  # Pumpkin orange (jour)
                "#2D1B4E"   # Dark purple (nuit)
            ),
            (
                "💕 Saint-Valentin (14 fév)",
                "saint_valentin",
                # JOUR: Romantique, décorations ville, PAS DE PERSONNAGES EN GROS PLAN
                "mid february, soft romantic winter light, clear pale blue sky, "
                "Valentine's Day decorations on streets, red and pink heart garlands "
                "hanging between buildings, heart-shaped balloons tied to lampposts, "
                "flower shop displays with red roses, no people close-up, "
                "romantic city atmosphere, soft warm feeling",
                # NUIT: Soirée romantique, lumières douces, décorations ville
                "Valentine's night, clear starry sky with soft pink hue, "
                "romantic pink and red fairy lights on bridges over Saône river, "
                "heart-shaped light decorations on buildings, "
                "warm glowing restaurant windows in distance, "
                "rose petals on ground, love atmosphere, no people close-up",
                "#FF69B4",  # Hot pink (jour)
                "#C71585"   # Medium violet red (nuit)
            ),
        ]

        for event_name, filename_base, prompt_day, prompt_night, color_day, color_night in easter_eggs:
            row = ctk.CTkFrame(f5, fg_color="transparent")
            row.pack(fill="x", pady=3)
            ctk.CTkLabel(row, text=event_name, width=220, anchor="w").pack(side="left", padx=5)

            # Bouton JOUR
            self.add_btn(
                row,
                "☀️ Jour",
                f"F_{filename_base}_day.png",
                prompt_day,
                color=color_day
            )

            # Bouton NUIT
            self.add_btn(
                row,
                "🌙 Nuit",
                f"F_{filename_base}_night.png",
                prompt_night,
                color=color_night
            )

if __name__ == "__main__":
    app = LyonGeminiV3App()
    app.mainloop()