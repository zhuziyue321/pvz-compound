extends Resource
class_name ResourceTutorialData
## 新手教程数据：一串按顺序执行的教学步骤
##
## 挂在关卡资源 ResourceLevelData.tutorial_data 上；不为空时本关就是教程关
## （原版：冒险模式 1-1 是教程关，首次游玩才播教程）。推进逻辑见 TutorialManager。

## 按顺序执行的教程步骤
@export var steps: Array[ResourceTutorialStep] = []
## 是否只在「首次游玩该关」（该关还没有通关记录）时播放
## 原版教程只在冒险模式第一轮出现，重玩不再提示
@export var only_first_playthrough: bool = true
## 是否为「开场教程」：整段教程在关卡正式开局之前跑完
## （原版 1-5：戴夫开场白说完 → 玩家铲光草坪 → 戴夫介绍保龄球、红线出现 → 才预览僵尸并开局）
## 为 false 时教程在主游戏阶段开始后才跑（原版 1-1 / 1-2）
@export var is_opening_tutorial: bool = false
