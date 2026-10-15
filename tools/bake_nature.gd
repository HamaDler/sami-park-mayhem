extends SceneTree
var asset_dir := "res://assets/nature/"
var material_cache: Dictionary = {}
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(asset_dir+"bake_models.json"))
	var all_models: Array=[]
	all_models.append_array(spec.trees)
	all_models.append_array(spec.details)
	var manifest: Dictionary={}
	for name: String in all_models:
		var model: Node3D=load(asset_dir+"models/"+name+".fbx").instantiate()
		root.add_child(model)
		var mesh := ArrayMesh.new()
		for instance: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var transform: Transform3D=model.global_transform.affine_inverse()*instance.global_transform
			for surface in instance.mesh.get_surface_count():
				var arrays: Array=instance.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				for i in verts.size():verts[i]=transform*verts[i]
				for i in normals.size():normals[i]=(transform.basis.inverse().transposed()*normals[i]).normalized()
				arrays[Mesh.ARRAY_VERTEX]=verts
				arrays[Mesh.ARRAY_NORMAL]=normals
				# Imported tangents refer to the source transform; regenerate after baking.
				arrays[Mesh.ARRAY_TANGENT]=null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				var source_mat: Material=instance.get_active_material(surface)
				var mat_name: String=source_mat.resource_name if source_mat else ""
				if mat_name.is_empty():mat_name="Grass" if name.begins_with("Grass") else "Flowers"
				mesh.surface_set_material(mesh.get_surface_count()-1,material_for(mat_name))
		var path := asset_dir+"meshes/"+name+".res"
		ResourceSaver.save(mesh,path)
		var bound: AABB=mesh.get_aabb()
		manifest[name]={"mesh":path,"size":[bound.size.x,bound.size.y,bound.size.z],"center":[bound.get_center().x,bound.get_center().y,bound.get_center().z]}
		model.queue_free()
		if name in spec.trees:
			await impostor(mesh,name,bound)
			manifest[name].impostor=asset_dir+"impostors/"+name+".res"
		print("BAKED ",name)
	var f:=FileAccess.open(asset_dir+"manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest,"  "))
	print("NATURE_BAKE_COMPLETE ",manifest.size())
	quit()
func material_for(name: String) -> Material:
	if material_cache.has(name):return material_cache[name]
	var texture_name:=name
	if name=="Rock":texture_name="Rocks"
	var leafy:=name.contains("Leaves") or name in ["Flowers","Grass"]
	var tint:=Color.WHITE
	if name.contains("Leaves"):tint=Color(0.28,0.46,0.24)
	if name=="Bush_Leaves":tint=Color(0.28,0.48,0.23)
	if name=="BirchTree_Leaves":tint=Color(0.30,0.48,0.24)
	if name=="MapleTree_Leaves":texture_name="MapleTree_Leaves_BW";tint=Color(0.18,0.36,0.13)
	if name=="Grass":tint=Color(0.50,0.68,0.42)
	var texture: Texture2D=load(asset_dir+"textures/"+texture_name+".png")
	var result: Material
	if leafy:
		var mat:=ShaderMaterial.new()
		mat.shader=load(asset_dir+"foliage.gdshader")
		mat.set_shader_parameter("leaf_texture",texture)
		mat.set_shader_parameter("tint",tint)
		mat.set_shader_parameter("wind_strength",0.04 if name=="Flowers" else 0.055)
		result=mat
	else:
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=texture
		mat.albedo_color=Color(0.9,0.87,0.81) if name=="Rock" else Color(0.83,0.83,0.78)
		mat.roughness=1.0
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		result=mat
	result.resource_name=name
	ResourceSaver.save(result,asset_dir+"materials/"+name+".tres")
	material_cache[name]=result
	return result
func impostor(mesh: Mesh, name: String, bound: AABB) -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(256,384)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color(0,0,0,0)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=0.6
	env.environment=settings
	viewport.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-43,-32,0)
	sun.light_energy=0.65
	viewport.add_child(sun)
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	viewport.add_child(instance)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=maxf(bound.size.y*1.1,maxf(bound.size.x,bound.size.z)*1.1*384.0/256.0)
	viewport.add_child(camera)
	var center:=bound.get_center()
	var horizontal_size:=maxf(bound.size.x,bound.size.z)*1.1
	var width:=maxf(horizontal_size,camera.size*256.0/384.0)
	var height:=camera.size
	var output:=ArrayMesh.new()
	var atlas:=Image.create(256,1024,false,Image.FORMAT_RGBA8)
	var all_positions:=PackedVector3Array()
	var all_uvs:=PackedVector2Array()
	var all_indices:=PackedInt32Array()
	for view in 3:
		if view==0:camera.position=center+Vector3(0,0,20);camera.look_at(center)
		elif view==1:camera.position=center+Vector3(20,0,0);camera.look_at(center)
		else:
			viewport.size=Vector2i(256,256)
			camera.size=horizontal_size
			camera.position=center+Vector3(0,20,0)
			camera.look_at(center,Vector3.FORWARD)
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		var texture_path:=asset_dir+"impostors/"+name+"_"+str(view)+".png"
		image.save_png(texture_path)
		# ImageTexture keeps the freshly generated capture available until next import.
		var texture:=ImageTexture.create_from_image(image)
		texture.resource_path=texture_path
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=texture
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold=.35
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var positions: PackedVector3Array
		if view==0:positions=PackedVector3Array([center+Vector3(-width/2,-height/2,0),center+Vector3(width/2,-height/2,0),center+Vector3(width/2,height/2,0),center+Vector3(-width/2,height/2,0)])
		elif view==1:positions=PackedVector3Array([center+Vector3(0,-height/2,width/2),center+Vector3(0,-height/2,-width/2),center+Vector3(0,height/2,-width/2),center+Vector3(0,height/2,width/2)])
		else:positions=PackedVector3Array([center+Vector3(-horizontal_size/2,bound.size.y*.20,-horizontal_size/2),center+Vector3(horizontal_size/2,bound.size.y*.20,-horizontal_size/2),center+Vector3(horizontal_size/2,bound.size.y*.20,horizontal_size/2),center+Vector3(-horizontal_size/2,bound.size.y*.20,horizontal_size/2)])
		image.convert(Image.FORMAT_RGBA8)
		var offset:=view*384
		atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(0,offset))
		all_positions.append_array(positions)
		var upper:=float(offset)/1024.0
		var lower:=float(offset+image.get_height())/1024.0
		all_uvs.append_array(PackedVector2Array([Vector2(0,lower),Vector2(1,lower),Vector2(1,upper),Vector2(0,upper)]))
		for index in [0,1,2,0,2,3]:all_indices.append(view*4+index)
	var atlas_path:=asset_dir+"impostors/"+name+"_atlas.png"
	atlas.save_png(atlas_path)
	var mat:=StandardMaterial3D.new()
	var texture:=ImageTexture.create_from_image(atlas)
	texture.resource_path=atlas_path
	mat.albedo_texture=texture
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold=.35
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=all_positions
	arrays[Mesh.ARRAY_TEX_UV]=all_uvs
	arrays[Mesh.ARRAY_INDEX]=all_indices
	output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	output.surface_set_material(0,mat)
	ResourceSaver.save(output,asset_dir+"impostors/"+name+".res")
	viewport.queue_free()
