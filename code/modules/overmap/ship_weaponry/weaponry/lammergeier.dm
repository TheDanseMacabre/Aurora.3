/obj/machinery/ship_weapon/lammergeier
	name = "lammergeier cannon"
	desc = "A Dominian naval cannon."
	icon_state = "weapon_base"
	icon = 'icons/obj/machines/ship_guns/lammergeier.dmi'
	heavy_firing_sound = 'sound/weapons/gunshot/ship_weapons/flak_fire.ogg'
	projectile_type = /obj/item/projectile/ship_ammo/lammergeier
	caliber = SHIP_CALIBER_200MM
	firing_effects = FIRING_EFFECT_FLAG_EXTREMELY_LOUD
	screenshake_type = SHIP_GUN_SCREENSHAKE_ALL_MOBS

/obj/machinery/ammunition_loader/lammergeier
	name = "lammergeier shell loader"

/obj/item/ship_ammunition/lammergeier_shell
	name = "lammergeier HE shell"
	desc = "A lammergeier shell."
	icon = 'icons/obj/guns/ship/ship_ammo_lammergeier.dmi'
	icon_state = "shell_he"
	caliber = SHIP_CALIBER_200MM
	ammunition_behaviour = SHIP_AMMO_BEHAVIOUR_DUMBFIRE
	projectile_type_override = /obj/item/projectile/ship_ammo/lammergeier

/obj/item/ship_ammunition/lammergeier_shell/ap
	name = "lammergeier armor-piercing shell"
	desc = "A lammergeier shell."
	icon_state = "shell_ap"
	impact_type = SHIP_AMMO_IMPACT_AP
	projectile_type_override = /obj/item/projectile/ship_ammo/lammergeier/ap

/obj/item/projectile/ship_ammo/lammergeier
	icon_state = "heavy"
	damage = 500
	armor_penetration = 1000
	var/penetrated = FALSE

/obj/item/projectile/ship_ammo/lammergeier/ap
	icon_state = "heavy"
	damage = 500
	armor_penetration = 1000

/obj/item/projectile/ship_ammo/lammergeier/launch_projectile(atom/target, target_zone, mob/user, params, angle_override, forced_spread)
	if(ammo.impact_type == SHIP_AMMO_IMPACT_AP)
		penetrating = 1
	. = ..()

/obj/item/projectile/ship_ammo/lammergeier/on_hit(atom/target, blocked, def_zone, is_landmark_hit)
	. = ..()
	if(isturf(target) || isobj(target))
		switch(ammo.impact_type)
			if(SHIP_AMMO_IMPACT_AP)
				if(!penetrated)
					target.ex_act(1)
					if(!QDELING(target) && target.density)
						qdel(target)
					penetrated = TRUE
				else
					explosion(target, 0, 2, 4)
					qdel(src)
			if(SHIP_AMMO_IMPACT_HE)
				explosion(target, 0, 4, 6)
		return TRUE