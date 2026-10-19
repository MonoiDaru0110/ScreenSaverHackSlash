class_name VisualFx
extends Node
## 背景段階変化（転生連動）およびオーラを制御するノード。
## オーバーレイ本体のスタイルはシーン(main.tscn)側のシェーダーマテリアルで設定する。

@export var bg_stage_rect: ColorRect
@export var aura_rect: ColorRect
## オーラ有効時の発光強度 (0〜1)
@export_range(0.0, 1.0) var aura_strength: float = 1.0
## 段階変更時のフェード時間(秒)
@export var fade_time: float = 1.5

var _bg_shown_stage: float = 0.0
var _bg_tween: Tween = null

var _aura_enabled: bool = false
var _aura_shown: float = 0.0
var _aura_tween: Tween = null


func _ready() -> void:
	if aura_rect:
		aura_rect.visible = false
		var mat := aura_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("rect_size", aura_rect.size)
			mat.set_shader_parameter("strength", 0.0)

	# 転生シグナルに接続 (転生するごとに背景が1段階ずつ進行)
	GameData.reincarnation_performed.connect(_on_reincarnation_performed)

	# 初回反映 (アニメーションなし)
	_update_background_for_reincarnation(false)


func _on_reincarnation_performed() -> void:
	# 転生時はアニメーション付きで背景段階を進める
	_update_background_for_reincarnation(true)


func _update_background_for_reincarnation(animated: bool) -> void:
	if not bg_stage_rect:
		return

	var reinc_lvl: int = GameData.reincarnation_level
	if reinc_lvl <= 0:
		if animated:
			_tween_bg_stage(0.0)
			if _bg_tween:
				_bg_tween.tween_callback(func() -> void: bg_stage_rect.visible = false)
		else:
			_set_bg_stage(0.0)
			bg_stage_rect.visible = false
	else:
		bg_stage_rect.visible = true
		var target_stage := clampf(float(reinc_lvl), 1.0, 6.0)
		if animated:
			_tween_bg_stage(target_stage)
		else:
			_set_bg_stage(target_stage)


## オーラの種類を切り替える (0=炎 / 1=氷 / 2=雷 / 3=光)
func set_aura_type(type_id: int) -> void:
	if aura_rect:
		var mat := aura_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("aura_type", type_id)


func set_aura_enabled(enabled: bool) -> void:
	_aura_enabled = enabled
	if not aura_rect:
		return
	if is_instance_valid(_aura_tween):
		_aura_tween.kill()
	aura_rect.visible = true
	var target := aura_strength if enabled else 0.0
	_aura_tween = create_tween()
	_aura_tween.tween_method(_set_aura_strength, _aura_shown, target, fade_time)
	if not enabled:
		_aura_tween.tween_callback(func() -> void: aura_rect.visible = false)


func set_background_enabled(enabled: bool) -> void:
	if not bg_stage_rect:
		return
	if enabled:
		bg_stage_rect.visible = true
		var target := clampf(float(GameData.reincarnation_level), 1.0, 6.0)
		_tween_bg_stage(target)
	else:
		_tween_bg_stage(0.0)
		if _bg_tween:
			_bg_tween.tween_callback(func() -> void: bg_stage_rect.visible = false)


func set_background_stage(stage: float) -> void:
	if bg_stage_rect:
		bg_stage_rect.visible = stage > 0.0
		_tween_bg_stage(stage)


func _tween_bg_stage(target: float) -> void:
	if is_instance_valid(_bg_tween):
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_method(_set_bg_stage, _bg_shown_stage, target, fade_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_bg_stage(value: float) -> void:
	_bg_shown_stage = value
	if bg_stage_rect:
		var mat := bg_stage_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("stage", value)


func _set_aura_strength(value: float) -> void:
	_aura_shown = value
	if aura_rect:
		var mat := aura_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("strength", value)
