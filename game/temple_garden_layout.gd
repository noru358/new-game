extends RefCounted

# The garden shares the run's simulation, but occupies an isolated field.
const MAIN_BOUNDS := Rect2(0, 0, 5100, 2160)
const FIELD_BOUNDS := Rect2(5600, 80, 3000, 2000)
const ENTRY_TRIGGER := Rect2(3070, 200, 110, 110)
const RETURN_POINT := Vector2(2970, 250)
const FIELD_ENTRY := Vector2(5840, 1770)
const EXIT_TRIGGER := Rect2(5660, 1690, 100, 160)
const ALTAR := Vector2(8300, 480)
const GUARDS := [Vector2(6350, 1510), Vector2(7130, 520), Vector2(8030, 1370)]
const GUARD_AREAS := [Rect2(6130, 1290, 600, 690), Rect2(6720, 250, 920, 470), Rect2(7740, 930, 680, 880)]
const POND := Rect2(6810, 870, 800, 470)
