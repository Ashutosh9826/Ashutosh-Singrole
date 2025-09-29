extends Panel

@onready var final_time_label = $"Score"

func _ready():
	final_time_label.text = "Final Time: " + ("%.2f" % GameState.final_time)
