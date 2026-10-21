# tools/paint_cards.py
# THE CARDS' PICTURES, PAINTED (GAME-DESIGN 23; the player, 2026-10-20: "每个牌的图片应该作成2D的美工画，而不是还是3D
# 的，而且美工画要有艺术感，然后3D在这个2D美工化的基础上，画出3D模型，类似pokeymon的卡"). Each card's picture -- each
# building, the raise, each affix -- each creature of ours, each monster, each star dinosaur, each place: a hand-painted
# illustration made with Stable Diffusion XL on this machine's GPU, in one style for all of them. A creature is painted
# over its own 3D model (tools/paint_sources.gd renders them; ControlNet keeps the painting to the model's outline), so
# the painting and the model in the game are the same animal. A building and a star dinosaur are painted from their
# description alone: the paintings lead, and the 3D models follow them. An affix's thing is an object cut out of its
# painting and set on one plate (an empty mossy altar).
#
#   C:/Users/jobzk/ai/sd/Scripts/python.exe dino-raid/tools/paint_cards.py [--src DIR] [--force] [keys...]
#   (a picture already there is kept unless --force, or unless it is named)
#
# Writes dino-raid/assets/art/<key>.jpg. Needs: torch (CUDA), diffusers,
# opencv, rembg; the models stabilityai/stable-diffusion-xl-base-1.0, diffusers/controlnet-canny-sdxl-1.0 and
# madebyollin/sdxl-vae-fp16-fix (the decoder that stays in half precision: twice as quick on a 12 GB card).

import os
import sys
import zlib

import cv2
import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "assets", "art")
HF = os.environ.get("HF_HOME_MODELS", r"C:\Users\jobzk\ai\hf")
WORK = os.environ.get("PAINT_WORK", r"C:\Users\jobzk\ai\work")    # what is made once and kept (the affix plate)
SDXL = "stabilityai/stable-diffusion-xl-base-1.0"
CANNY = "diffusers/controlnet-canny-sdxl-1.0"
VAE = "madebyollin/sdxl-vae-fp16-fix"       # the decoder fixed for half precision: no upcasting each picture

# First in each prompt (the text encoders read only so far): the look every picture shares.
STYLE = "painterly fantasy card art, hand-painted, rich brush strokes, vibrant colours, golden rim light, storybook"
CUTE = "cute cartoon creature, big eyes, "
# What no picture has. The text encoders read only the first 77 tokens of this too: what one picture must not have goes
# before it (main), the most needed of these first.
NEG = ("human, person, people, rider, text, watermark, signature, logo, photo, 3d render, frame, border, card, ui, "
       "blurry, lowres, deformed, extra limbs, ugly, dark, muddy, plastic, grainy")

# More to keep out of one picture (a colour the place would otherwise lend it, what its words would otherwise bring in).
MORE_NEG = {"u_white": "green skin, green scales, green dinosaur",
            "b_nest_scav": "bird, magpie, jay, crow", "b_horde_totem": "dinosaur, creature, animal",
            "b_stabilizer": "creature, animal, bird, dragon", "b_mine": "path, road, stairs, bridge",
            "b_vanguard": "path, stairs, tree house, single tent"}

PLACES = {
    "rain": "in a lush prehistoric rainforest with giant ferns and sunbeams",
    "lava": "in a volcanic wasteland with glowing lava cracks and ash in the air",
    "bog": "in a misty swamp with dead trees, reeds and green water",
    "ice": "on frozen ice fields with blue ice crystals and snow",
    "sand": "in a golden desert with dunes and red rocks under a hot sun",
    "sea": "on a sunny rocky coast with waves and tide pools",
}

# Our creatures: what each looks like (its 3D model guides the painting).
UNITS = {
    "red": "a cute red velociraptor dinosaur with a cream belly and big yellow eyes, crouched to pounce",
    "blue": "a cute slender blue coelophysis dinosaur spitting a glowing cyan glob",
    "green": "a cute green armoured desmatosuchus with a dark green shell edged in cream and cream spikes, standing guard",
    "gold": "a cute powerful golden-yellow allosaurus dinosaur roaring, dust rising",
    "white": "a cute pure white psittacosaurus with snow-white scales, an orange beak and a crest of orange quills, warm "
             "healing sparkles",
    "scav": "a cute brown dilong dinosaur with a feather crest, a sack of shiny trinkets, holding a stone",
    "mutant": "a cute pink sinornithosaurus with a feather crest and little wings, glowing gene sparks around it",
    "falcon": "a cute orange pterosaur diving through the sky, wings spread wide",
    "thunder": "a cute blue stegosaurus with golden back plates, crackling with lightning",
    "miasma": "a cute green feathered sinocalliopteryx breathing a cloud of poison mist",
    "magma": "a cute red-orange ceratosaurus with a nose horn, cracks of glowing lava on its skin",
    "titan": "a huge brown tyrannosaurus titan roaring, colossal and fierce",
}
UNIT_PLACE = {"red": "rain", "blue": "rain", "green": "rain", "gold": "rain", "white": "rain", "scav": "sand",
              "mutant": "bog", "falcon": "sea", "thunder": "ice", "miasma": "bog", "magma": "lava", "titan": "rain"}

ALIEN = "a cartoon alien monster with glowing orange eyes, "
ENEMIES = {
    "grey": ("a grey six-legged alien crawler bug with pincer jaws and antennae", "rain"),
    "purple": ("a purple six-legged alien crawler with a glowing sac on its back", "rain"),
    "black": ("a black armoured alien beetle crawler with heavy jaws", "rain"),
    "spore": ("a round green alien spore blob covered in glowing spore balls", "rain"),
    "mite": ("a tiny round yellow-green alien mite", "rain"),
    "mini_rain": ("a big green armoured alien crawler with huge jaws", "rain"),
    "mini_rain2": ("a big alien crawler with a row of bone spikes along its back", "rain"),
    "boss_rain": ("a giant alien brood mother blob on six legs carrying glowing eggs, a crown of glowing spikes", "rain"),
    "beetle": ("a dark red lava beetle with a horn and glowing embers in its shell", "lava"),
    "salamander": ("an orange fire salamander lizard with a burning tail", "lava"),
    "mini_lava": ("a hulking lava warden beast with rocks and glowing embers on its back", "lava"),
    "mini_lava2": ("a long spiky volcano monitor lizard", "lava"),
    "boss_lava": ("a colossal horned lava beast covered in rocks and glowing magma", "lava"),
    "leech": ("a brown segmented mud leech with a pink sucker mouth", "bog"),
    "moth": ("a yellow-green venom moth with glowing eye spots on its wings", "bog"),
    "mini_bog": ("a giant warty bog frog", "bog"),
    "mini_bog2": ("a giant poison toad with warts and glowing green poison sacs", "bog"),
    "boss_bog": ("a huge swamp mother blob with tentacles and warts, a crown of spikes", "bog"),
    "frostfang": ("an icy pale alien beast with fangs and ice crystals on its back", "ice"),
    "shard": ("a floating blue ice crystal creature with one glowing eye", "ice"),
    "mini_ice": ("a big ice-shell grub crawler covered in ice crystals", "ice"),
    "mini_ice2": ("a hulking white-furred snow berserker beast with horns", "ice"),
    "boss_ice": ("an ice hive queen, a big blue alien crawler with a crown of ice crystals", "ice"),
    "sandworm": ("a tan segmented sandworm with a ring of teeth bursting from the sand", "sand"),
    "scorpion": ("a brown alien scorpion with pincers and a glowing stinger", "sand"),
    "mini_sand": ("a great spiked sandworm bursting from the dunes", "sand"),
    "mini_sand2": ("an armoured venomtail scorpion king with huge pincers", "sand"),
    "boss_sand": ("a colossal sandstorm worm beast with a crown of spikes in a whirling sandstorm", "sand"),
    "crab": ("a red alien shell crab with eye stalks and big claws", "sea"),
    "jelly": ("a glowing translucent purple jellyfish alien floating", "sea"),
    "mini_sea": ("a great claw crab with enormous pincers", "sea"),
    "mini_sea2": ("a teal sea serpent with fangs and a fin rising from the waves", "sea"),
    "boss_sea": ("a huge deep sea hive mother blob with tentacles and many glowing eyes, a crown of spikes", "sea"),
}

# The homeland's buildings: a gene-tech homestead in a jungle, not a primitive camp (the player, 2026-10-20: "这个不能太
# 原始，比如还需要研究所，我觉得塞尔达风格可以") -- pale stone, warm timber, copper and brass, glass tanks of glowing gene
# fluid, moss and vines, cloth in the nest's colour. Each painted alone in a clearing from three-quarters above: the
# design its 3D model is made after. Each nest its own kind of place, fitting what it hatches (the player, 2026-10-20:
# "不同的类型恐龙需要不同的巢穴，现在只是颜色变了一下").
HOME = "alone in a small jungle clearing, three-quarter view from above"
NESTS = {
    "nest_red": "a raptor hatchery den, a woven nest of red glowing eggs inside a ring of tall sharp stone fangs, a brass "
                "heat lamp, a red banner, ferns",
    "nest_blue": "a stilted reed hatchery over a small pond, a reed nest of blue glowing eggs high on wooden stilts with a "
                 "ladder, a copper water pipe",
    "nest_green": "a squat round burrow shaped like a tortoise shell of overlapping green stone plates, a low round door, "
                  "green glowing eggs",
    "nest_gold": "a big rocky den of heavy stacked boulders with a wide cave mouth, bone trophies, golden glowing eggs on "
                 "straw",
    "nest_white": "a small glass greenhouse dome over a soft moss nest of white glowing eggs, white flowers, a tiny healing "
                  "spring",
    "nest_scav": "a big messy nest of scrap brass, gears and rope in the fork of a short gnarled tree, shiny trinkets, "
                 "brown eggs",
    "nest_mutant": "a gene lab incubator, three glass vats of glowing pink fluid with embryos inside, copper pipes and "
                   "cables on a stone base",
}
BUILDINGS = {
    "pool": "a culture pool, a round carved stone basin of glowing green bubbling biomass, brass pipes, a little hand pump",
    "spore_pool": "a spore pool, a stone basin of glowing yellow-green spores ringed by giant puffball mushrooms",
    "horde_totem": "a tall carved wooden totem pole topped with a dinosaur skull, red war banners hanging from it, a big "
                   "hide drum at its foot",
    "sampler": "a small field research station, a brass and glass hut with a dish antenna and racks of glowing sample "
               "tubes",
    "stabilizer": "a gene stabilizer, a tall bronze pylon tower on a stone base, three floating rings of glowing light "
                  "around it",
    "gene_bank": "a gene research institute, a round stone building under a big glass dome full of glowing DNA helixes, "
                 "copper pipes",
    "mine": "a gold mine, a timber-framed tunnel door cut into a mossy rock cliff, a glowing gold ore vein, mine rails "
            "with a cart full of gold nuggets",
    "forge": "a stone forge with a tall chimney, glowing molten metal, an anvil and bellows, sparks",
    "vault": "a treasure vault, a heavy carved stone building with a round golden door, coins spilling out",
    "market": "a trading post, a wooden market stall with striped awnings, crates, jars and hanging goods",
    "champion_hall": "a champion hall, a small white marble hall with columns and a golden crown on its roof",
    "watchtower": "a tall stone watchtower with a wooden lookout platform and a red flag",
    "vanguard": "a vanguard camp, a ring of sharpened log palisade walls with round shields hung on them, spears, a war "
                "flag in the middle",
}
BUILD_NEG = "town, city, castle, village, many buildings, crowd, soldiers, interior, indoors"
RAISE = "a small stone and timber building growing taller inside wooden scaffolding, golden sparks, a glowing upward arrow"
# Each gene affix painted as the thing it grows: the object cut out and set large on one shared plate (an empty mossy
# altar) -- clear at a card's size, where a creature wearing a small one is not, and where a scene loses it.
AFFIXES = {
    "shell": "a heavy curved shell of steel-grey armour plates like a tortoise's back",
    "blade": "a pair of gleaming curved steel forearm blades with leather straps, crossed",
    "acid": "a glowing green acid sac in a glass flask, acid dripping",
    "wings": "a pair of big leathery orange wings spread wide",
    "plasma": "a crackling blue-white plasma orb held in a bronze cage",
    "poison": "a curved purple poison stinger barb dripping glowing venom",
    "flame": "a crest of bright magical fire blazing in a bronze brazier",
    "haste": "a pair of glowing cyan feathered fins streaked with motion trails",
    "hide": "a slab of thick bony brown hide studded with bone scutes",
    "horn": "a big curved polished ivory charging horn",
}
AFFIX_PLATE = "an empty mossy stone altar top in a dim jungle grotto, soft glowing green light, bokeh, nothing on it"
ITEM_NEG = "creature, animal, bird, person, woman, man, hand, building, stairs, door, book"
PLACE_ART = {
    "rain": "a lush prehistoric rainforest valley with giant ferns, waterfalls and sunbeams",
    "lava": "a volcanic wasteland with an erupting volcano, rivers of glowing lava and ash clouds",
    "bog": "a misty swamp with twisted dead trees, reeds and still green water",
    "ice": "vast frozen ice fields with towering blue ice crystals and snowy pines",
    "sand": "a golden desert of dunes and red rock arches under a blazing sun",
    "sea": "a sunny rocky coast with crashing waves, tide pools and palm trees",
}
# The star dinosaurs (Content.STARS): each a character of its own, doing what it does, in the park's jungle.
STARS = {
    "hoarder": "a cute orange oviraptor dinosaur hugging a big pile of glowing cards and eggs, mischievous grin",
    "mother": "a gentle green duck-billed maiasaura dinosaur mother curled round a nest of eggs, warm smile",
    "trader": "a cute blue pterosaur merchant flying with a bulging travel bag of goods",
    "scout": "a cute olive-green raptor dinosaur scout running fast with a little brass spyglass",
    "doctor": "a cute clever blue troodon dinosaur scientist wearing round spectacles, holding a glowing flask",
    "shield": "a cute stout grey ankylosaurus dinosaur with a club tail and an armoured back, standing guard",
    "saver": "a cute sandy protoceratops dinosaur counting a stack of gold coins on an abacus",
    "belly": "a cute round-bellied green diplodocus dinosaur happily munching leaves, very long neck",
    "tri": "a cute brave orange-brown triceratops dinosaur with a big frill and three horns",
    "scar": "a cute tough dark red velociraptor with a scar over one eye, confident grin",
    "fisher": "a cute teal crocodile-like phytosaur fishing in a pond, a fish in its jaws",
    "bounty": "a cute brown postosuchus reptile wearing a bandana, a pouch of gold coins at its side",
    "horn": "a cute pink parasaurolophus dinosaur trumpeting a loud call through its long head crest, music notes",
    "spitter": "a cute teal dilophosaurus dinosaur with two head crests spitting a glowing glob",
    "oldking": "a grand old feathered yutyrannus tyrant dinosaur king with grey feathers and a battered crown",
    "sickle": "a cute fluffy therizinosaurus dinosaur with huge sickle claws and a gentle face",
    "neck": "a cute tall brachiosaurus dinosaur reaching the high treetops, very long neck",
    "queen": "a majestic purple duck-billed dinosaur queen with a golden crown on a huge glowing nest of eggs",
    "goldcrown": "a golden guanlong dinosaur with a tall glowing golden head crest, sparkling gold coins",
    "firstbird": "a glowing archaeopteryx, the first bird, with rainbow feathered wings and gene light",
    "warlord": "a mighty golden-red tyrannosaurus rex warlord roaring, battle scars, a war banner behind it",
    "titan": "a colossal argentinosaurus sauropod titan towering over the jungle, tiny trees at its feet",
}
# An object to cut out (an affix's thing): its own look, without the card painting's scenery.
ICON = "painterly fantasy game item icon, hand-painted, rich brush strokes, vibrant colours, golden rim light"
ICON_TAIL = "single object, whole object in view, centred, plain flat grey background"


def jobs():
    """Every picture: its key, its prompt, its guide (a 3D render's file, or None), and how it is cut ("card": a
    painting; "item": an object cut out and set on the affix plate)."""
    out = []
    for kind, says in UNITS.items():
        out.append(("u_" + kind, CUTE + says + ", " + PLACES[UNIT_PLACE[kind]], "u_" + kind, "card"))
    for kind, (says, place) in ENEMIES.items():
        out.append(("e_" + kind, ALIEN + says + ", " + PLACES[place], "e_" + kind, "card"))
    for kind, says in list(NESTS.items()) + list(BUILDINGS.items()):
        out.append(("b_" + kind, says + ", " + HOME, None, "card"))
    out.append(("raise", RAISE + ", " + HOME, None, "card"))
    for a, says in AFFIXES.items():
        out.append(("a_" + a, says, None, "item"))
    for s, says in STARS.items():
        out.append(("s_" + s, CUTE + says + ", " + PLACES["rain"], None, "card"))
    for place, says in PLACE_ART.items():
        out.append(("place_" + place, "wide landscape, " + says + ", no creatures, epic vista", None, "card"))
    return out


def _model(repo):
    """The local snapshot of `repo` in the models' cache (only the files used were fetched)."""
    root = os.path.join(HF, "models--" + repo.replace("/", "--"), "snapshots")
    return os.path.join(root, sorted(os.listdir(root))[-1])


def edges(img, alpha):
    """The outline of what is drawn (where it is opaque), and its inner edges, as ControlNet's canny wants them."""
    grey = cv2.cvtColor(np.array(img.convert("RGB")), cv2.COLOR_RGB2GRAY)
    e = cv2.Canny(grey, 60, 160)
    a = cv2.Canny((alpha > 127).astype(np.uint8) * 255, 50, 150)
    e = np.maximum(e, a)
    e[alpha < 10] = 0
    e = np.maximum(e, a)
    return Image.fromarray(np.stack([e] * 3, axis=-1))


def guide(src_dir, name, w, h):
    """A 3D render as the painting's starting point (on a warm soft background) and its edges; None when there is none."""
    path = os.path.join(src_dir, name + ".png")
    if not os.path.exists(path):
        return None, None
    rgba = Image.open(path).convert("RGBA")
    # Cropped to the painting's shape round its middle.
    sw, sh = rgba.size
    want = w / h
    if sw / sh > want:
        cw = int(sh * want)
        rgba = rgba.crop(((sw - cw) // 2, 0, (sw - cw) // 2 + cw, sh))
    else:
        ch = int(sw / want)
        rgba = rgba.crop((0, (sh - ch) // 2, sw, (sh - ch) // 2 + ch))
    rgba = rgba.resize((w, h), Image.LANCZOS)
    alpha = np.array(rgba)[:, :, 3]
    y = np.linspace(0.0, 1.0, h)[:, None, None]
    bg = (np.array([0.62, 0.72, 0.55]) * (1.0 - y) + np.array([0.32, 0.4, 0.24]) * y) * 255.0
    bg = np.broadcast_to(bg, (h, w, 3))
    rgb = np.array(rgba)[:, :, :3].astype(np.float32)
    a = alpha[:, :, None].astype(np.float32) / 255.0
    init = Image.fromarray((rgb * a + bg * (1.0 - a)).astype(np.uint8))
    return init, edges(init, alpha)


def affix_plate(free):
    """The plate every affix's thing is set on (an empty mossy altar), painted once and kept."""
    path = os.path.join(WORK, "affix_plate.png")
    if os.path.exists(path):
        return Image.open(path).convert("RGB")
    g = torch.Generator("cuda").manual_seed(777)
    img = free(STYLE + ", " + AFFIX_PLATE, negative_prompt=NEG + ", object, bottle, flask, creature, person", width=1216,
               height=768, num_inference_steps=32, guidance_scale=6.5, generator=g).images[0]
    img = img.resize((640, 404), Image.LANCZOS)
    os.makedirs(WORK, exist_ok=True)
    img.save(path)
    return img


def on_plate(item, plate):
    """`item` (cut out) large in the middle of the plate -- inside the part a card shows (its middle, about square) --
    with a soft shadow under it."""
    card = plate.copy().convert("RGBA")
    w, h = card.size
    item = item.crop(item.getbbox())
    k = min(w * 0.56 / item.width, h * 0.8 / item.height)
    item = item.resize((max(1, int(item.width * k)), max(1, int(item.height * k))), Image.LANCZOS)
    x = (w - item.width) // 2
    y = (h - item.height) // 2 + 8
    shadow = Image.new("L", card.size, 0)
    ImageDraw.Draw(shadow).ellipse([w * 0.5 - item.width * 0.4, y + item.height - 18, w * 0.5 + item.width * 0.4,
                                    y + item.height + 12], fill=140)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    card = Image.composite(Image.new("RGBA", card.size, (8, 12, 6, 255)), card, shadow)
    card.alpha_composite(item, (x, y))
    return card.convert("RGB")


def main():
    args = sys.argv[1:]
    src = r"C:\Users\jobzk\ai\src"
    if "--src" in args:
        i = args.index("--src")
        src = args[i + 1]
        del args[i:i + 2]
    force = "--force" in args
    args = [a for a in args if a != "--force"]
    only = set(args)

    def done(key, cut):
        return os.path.exists(os.path.join(OUT, key + (".png" if cut == "cutout" else ".jpg")))
    todo = [j for j in jobs() if (j[0] in only) or (not only and (force or not done(j[0], j[3])))]
    print("%d to paint" % len(todo), flush=True)
    os.makedirs(OUT, exist_ok=True)
    from diffusers import AutoencoderKL, ControlNetModel, StableDiffusionXLControlNetPipeline, StableDiffusionXLPipeline
    controlnet = ControlNetModel.from_pretrained(_model(CANNY), torch_dtype=torch.float16, variant="fp16")
    vae = AutoencoderKL.from_pretrained(_model(VAE), torch_dtype=torch.float16)
    guided = StableDiffusionXLControlNetPipeline.from_pretrained(
        _model(SDXL), controlnet=controlnet, vae=vae, torch_dtype=torch.float16, variant="fp16", use_safetensors=True)
    guided.to("cuda")
    guided.vae.enable_slicing()
    free = StableDiffusionXLPipeline(**{k: v for k, v in guided.components.items() if k != "controlnet"})
    W, H = 1216, 768
    cutter = None
    plate = None
    for key, prompt, source, cut in todo:
        g = torch.Generator("cuda").manual_seed(zlib.crc32(key.encode()) % 100000)
        icon = cut in ("cutout", "item")
        text = ICON + ", " + prompt + ", " + ICON_TAIL if icon else STYLE + ", " + prompt
        extra = [MORE_NEG[key]] if key in MORE_NEG else []
        if key.startswith("b_") or key == "raise":
            extra.append(BUILD_NEG)
        if cut == "item":
            extra.append(ITEM_NEG)
        if icon:
            extra.append("scenery, landscape, sky, clouds, mist, smoke, cropped, head, skull, face, creature")
        neg = ", ".join(extra + [NEG])
        init, edge = guide(src, source, W, H) if source else (None, None)
        if init is not None:
            # Painted to the model's outline (its edges), all else -- its colours, the light, the place -- painted
            # freely; the last steps free of the outline too, so the brushwork is the painting's own.
            img = guided(text, negative_prompt=neg, image=edge, width=W, height=H, controlnet_conditioning_scale=0.62,
                         control_guidance_end=0.72, num_inference_steps=32, guidance_scale=6.5, generator=g).images[0]
        elif icon:
            img = free(text, negative_prompt=neg, width=1024, height=1024, num_inference_steps=32, guidance_scale=6.5,
                       generator=g).images[0]
        else:
            img = free(text, negative_prompt=neg, width=W, height=H, num_inference_steps=32, guidance_scale=6.5,
                       generator=g).images[0]
        if icon:
            if cutter is None:
                from rembg import new_session, remove
                cutter = (new_session("isnet-general-use"), remove)
            cutout = cutter[1](img, session=cutter[0])
            if cut == "item":
                if plate is None:
                    plate = affix_plate(free)
                on_plate(cutout, plate).save(os.path.join(OUT, key + ".jpg"), quality=90)
            else:
                cutout.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, key + ".png"))
        else:
            img.resize((640, 404), Image.LANCZOS).save(os.path.join(OUT, key + ".jpg"), quality=90)
        print("[OK] " + key, flush=True)


if __name__ == "__main__":
    main()
