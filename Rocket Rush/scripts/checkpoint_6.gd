extends Area2D

@export var checkpoint_index: int = 6
@export var last_checkpoint: bool = false

# Signal that the checkpoint has been collected
# It passes the index, whether it's the last checkpoint, and a reference to itself.
signal checkpoint_collected(checkpoint_index, is_last_checkpoint, checkpoint_node)

func _on_body_entered(body):
	# We are only interested in collisions with the player's rocket
	if body is CharacterBody2D:
		# Emit the signal, passing our index, last_checkpoint status, and a reference to this node.
		# The rocket script will handle the rest.
		checkpoint_collected.emit(checkpoint_index, last_checkpoint, self)
