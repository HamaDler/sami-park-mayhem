extends Node3D
# Bounded, pooled combat effects: blood mist and droplets, dust puffs, muzzle flash light and
# ground blood splatter. CPU particles because the project uses the Compatibility renderer.
# Blood follows the Call of Duty Zombies read: a quick red mist puff at the wound that billows
# and fades in ~0.3 s, a few droplets flicked out along the bullet, and a bigger burst on
# headshots/kills. All sprite shapes are generated from noise at startup, so nothing renders
# as a square and no texture files are needed.
const BLOOD_POOL: int=10
const DUST_POOL: int=6
const SPLAT_POOL: int=40
const SPLAT_LIFETIME: float=20.0
const MIST_COLORS:=[Color(.5,.03,.025,.8),Color(.44,.02,.02,.7),Color(.3,.012,.012,.3),Color(.22,.01,.01,0)]
const DROP_COLORS:=[Color(.42,.02,.02,1),Color(.36,.015,.015,.9),Color(.26,.01,.01,0)]
var mists: Array[CPUParticles3D]=[]
var drops: Array[CPUParticles3D]=[]
var blood_index: int=0
var dust: Array[CPUParticles3D]=[]
var dust_index: int=0
var splats: Array[MeshInstance3D]=[]
var splat_life: Array[float]=[]
var splat_index: int=0
var flash_quad: MeshInstance3D
var flash_light: OmniLight3D
var flash_time: float=0
var flash_peak: float=0
var random:=RandomNumberGenerator.new()
func _ready() -> void:
    top_level=true;global_transform=Transform3D.IDENTITY;random.randomize()
    var mist_textures: Array[Texture2D]=[_blot_texture(64,11,.34,.7,0,.75),_blot_texture(64,23,.32,.75,0,.7)]
    var drop_texture: Texture2D=_blot_texture(32,5,.36,.25,0)
    for i in BLOOD_POOL:
        mists.append(_mist(mist_textures[i%mist_textures.size()]))
        drops.append(_droplets(drop_texture))
    var puff: Texture2D=load("res://assets/dust_puff.svg")
    for i in DUST_POOL:dust.append(_dust(puff))
    var splat_textures: Array[Texture2D]=[_blot_texture(128,41,.28,.12,16),_blot_texture(128,57,.26,.1,22),_blot_texture(128,73,.3,.12,12)]
    var plane:=PlaneMesh.new();plane.size=Vector2.ONE
    for i in SPLAT_POOL:
        var splat:=MeshInstance3D.new();splat.mesh=plane;splat.top_level=true;splat.visible=false
        splat.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var material:=StandardMaterial3D.new();material.albedo_texture=splat_textures[i%splat_textures.size()]
        material.albedo_color=Color(.32,.015,.015,.85);material.roughness=.35
        material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.render_priority=-1;splat.material_override=material
        add_child(splat);splats.append(splat);splat_life.append(0)
    flash_quad=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.34,.34);flash_quad.mesh=quad
    var flash_texture:=GradientTexture2D.new();flash_texture.fill=GradientTexture2D.FILL_RADIAL;flash_texture.fill_from=Vector2(.5,.5);flash_texture.fill_to=Vector2(.5,0)
    var flash_ramp:=Gradient.new();flash_ramp.offsets=PackedFloat32Array([0,.25,1]);flash_ramp.colors=PackedColorArray([Color(1,.97,.85,1),Color(1,.75,.3,.85),Color(1,.5,.1,0)])
    flash_texture.gradient=flash_ramp
    var flash_material:=StandardMaterial3D.new();flash_material.albedo_texture=flash_texture;flash_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;flash_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;flash_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
    flash_quad.material_override=flash_material;flash_quad.top_level=true;flash_quad.visible=false;flash_quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(flash_quad)
    flash_light=OmniLight3D.new();flash_light.light_color=Color(1,.8,.45);flash_light.omni_range=6;flash_light.light_energy=0;flash_light.shadow_enabled=false;flash_light.top_level=true;add_child(flash_light)
# White alpha blot with a noise-warped edge. radius is in UV units (0.5 = texture edge); the edge
# wobbles between ~0.72x and 1.22x of it, so keep radius <= ~0.36 to stay clear of the borders.
# satellites>0 adds scattered droplets around it (ground splatter).
func _blot_texture(size: int, seed_value: int, radius: float, softness: float, satellites: int, falloff: float=0.0) -> ImageTexture:
    var noise:=FastNoiseLite.new();noise.seed=seed_value;noise.frequency=4.0/size;noise.fractal_octaves=3
    var image:=Image.create(size,size,false,Image.FORMAT_RGBA8)
    var drops_at: Array[Vector3]=[]
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    for i in satellites:
        var angle: float=rng.randf()*TAU;var reach: float=rng.randf_range(radius*1.05,.44)
        drops_at.append(Vector3(.5+cos(angle)*reach,.5+sin(angle)*reach,rng.randf_range(.012,.035)))
    var alphas:=PackedFloat32Array();alphas.resize(size*size)
    for y in size:
        for x in size:
            var d: float=Vector2((x+.5)/size-.5,(y+.5)/size-.5).length()
            var edge: float=radius*(.72+.5*(noise.get_noise_2d(x,y)*.5+.5))
            alphas[y*size+x]=(1.0-smoothstep(edge-softness*edge,edge,d))*(1.0-falloff*clampf(d/edge,0,1))
    # Satellite droplets only touch their own small pixel box.
    for drop: Vector3 in drops_at:
        var r: int=ceili(drop.z*size)+1;var cx: int=int(drop.x*size);var cy: int=int(drop.y*size)
        for y in range(maxi(0,cy-r),mini(size,cy+r+1)):
            for x in range(maxi(0,cx-r),mini(size,cx+r+1)):
                var d: float=Vector2((x+.5)/size-drop.x,(y+.5)/size-drop.y).length()
                alphas[y*size+x]=maxf(alphas[y*size+x],1.0-smoothstep(drop.z*.6,drop.z,d))
    for y in size:
        for x in size:
            # Slightly uneven density inside so it reads as liquid, not a flat disc.
            var alpha: float=alphas[y*size+x]*(.82+.18*noise.get_noise_2d(x*3+97,y*3+31))
            image.set_pixel(x,y,Color(1,1,1,clampf(alpha,0,1)))
    return ImageTexture.create_from_image(image)
func _material(texture: Texture2D) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;material.vertex_color_use_as_albedo=true;material.albedo_texture=texture
    # Without this, particle billboards ignore per-particle scale and every sprite renders 1 m wide.
    material.billboard_keep_scale=true
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
    return material
func _base(texture: Texture2D, colors: Array, offsets: PackedFloat32Array) -> CPUParticles3D:
    var particles:=CPUParticles3D.new();particles.one_shot=true;particles.emitting=false;particles.explosiveness=1
    particles.local_coords=false;particles.direction=Vector3.FORWARD;particles.fixed_fps=60;particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var ramp:=Gradient.new();ramp.offsets=offsets;ramp.colors=PackedColorArray(colors);particles.color_ramp=ramp
    var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=_material(texture);particles.mesh=quad
    add_child(particles);return particles
func _mist(texture: Texture2D) -> CPUParticles3D:
    var particles:=_base(texture,MIST_COLORS,PackedFloat32Array([0,.12,.55,1]))
    particles.lifetime=.4;particles.spread=55;particles.gravity=Vector3(0,-1.2,0)
    particles.damping_min=3;particles.damping_max=5;particles.angle_min=0;particles.angle_max=360
    var grow:=Curve.new();grow.add_point(Vector2(0,.35));grow.add_point(Vector2(.3,.85));grow.add_point(Vector2(1,1.0));particles.scale_amount_curve=grow
    return particles
func _droplets(texture: Texture2D) -> CPUParticles3D:
    var particles:=_base(texture,DROP_COLORS,PackedFloat32Array([0,.7,1]))
    particles.lifetime=.5;particles.spread=28;particles.gravity=Vector3(0,-13,0);particles.damping_min=.3;particles.damping_max=1
    return particles
func _dust(texture: Texture2D) -> CPUParticles3D:
    var particles:=_base(texture,[Color(.62,.58,.5,.55),Color(.62,.58,.5,0)],PackedFloat32Array([0,1]))
    particles.amount=8;particles.lifetime=.6;particles.spread=20;particles.gravity=Vector3(0,-.6,0)
    particles.initial_velocity_min=1.3;particles.initial_velocity_max=3.3;particles.damping_min=1;particles.damping_max=3
    particles.scale_amount_min=.15;particles.scale_amount_max=.55
    return particles
func _aim(particles: CPUParticles3D, point: Vector3, direction: Vector3) -> void:
    var forward: Vector3=direction.normalized() if direction.length_squared()>.0001 else Vector3.UP
    var side:=Vector3.UP if absf(forward.dot(Vector3.UP))<.95 else Vector3.RIGHT
    particles.global_transform=Transform3D(Basis.looking_at(forward,side),point)
func _fire(particles: CPUParticles3D) -> void:
    particles.restart();particles.emitting=true
# direction: bullet travel. heavy: headshot or kill — bigger mist and more droplets.
func blood_burst(point: Vector3, direction: Vector3, heavy: bool=false) -> void:
    var mist:=mists[blood_index];var drop:=drops[blood_index];blood_index=(blood_index+1)%mists.size()
    var travel: Vector3=direction.normalized() if direction.length_squared()>.0001 else Vector3.FORWARD
    # Hitboxes sit inside the skinned mesh and hunched zombies lean their heads over the chest.
    # Pulling the puff back along the bullet line keeps it on the same screen spot but in front
    # of the geometry that would otherwise hide it.
    var entry: Vector3=point-travel*.4
    # Mist puffs back toward the shooter and up, so the player sees it on the near side of the body.
    _aim(mist,entry,-travel*.7+Vector3.UP*.45)
    mist.amount=10 if heavy else 6
    mist.scale_amount_min=.26 if heavy else .2;mist.scale_amount_max=.5 if heavy else .36
    mist.initial_velocity_min=.4;mist.initial_velocity_max=1.5 if heavy else .9
    mist.spread=65 if heavy else 40
    _fire(mist)
    # Droplets are flicked out the far side along the bullet, then fall.
    _aim(drop,point,travel+Vector3.UP*.25)
    drop.amount=12 if heavy else 6
    drop.scale_amount_min=.03;drop.scale_amount_max=.065 if heavy else .05
    drop.initial_velocity_min=1.6;drop.initial_velocity_max=4.6 if heavy else 3.4
    _fire(drop)
func dust_puff(point: Vector3, normal: Vector3) -> void:
    var particles:=dust[dust_index];dust_index=(dust_index+1)%dust.size()
    _aim(particles,point,normal);_fire(particles)
func blood_splat(point: Vector3, size: float=1.0) -> void:
    var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.5,point-Vector3.UP*3,1)
    var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty() or hit.normal.y<.7:return
    var splat:=splats[splat_index];splat_life[splat_index]=SPLAT_LIFETIME;splat_index=(splat_index+1)%splats.size()
    var extent: float=size*.62*random.randf_range(.85,1.15)
    splat.global_transform=Transform3D(Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3(extent*random.randf_range(.8,1.2),1,extent)),hit.position+hit.normal*(.012+splat_index*.0004))
    (splat.material_override as StandardMaterial3D).albedo_color.a=.85;splat.visible=true
func muzzle_flash(point: Vector3, scale_factor: float=1.0) -> void:
    flash_quad.global_position=point;flash_quad.scale=Vector3.ONE*scale_factor*random.randf_range(.8,1.25)
    flash_quad.rotation.z=random.randf()*TAU;flash_quad.visible=true
    flash_light.global_position=point;flash_peak=2.4*scale_factor;flash_light.light_energy=flash_peak;flash_time=.05
func _process(delta: float) -> void:
    if flash_time>0:
        flash_time=maxf(0,flash_time-delta)
        flash_light.light_energy=flash_peak*flash_time/.05
        flash_quad.visible=flash_time>0
    for i in splats.size():
        if splat_life[i]<=0:continue
        splat_life[i]=maxf(0,splat_life[i]-delta)
        if splat_life[i]<3:(splats[i].material_override as StandardMaterial3D).albedo_color.a=.85*splat_life[i]/3
        if splat_life[i]==0:splats[i].visible=false
func clear() -> void:
    for i in splats.size():splat_life[i]=0;splats[i].visible=false
