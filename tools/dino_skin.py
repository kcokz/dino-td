# tools/dino_skin.py
# THE SKIN CLOSE TO (the player, 2026-09-30: the skin's detail and its marks, chosen for the dinosaurs' going-over;
# "它们最终要有个图鉴系统" -- they will be looked at close). A body's colours were at its vertices: its marks as wide
# as a ring's spacing, and the skin itself smooth as a toy's. Here the skin is drawn at a texture's grain and
# baked:
#
#   ITS SCALES: pebbly scales all over (a cell pattern in the body's own space), small on the head and the feet
#   and larger over the back, where a row of bigger ones runs; the grooves between them dark. Crocodile-line
#   skin has its own: square belly scales in rows, and rows of rectangular ones up the flanks.
#   ITS COLOURS: the marks painted at the vertices (tools/dino_body.py: the back dark, the belly pale, bands,
#   a stripe through the eye), each scale a shade apart from the next, fine speckles.
#
# Worked out as a shader in Blender and baked, on an unwrapped copy of the body's surface, to two images --
# the colour and the normal (the scales' relief) -- that the exported model carries (glTF: baseColorTexture,
# normalTexture).
#
# Blender only (bpy); used by tools/generate_dinos.py.

import math

import bpy


def unwrap(obj):
    """Its surface opened out flat: islands at the angles where it bends most, packed into the square."""
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.004, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')


def _node(nt, kind, loc, **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def bake_material(spec):
    """The skin as a shader: the painted colours ("Col"), scales and grooves, speckles; its relief as bumps."""
    sk = spec.get("scales", {})
    mat = bpy.data.materials.new("SkinBake")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = _node(nt, "ShaderNodeOutputMaterial", (1400, 0))
    bsdf = _node(nt, "ShaderNodeBsdfPrincipled", (1100, 0))
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    col = _node(nt, "ShaderNodeAttribute", (-600, 300))
    col.attribute_name = "Col"
    tex = _node(nt, "ShaderNodeTexCoord", (-1200, -100))
    geo = _node(nt, "ShaderNodeNewGeometry", (-1200, -400))

    # How much a place faces up (the back) or down (the belly): from its normal, in the body's own space.
    sep = _node(nt, "ShaderNodeSeparateXYZ", (-1000, -400))
    tnorm = _node(nt, "ShaderNodeVectorTransform", (-1100, -500))
    tnorm.vector_type = 'NORMAL'
    tnorm.convert_from = 'WORLD'
    tnorm.convert_to = 'OBJECT'
    nt.links.new(geo.outputs["Normal"], tnorm.inputs["Vector"])
    nt.links.new(tnorm.outputs["Vector"], sep.inputs["Vector"])
    dorsal = _node(nt, "ShaderNodeMapRange", (-800, -400))
    dorsal.inputs["From Min"].default_value = sk.get("dorsal_from", 0.55)
    dorsal.inputs["From Max"].default_value = 0.95
    nt.links.new(sep.outputs["Z"], dorsal.inputs["Value"])

    # Scales: a cell pattern in the body's own space, the size of a scale; its edges the grooves.
    small = _node(nt, "ShaderNodeTexVoronoi", (-600, -100))
    small.voronoi_dimensions = '3D'
    small.feature = 'DISTANCE_TO_EDGE'
    small.inputs["Scale"].default_value = sk.get("cells", 160.0)
    small.inputs["Randomness"].default_value = 0.9
    nt.links.new(tex.outputs["Object"], small.inputs["Vector"])
    small_col = _node(nt, "ShaderNodeTexVoronoi", (-600, -350))
    small_col.voronoi_dimensions = '3D'
    small_col.feature = 'F1'
    small_col.inputs["Scale"].default_value = sk.get("cells", 160.0)
    small_col.inputs["Randomness"].default_value = 0.9
    nt.links.new(tex.outputs["Object"], small_col.inputs["Vector"])
    # Each scale a dome, not a flat tile between cracks: its height rises smoothly from its edge over `groove`
    # of its width (a tile's flat top and thin dark edges read as dried mud).
    groove = _node(nt, "ShaderNodeMapRange", (-350, -100))
    groove.interpolation_type = 'SMOOTHSTEP'
    groove.inputs["From Min"].default_value = 0.0
    groove.inputs["From Max"].default_value = sk.get("groove", 0.18)
    nt.links.new(small.outputs["Distance"], groove.inputs["Value"])
    # Bigger scales over the back: a coarser pattern, as the skin faces up.
    big = _node(nt, "ShaderNodeTexVoronoi", (-600, -650))
    big.voronoi_dimensions = '3D'
    big.feature = 'DISTANCE_TO_EDGE'
    big.inputs["Scale"].default_value = sk.get("cells", 160.0) * sk.get("dorsal_size", 0.45)
    big.inputs["Randomness"].default_value = 0.7
    nt.links.new(tex.outputs["Object"], big.inputs["Vector"])
    big_groove = _node(nt, "ShaderNodeMapRange", (-350, -650))
    big_groove.interpolation_type = 'SMOOTHSTEP'
    big_groove.inputs["From Min"].default_value = 0.0
    big_groove.inputs["From Max"].default_value = sk.get("groove", 0.18) * 0.8
    nt.links.new(big.outputs["Distance"], big_groove.inputs["Value"])
    pebbles = _node(nt, "ShaderNodeMix", (-100, -300))
    pebbles.data_type = 'FLOAT'
    nt.links.new(dorsal.outputs["Result"], pebbles.inputs["Factor"])
    nt.links.new(groove.outputs["Result"], pebbles.inputs["A"])
    nt.links.new(big_groove.outputs["Result"], pebbles.inputs["B"])
    height = pebbles
    sc = spec.get("scutes")
    if sc:
        mask = _node(nt, "ShaderNodeAttribute", (-1200, -1200))
        mask.attribute_name = "Mask"
        mask_rgb = _node(nt, "ShaderNodeSeparateColor", (-1000, -1200))
        nt.links.new(mask.outputs["Color"], mask_rgb.inputs["Color"])
        height = _scutes(nt, tex, sep, pebbles, sc, mask_rgb.outputs["Red"])
    height_out = height.outputs["Result"]

    # Colour: the painted colour, each scale a shade apart, the grooves darker, fine speckles.
    jitter = _node(nt, "ShaderNodeMapRange", (-350, -350))
    jitter.inputs["From Min"].default_value = 0.0
    jitter.inputs["From Max"].default_value = 1.0
    jitter.inputs["To Min"].default_value = 1.0 - sk.get("tint", 0.14)
    jitter.inputs["To Max"].default_value = 1.0 + sk.get("tint", 0.14)
    sep_c = _node(nt, "ShaderNodeSeparateColor", (-450, -450))
    nt.links.new(small_col.outputs["Color"], sep_c.inputs["Color"])
    nt.links.new(sep_c.outputs["Red"], jitter.inputs["Value"])
    tint_out = jitter.outputs["Result"]
    # Feathers where it had them (tools/dino_feathers.py): the coat, and each feather's vane.
    if spec.get("feathers"):
        height_out, tint_out = _plumage(nt, tex, height_out, tint_out, spec["feathers"])
    # Horn and bare plate where it had them (sculpt.Body.horn): no scales -- a smooth sheath with a fine grain.
    if spec.get("horn"):
        height_out, tint_out = _horn(nt, tex, height_out, tint_out, spec["horn"])
    shade = _node(nt, "ShaderNodeMapRange", (-100, -100))
    shade.inputs["From Min"].default_value = 0.0
    shade.inputs["From Max"].default_value = 1.0
    shade.inputs["To Min"].default_value = 1.0 - sk.get("groove_dark", 0.45)
    shade.inputs["To Max"].default_value = 1.0
    nt.links.new(height_out, shade.inputs["Value"])
    speck = _node(nt, "ShaderNodeTexNoise", (-600, 600))
    speck.inputs["Scale"].default_value = sk.get("cells", 160.0) * 1.6
    speck.inputs["Detail"].default_value = 2.0
    nt.links.new(tex.outputs["Object"], speck.inputs["Vector"])
    speck_k = _node(nt, "ShaderNodeMapRange", (-350, 600))
    speck_k.inputs["From Min"].default_value = 0.35
    speck_k.inputs["From Max"].default_value = 0.65
    speck_k.inputs["To Min"].default_value = 1.0 - sk.get("speckle", 0.12)
    speck_k.inputs["To Max"].default_value = 1.0 + sk.get("speckle", 0.12) * 0.5
    nt.links.new(speck.outputs["Fac"], speck_k.inputs["Value"])
    m1 = _node(nt, "ShaderNodeMix", (100, 300))
    m1.data_type = 'RGBA'
    m1.blend_type = 'MULTIPLY'
    m1.inputs["Factor"].default_value = 1.0
    nt.links.new(col.outputs["Color"], m1.inputs["A"])
    comb = _node(nt, "ShaderNodeMath", (-100, 100))
    comb.operation = 'MULTIPLY'
    nt.links.new(tint_out, comb.inputs[0])
    nt.links.new(shade.outputs["Result"], comb.inputs[1])
    comb2 = _node(nt, "ShaderNodeMath", (100, 100))
    comb2.operation = 'MULTIPLY'
    nt.links.new(comb.outputs["Value"], comb2.inputs[0])
    nt.links.new(speck_k.outputs["Result"], comb2.inputs[1])
    to_rgb = _node(nt, "ShaderNodeCombineColor", (300, 100))
    for ch in ("Red", "Green", "Blue"):
        nt.links.new(comb2.outputs["Value"], to_rgb.inputs[ch])
    nt.links.new(to_rgb.outputs["Color"], m1.inputs["B"])
    nt.links.new(m1.outputs["Result"], bsdf.inputs["Base Color"])

    # The relief: the scales' heights as bumps.
    bump = _node(nt, "ShaderNodeBump", (800, -300))
    bump.inputs["Strength"].default_value = sk.get("relief", 0.6)
    bump.inputs["Distance"].default_value = sk.get("depth", 0.0015)
    nt.links.new(height_out, bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.7
    return mat


def _math(nt, op, loc, a=None, b=None, c=None):
    """A math node doing `op` on `a`, `b` (and `c`): each a socket to link or a number to set."""
    n = _node(nt, "ShaderNodeMath", loc)
    n.operation = op
    for i, x in enumerate((a, b, c)):
        if x is None:
            continue
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = float(x)
        else:
            nt.links.new(x, n.inputs[i])
    return n.outputs["Value"]


def _range(nt, loc, value, a, b, lo, hi, smooth=False):
    """`value` from a..b mapped to lo..hi (clamped; eased if `smooth`)."""
    n = _node(nt, "ShaderNodeMapRange", loc)
    if smooth:
        n.interpolation_type = 'SMOOTHSTEP'
    n.inputs["From Min"].default_value = a
    n.inputs["From Max"].default_value = b
    n.inputs["To Min"].default_value = lo
    n.inputs["To Max"].default_value = hi
    nt.links.new(value, n.inputs["Value"])
    return n.outputs["Result"]


def _mixf(nt, loc, factor, a, b):
    n = _node(nt, "ShaderNodeMix", loc)
    n.data_type = 'FLOAT'
    nt.links.new(factor, n.inputs["Factor"])
    nt.links.new(a, n.inputs["A"])
    nt.links.new(b, n.inputs["B"])
    return n.outputs["Result"]


def _plumage(nt, tex, scale_height, scale_tint, fe):
    """The feathered skin (the "Feather" attribute, tools/dino_feathers.py). THE COAT: overlapping feather tips --
    cells drawn out along the body -- over fine streaks running with it. A VANE: barbs slanting out from the
    shaft towards the tip, the shaft itself pale and raised, bars across it. Returns the height and the tint, each
    the scales' where there are no feathers."""
    attr = _node(nt, "ShaderNodeAttribute", (-1900, 1000))
    attr.attribute_name = "Feather"
    parts = _node(nt, "ShaderNodeSeparateColor", (-1700, 1000))
    nt.links.new(attr.outputs["Color"], parts.inputs["Color"])
    coat_k, vane_k, u = parts.outputs["Red"], parts.outputs["Green"], parts.outputs["Blue"]
    across = attr.outputs["Alpha"]

    # The coat.
    cells = fe.get("coat_cells", 120.0)
    drawn = _node(nt, "ShaderNodeVectorMath", (-1700, 800))
    drawn.operation = 'MULTIPLY'
    drawn.inputs[1].default_value = (1.0, fe.get("coat_stretch", 0.45), 1.0)
    nt.links.new(tex.outputs["Object"], drawn.inputs[0])
    tips = _node(nt, "ShaderNodeTexVoronoi", (-1500, 800))
    tips.voronoi_dimensions = '3D'
    tips.feature = 'DISTANCE_TO_EDGE'
    tips.inputs["Scale"].default_value = cells
    tips.inputs["Randomness"].default_value = 0.85
    nt.links.new(drawn.outputs["Vector"], tips.inputs["Vector"])
    tips_col = _node(nt, "ShaderNodeTexVoronoi", (-1500, 600))
    tips_col.voronoi_dimensions = '3D'
    tips_col.feature = 'F1'
    tips_col.inputs["Scale"].default_value = cells
    tips_col.inputs["Randomness"].default_value = 0.85
    nt.links.new(drawn.outputs["Vector"], tips_col.inputs["Vector"])
    tips_rgb = _node(nt, "ShaderNodeSeparateColor", (-1300, 600))
    nt.links.new(tips_col.outputs["Color"], tips_rgb.inputs["Color"])
    fine = _node(nt, "ShaderNodeVectorMath", (-1700, 400))
    fine.operation = 'MULTIPLY'
    fine.inputs[1].default_value = (1.0, 0.07, 1.0)
    nt.links.new(tex.outputs["Object"], fine.inputs[0])
    streak = _node(nt, "ShaderNodeTexNoise", (-1500, 400))
    streak.inputs["Scale"].default_value = cells * 4.0
    streak.inputs["Detail"].default_value = 3.0
    nt.links.new(fine.outputs["Vector"], streak.inputs["Vector"])
    tip_h = _range(nt, (-1100, 800), tips.outputs["Distance"], 0.0, fe.get("coat_groove", 0.3), 0.0, 1.0, smooth=True)
    coat_h = _math(nt, 'MULTIPLY_ADD', (-900, 800), tip_h, 0.3,
                   _math(nt, 'MULTIPLY_ADD', (-1100, 400), streak.outputs["Fac"], 0.15, 0.55))
    t = fe.get("coat_tint", 0.1)
    s = fe.get("streak", 0.12)
    coat_t = _math(nt, 'MULTIPLY', (-900, 600),
                   _range(nt, (-1100, 600), tips_rgb.outputs["Red"], 0.0, 1.0, 1.0 - t, 1.0 + t),
                   _range(nt, (-1100, 300), streak.outputs["Fac"], 0.3, 0.7, 1.0 - s, 1.0 + s * 0.6))

    # A vane: `across` is 0 at the leading edge, a half at the shaft, 1 at the trailing edge.
    off = _math(nt, 'MULTIPLY', (-1300, 100), _math(nt, 'ABSOLUTE', (-1500, 100), _math(nt, 'SUBTRACT', (-1700, 100), across, 0.5)), 2.0)
    barbs = fe.get("barbs", 40.0)
    phase = _math(nt, 'MULTIPLY_ADD', (-1100, 100), off, barbs * fe.get("slant", 0.6), _math(nt, 'MULTIPLY', (-1300, 0), u, barbs))
    barb = _range(nt, (-700, 100), _math(nt, 'SINE', (-900, 100), _math(nt, 'MULTIPLY', (-1000, 0), phase, 2.0 * math.pi)),
                  -1.0, 1.0, 0.0, 1.0)
    shaft = _range(nt, (-1100, -100), off, 0.0, fe.get("shaft", 0.08), 1.0, 0.0, smooth=True)
    bar_phase = _math(nt, 'MULTIPLY_ADD', (-1100, -250), off, fe.get("bar_slant", 0.5), _math(nt, 'MULTIPLY', (-1300, -250), u, fe.get("bars", 5.0)))
    bar_wave = _math(nt, 'SINE', (-900, -250), _math(nt, 'MULTIPLY', (-1000, -300), bar_phase, 2.0 * math.pi))
    bar = _range(nt, (-700, -250), bar_wave, fe.get("bar_width", 0.3) - 0.15, fe.get("bar_width", 0.3) + 0.15, 0.0, 1.0, smooth=True)
    vane_h = _math(nt, 'MULTIPLY_ADD', (-500, 100), barb, 0.4, _math(nt, 'MULTIPLY', (-700, 0), shaft, 0.6))
    vane_t = _math(nt, 'MULTIPLY', (-300, -150),
                   _math(nt, 'MULTIPLY', (-500, -150), _range(nt, (-500, -300), bar, 0.0, 1.0, 1.0, 1.0 - fe.get("bar_strength", 0.5)),
                         _range(nt, (-500, -50), barb, 0.0, 1.0, 0.85, 1.0)),
                   _range(nt, (-500, -400), shaft, 0.0, 1.0, 1.0, 1.0 + fe.get("shaft_light", 0.5)))

    height = _mixf(nt, (-100, 900), vane_k, _mixf(nt, (-300, 900), coat_k, scale_height, coat_h), vane_h)
    tint = _mixf(nt, (-100, 700), vane_k, _mixf(nt, (-300, 700), coat_k, scale_tint, coat_t), vane_t)
    return height, tint


def _horn(nt, tex, scale_height, scale_tint, hn):
    """Where the skin is horn (the "Horn" attribute): no scales, a sheath with a fine grain over it and a faint
    mottle -- the scales' height and tint kept elsewhere."""
    attr = _node(nt, "ShaderNodeAttribute", (-1900, 1500))
    attr.attribute_name = "Horn"
    k = _node(nt, "ShaderNodeSeparateColor", (-1700, 1500))
    nt.links.new(attr.outputs["Color"], k.inputs["Color"])
    grain = _node(nt, "ShaderNodeTexNoise", (-1500, 1500))
    grain.inputs["Scale"].default_value = hn.get("grain", 60.0)
    grain.inputs["Detail"].default_value = 3.0
    nt.links.new(tex.outputs["Object"], grain.inputs["Vector"])
    blot = _node(nt, "ShaderNodeTexNoise", (-1500, 1300))
    blot.inputs["Scale"].default_value = hn.get("grain", 60.0) * 0.12
    nt.links.new(tex.outputs["Object"], blot.inputs["Vector"])
    h = _range(nt, (-1300, 1500), grain.outputs["Fac"], 0.3, 0.7, 0.5 - hn.get("relief", 0.15), 0.5 + hn.get("relief", 0.15))
    t = _math(nt, 'MULTIPLY', (-1100, 1300),
              _range(nt, (-1300, 1300), blot.outputs["Fac"], 0.3, 0.7, 1.0 - hn.get("mottle", 0.12), 1.0 + hn.get("mottle", 0.12)),
              _range(nt, (-1300, 1100), grain.outputs["Fac"], 0.3, 0.7, 1.0 - hn.get("streak", 0.06), 1.0 + hn.get("streak", 0.06)))
    return (_mixf(nt, (-900, 1500), k.outputs["Red"], scale_height, h),
            _mixf(nt, (-900, 1300), k.outputs["Red"], scale_tint, t))


def _scutes(nt, tex, normal_xyz, pebbles, sc, where):
    """The crocodile line's skin: square scales in rows across the belly, where the skin faces down, and long
    ones in rows up the flanks -- a grid in the body's own space, its lines the grooves -- the pebbly scales
    kept over the back. Returns the height they make, mixed in by which way the skin faces."""
    size_along, size_across = sc["size"]
    # The rows not ruled: the grid bent a little by a slow noise, a scale's width at most.
    warp = _node(nt, "ShaderNodeTexNoise", (-1300, -900))
    warp.inputs["Scale"].default_value = 1.0 / (size_along * sc.get("warp_every", 6.0))
    nt.links.new(tex.outputs["Object"], warp.inputs["Vector"])
    centred = _node(nt, "ShaderNodeVectorMath", (-1150, -900))
    centred.operation = 'SUBTRACT'
    centred.inputs[1].default_value = (0.5, 0.5, 0.5)
    nt.links.new(warp.outputs["Color"], centred.inputs[0])
    bent = _node(nt, "ShaderNodeVectorMath", (-1050, -900))
    bent.operation = 'MULTIPLY_ADD'
    bent.inputs[1].default_value = (size_across * sc.get("warp", 0.8),) * 3
    nt.links.new(centred.outputs["Vector"], bent.inputs[0])
    nt.links.new(tex.outputs["Object"], bent.inputs[2])
    scale = _node(nt, "ShaderNodeVectorMath", (-900, -1000))
    scale.operation = 'MULTIPLY'
    scale.inputs[1].default_value = (1.0 / size_across, 1.0 / size_along, 1.0 / size_across)
    nt.links.new(bent.outputs["Vector"], scale.inputs[0])
    frac = _node(nt, "ShaderNodeVectorMath", (-700, -1000))
    frac.operation = 'FRACTION'
    nt.links.new(scale.outputs["Vector"], frac.inputs[0])
    centre = _node(nt, "ShaderNodeVectorMath", (-550, -1000))
    centre.operation = 'SUBTRACT'
    centre.inputs[1].default_value = (0.5, 0.5, 0.5)
    nt.links.new(frac.outputs["Vector"], centre.inputs[0])
    absolute = _node(nt, "ShaderNodeVectorMath", (-400, -1000))
    absolute.operation = 'ABSOLUTE'
    nt.links.new(centre.outputs["Vector"], absolute.inputs[0])
    parts = _node(nt, "ShaderNodeSeparateXYZ", (-250, -1000))
    nt.links.new(absolute.outputs["Vector"], parts.inputs["Vector"])
    # Belly: its grid across (x) and along (y); flanks: along (y) and up (z).
    edges = {}
    for key, (a, b) in (("belly", ("X", "Y")), ("flank", ("Y", "Z"))):
        mx = _node(nt, "ShaderNodeMath", (-100, -950 if key == "belly" else -1150))
        mx.operation = 'MAXIMUM'
        nt.links.new(parts.outputs[a], mx.inputs[0])
        nt.links.new(parts.outputs[b], mx.inputs[1])
        rng = _node(nt, "ShaderNodeMapRange", (100, -950 if key == "belly" else -1150))
        rng.inputs["From Min"].default_value = 0.5
        rng.inputs["From Max"].default_value = 0.5 - sc.get("mortar", 0.08)
        nt.links.new(mx.outputs["Value"], rng.inputs["Value"])
        edges[key] = rng
    # Which way the skin faces: down (the belly), sideways (the flanks), up (kept pebbly).
    belly_k = _node(nt, "ShaderNodeMapRange", (-250, -1350))
    belly_k.inputs["From Min"].default_value = sc.get("belly_below", -0.5) + 0.12
    belly_k.inputs["From Max"].default_value = sc.get("belly_below", -0.5) - 0.12
    nt.links.new(normal_xyz.outputs["Z"], belly_k.inputs["Value"])
    flank_k = _node(nt, "ShaderNodeMapRange", (-250, -1550))
    flank_k.inputs["From Min"].default_value = sc.get("flank_below", 0.35) + 0.12
    flank_k.inputs["From Max"].default_value = sc.get("flank_below", 0.35) - 0.12
    nt.links.new(normal_xyz.outputs["Z"], flank_k.inputs["Value"])
    # Only on the body and the tail (the mask), not the head or the limbs.
    flank_here = _node(nt, "ShaderNodeMath", (100, -1450))
    flank_here.operation = 'MULTIPLY'
    nt.links.new(flank_k.outputs["Result"], flank_here.inputs[0])
    nt.links.new(where, flank_here.inputs[1])
    belly_here = _node(nt, "ShaderNodeMath", (100, -1300))
    belly_here.operation = 'MULTIPLY'
    nt.links.new(belly_k.outputs["Result"], belly_here.inputs[0])
    nt.links.new(where, belly_here.inputs[1])
    on_flank = _node(nt, "ShaderNodeMix", (300, -1150))
    on_flank.data_type = 'FLOAT'
    nt.links.new(flank_here.outputs["Value"], on_flank.inputs["Factor"])
    nt.links.new(pebbles.outputs["Result"], on_flank.inputs["A"])
    nt.links.new(edges["flank"].outputs["Result"], on_flank.inputs["B"])
    on_belly = _node(nt, "ShaderNodeMix", (500, -1000))
    on_belly.data_type = 'FLOAT'
    nt.links.new(belly_here.outputs["Value"], on_belly.inputs["Factor"])
    nt.links.new(on_flank.outputs["Result"], on_belly.inputs["A"])
    nt.links.new(edges["belly"].outputs["Result"], on_belly.inputs["B"])
    return on_belly


def bake(obj, spec, size=2048, name="skin", normal_size=None):
    """The body's skin (its first material's faces) baked to a colour image and a normal image; the object then
    wears a material that reads them. Returns the two images: the colour kept as a JPEG, the normal as a PNG
    at `normal_size` (the relief needs less than the colour, and a PNG of it is heavy)."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 4
    scene.render.bake.margin = 8
    unwrap(obj)
    bake_mat = bake_material(spec)
    final = obj.data.materials[0]
    obj.data.materials[0] = bake_mat
    colour = bpy.data.images.new(name + "_skin", size, size, alpha=False)
    normal = bpy.data.images.new(name + "_skin_normal", size, size, alpha=False)
    normal.colorspace_settings.name = 'Non-Color'
    target = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
    bake_mat.node_tree.nodes.active = target
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    target.image = colour
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
    target.image = normal
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', use_clear=True)
    if normal_size and normal_size != size:
        normal.scale(normal_size, normal_size)
    # Saved as files of their kinds, so the exporter keeps each as it is (a JPEG colour, a PNG relief).
    import os
    import tempfile
    for img, ext, kind in ((colour, ".jpg", 'JPEG'), (normal, ".png", 'PNG')):
        img.file_format = kind
        img.filepath_raw = os.path.join(tempfile.gettempdir(), img.name + ext)
        img.save()
    # What it wears from now on: the two images, no vertex colours.
    worn = bpy.data.materials.new(final.name)
    worn.use_nodes = True
    nt = worn.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = colour
    t_nrm = nt.nodes.new("ShaderNodeTexImage")
    t_nrm.image = normal
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(t_nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = spec.get("roughness", 0.62)
    obj.data.materials[0] = worn
    bpy.data.materials.remove(bake_mat)
    for attr_name in ("Col", "Mask", "Feather", "Horn"):
        a = obj.data.color_attributes.get(attr_name)
        if a is not None:
            obj.data.color_attributes.remove(a)
    return colour, normal
