extends RefCounted
## Place-aware role mix only. Existing spawn budget, AI, tells and rewards stay authoritative.
## Roles: fragment, charging beast, lamp, ground zone, support.
static func place_weights(point:Vector2)->Array[float]:
	if point.x>3500 and point.y>1450:
		# Broken offering court: choose whether to break through to the rear support.
		return [45.0,15.0,10.0,10.0,20.0]
	if point.x>3400:
		# Inner causeway: read a charge line while using the broader landing to sidestep.
		return [40.0,35.0,15.0,10.0,0.0]
	if point.x>1950 and point.y>1150 and point.y<1900:
		# Open face bank: relocate around visible ground warnings instead of staying planted.
		return [40.0,15.0,10.0,30.0,5.0]
	if point.y<1400:
		# Outer root path: reach the ranged attacker around the water bend.
		return [45.0,20.0,25.0,10.0,0.0]
	return [55.0,25.0,15.0,5.0,0.0]
static func weights(point:Vector2,time:float,phase:Dictionary)->Array[float]:
	var baseline:Array = [70.0,20.0,0.0,10.0,0.0] if time<120.0 else [55.0,20.0,10.0,10.0,5.0] if time<200.0 else [45.0,20.0,15.0,10.0,10.0]
	baseline=phase.get("weights",baseline)
	var local:=place_weights(point)
	# Retain the common pressure/recovery sequence as the majority of the mix.
	for i in 5:local[i]=local[i]*0.40+float(baseline[i])*0.60
	return local
