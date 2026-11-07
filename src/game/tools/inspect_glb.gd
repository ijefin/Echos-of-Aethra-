# Lista malhas, ossos e animações de um .glb importado.
# godot --headless --path . -s res://src/game/tools/inspect_glb.gd -- res://caminho.glb
extends SceneTree


func _initialize() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	for n in scene.find_children("*", "", true, false):
		var line := "%s  [%s]" % [scene.get_path_to(n), n.get_class()]
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			line += "  surfaces=%d aabb=%s" % [mi.mesh.get_surface_count(), mi.get_aabb().size]
		if n is BoneAttachment3D:
			line += "  bone=" + (n as BoneAttachment3D).bone_name
		print(line)
		if n is Skeleton3D:
			var sk := n as Skeleton3D
			var bones: PackedStringArray = []
			for i in sk.get_bone_count():
				bones.append(sk.get_bone_name(i))
			print("  bones: ", ", ".join(bones))
		if n is AnimationPlayer:
			print("  anims: ", ", ".join((n as AnimationPlayer).get_animation_list()))
	quit()
