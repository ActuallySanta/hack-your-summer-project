extends Node

var player : Player
var inDialogue: bool = false
var canMove : bool = true
## Attack and Shoot share the mouse buttons with the pause menu, so the menu takes these alone
## while it is up and leaves the rest of the player's input live.
var canAttack : bool = true
