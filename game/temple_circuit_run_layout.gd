extends RefCounted
const Existing = preload("res://game/temple_garden_layout.gd")
const MAIN_BOUNDS := Rect2(0, 0, 4600, 3500)
const FIELD_BOUNDS := Existing.FIELD_BOUNDS
const ENTRY_TRIGGER := Rect2(1160, 730, 110, 110)
const RETURN_POINT := Vector2(1310, 920)
const FIELD_ENTRY := Existing.FIELD_ENTRY
const EXIT_TRIGGER := Existing.EXIT_TRIGGER
const ALTAR := Existing.ALTAR
const GUARDS := Existing.GUARDS
const GUARD_AREAS := Existing.GUARD_AREAS
const POND := Existing.POND
