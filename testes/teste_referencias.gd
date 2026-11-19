extends SceneTree
## Referências depois da organização das pastas: toda cena, recurso e script
## carrega; todo caminho "res://" citado existe; cada uid de ext_resource aponta
## para o caminho escrito; autoloads e cena inicial; nomes de arquivo em
## snake_case, sem espaços nem acentos; nada solto na raiz.

const PASTAS_DO_JOGO := ["res://cenas", "res://scripts", "res://recursos"]
const RAIZ_PERMITIDA := ["project.godot", "icon.svg", "icon.svg.import", "default_bus_layout.tres", ".gitignore", "README.md"]

var falhas := 0
var verificacoes := 0
var problemas: Array[String] = []


func _initialize() -> void:
	_rodar.call_deferred()


func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if condicao:
		print("  ok   - ", descricao)
	else:
		falhas += 1
		print("  FALHA - ", descricao)


## Todos os arquivos (caminhos res://) sob `pasta`, recursivamente.
func listar(pasta: String) -> Array[String]:
	var lista: Array[String] = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		return lista
	dir.include_hidden = false
	for arquivo in dir.get_files():
		lista.append(pasta.path_join(arquivo))
	for subpasta in dir.get_directories():
		lista.append_array(listar(pasta.path_join(subpasta)))
	return lista


func ler(caminho: String) -> String:
	return FileAccess.get_file_as_string(caminho)


func _rodar() -> void:

	var arquivos: Array[String] = []
	for pasta in PASTAS_DO_JOGO:
		arquivos.append_array(listar(pasta))

	print("-- estrutura")
	for pasta in ["res://cenas/menus", "res://cenas/fases", "res://cenas/personagens", "res://cenas/objetos", "res://scripts/menus", "res://scripts/fases", "res://scripts/personagens", "res://scripts/objetos", "res://scripts/sistemas", "res://recursos/imagens", "res://recursos/sons", "res://recursos/fontes", "res://testes", "res://documentos"]:
		if not DirAccess.dir_exists_absolute(pasta):
			problemas.append("pasta ausente: " + pasta)
	checar(problemas.is_empty(), "pastas da estrutura existem (cenas, scripts, recursos, testes, documentos)")
	problemas.clear()

	var soltos: Array[String] = []
	var raiz := DirAccess.open("res://")
	for arquivo in raiz.get_files():
		if arquivo not in RAIZ_PERMITIDA:
			soltos.append(arquivo)
	checar(soltos.is_empty(), "nada solto na raiz além de project.godot, icon.svg, default_bus_layout.tres e .gitignore %s" % (str(soltos) if not soltos.is_empty() else ""))

	var nomes_ruins: Array[String] = []
	var padrao := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9]+)+$")
	for caminho in arquivos:
		if padrao.search(caminho.get_file()) == null:
			nomes_ruins.append(caminho)
	checar(nomes_ruins.is_empty(), "nomes em snake_case, sem espaços, acentos ou maiúsculas %s" % (str(nomes_ruins) if not nomes_ruins.is_empty() else ""))

	print("-- tudo carrega")
	var cenas := 0
	var scripts := 0
	for caminho in arquivos:
		var extensao := caminho.get_extension()
		if extensao in ["tscn", "tres"]:
			var recurso := load(caminho)
			if recurso == null:
				problemas.append("não carrega: " + caminho)
			elif recurso is PackedScene:
				var instancia: Node = (recurso as PackedScene).instantiate()
				if instancia == null:
					problemas.append("não instancia: " + caminho)
				else:
					instancia.free()
				cenas += 1
		elif extensao in ["gd", "gdshader"]:
			var script := load(caminho)
			if script == null:
				problemas.append("não carrega: " + caminho)
			elif script is GDScript and not (script as GDScript).can_instantiate():
				problemas.append("não compila: " + caminho)
			scripts += 1
		elif extensao in ["png", "jpeg", "jpg", "svg", "mp3", "wav", "ttf"]:
			if not ResourceLoader.exists(caminho):
				problemas.append("recurso não importado: " + caminho)
	checar(problemas.is_empty(), "%d cenas instanciam e %d scripts/shaders carregam %s" % [cenas, scripts, str(problemas) if not problemas.is_empty() else ""])
	problemas.clear()

	print("-- caminhos e uids")
	var citados := 0
	var caminho_citado := RegEx.create_from_string("\"\\*?(res://[^\"]+)\"")
	var ext_resource := RegEx.create_from_string("\\[ext_resource[^\\]]*?uid=\"(uid://[a-z0-9]+)\"[^\\]]*?path=\"(res://[^\"]+)\"")
	var uids_ok := 0
	var textos: Array[String] = ["res://project.godot"]
	for caminho in arquivos:
		if caminho.get_extension() in ["tscn", "tres", "gd", "gdshader"]:
			textos.append(caminho)
	for teste in listar("res://testes"):
		if teste.get_extension() == "gd":
			textos.append(teste)
	for caminho in textos:
		var texto := ler(caminho)
		for achado in caminho_citado.search_all(texto):
			var alvo := achado.get_string(1)
			if alvo.begins_with("res://.godot") or alvo.contains("$"):
				continue
			citados += 1
			if not FileAccess.file_exists(alvo) and not DirAccess.dir_exists_absolute(alvo):
				problemas.append("%s cita %s, que não existe" % [caminho, alvo])
		for achado in ext_resource.search_all(texto):
			var uid := achado.get_string(1)
			var alvo := achado.get_string(2)
			var id := ResourceUID.text_to_id(uid)
			if not ResourceUID.has_id(id):
				problemas.append("%s: uid %s desconhecido (%s)" % [caminho, uid, alvo])
			elif ResourceUID.get_id_path(id) != alvo:
				problemas.append("%s: uid %s aponta para %s, não %s" % [caminho, uid, ResourceUID.get_id_path(id), alvo])
			else:
				uids_ok += 1
	checar(problemas.is_empty(), "%d caminhos citados existem e %d uids batem com o caminho %s" % [citados, uids_ok, str(problemas) if not problemas.is_empty() else ""])
	problemas.clear()

	print("-- projeto")
	var principal := String(ProjectSettings.get_setting("application/run/main_scene"))
	var caminho_principal := ResourceUID.get_id_path(ResourceUID.text_to_id(principal)) if principal.begins_with("uid://") else principal
	checar(caminho_principal == "res://cenas/menus/menu_inicial.tscn", "cena inicial: %s" % caminho_principal)
	var autoloads_ok := true
	for nome in ["Configuracoes", "Transicao", "Audio"]:
		var valor := String(ProjectSettings.get_setting("autoload/" + nome, ""))
		autoloads_ok = autoloads_ok and valor.begins_with("*res://scripts/sistemas/") and FileAccess.file_exists(valor.substr(1)) and root.get_node_or_null(nome) != null
	checar(autoloads_ok, "autoloads Configuracoes, Transicao e Audio em scripts/sistemas e carregados")
	checar(String(ProjectSettings.get_setting("application/config/name")) == "As aventuras de um jogador", "título do jogo: \"%s\"" % ProjectSettings.get_setting("application/config/name"))
	checar(OS.get_user_data_dir().ends_with("/Godot/app_userdata/As aventura de um jogador"), "pasta de dados do jogador preservada (configurações salvas continuam valendo)")

	print("\n%d verificações, %d falhas" % [verificacoes, falhas])
	quit(falhas)
