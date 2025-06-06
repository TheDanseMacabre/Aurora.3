/mob/living/simple_animal/spiderbot

	min_oxy = 0
	max_tox = 0
	max_co2 = 0
	minbodytemp = 0
	maxbodytemp = 500
	mob_size = MOB_TINY

	var/radio_type = /obj/item/device/radio/borg
	var/obj/item/device/radio/borg/radio = null
	var/mob/living/silicon/ai/connected_ai = null
	var/obj/item/cell/cell = null
	var/obj/machinery/camera/camera = null
	var/obj/item/device/mmi/mmi = null
	var/obj/item/card/id/internal_id = null
	var/list/req_access = list(ACCESS_ROBOTICS) //Access needed to pop out the brain.
	var/positronic

	name = "spider-bot"
	desc = "A skittering robotic friend!"
	icon = 'icons/mob/robots.dmi'
	icon_state = "spiderbot-chassis"
	icon_living = "spiderbot-chassis"
	icon_dead = "spiderbot-smashed"
	blood_color = COLOR_OIL
	blood_type = COLOR_OIL

	wander = 0
	density = 0
	health = 25
	maxHealth = 25
	hunger_enabled = 0

	attacktext = "shocked"
	melee_damage_lower = 1
	melee_damage_upper = 3

	organ_names = list("head")
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "stomps on"

	var/emagged = 0
	var/obj/item/held_item = null //Storage for single item they can hold.
	speed = -1                    //Spiderbots gotta go fast.
	pass_flags = PASSTABLE | PASSDOORHATCH
	universal_understand = TRUE
	speak_emote = list("beeps","clicks","chirps")
	can_pull_size = 3
	can_pull_mobs = MOB_PULL_SMALLER

	psi_pingable = FALSE

/mob/living/simple_animal/spiderbot/Initialize()
	. = ..()
	add_language(LANGUAGE_TCB)
	default_language = GLOB.all_languages[LANGUAGE_TCB]
	internal_id = new /obj/item/card/id(src)
	add_verb(src, /mob/living/proc/ventcrawl)
	add_verb(src, /mob/living/proc/hide)
	add_verb(src, /mob/living/simple_animal/spiderbot/proc/control_integrated_radio)
	voice_name = name

	radio = new radio_type(src)
	camera = new /obj/machinery/camera(src, 0, TRUE, TRUE)
	camera.c_tag = "spiderbot-[real_name]"
	camera.replace_networks(list("SS13"))

/mob/living/simple_animal/spiderbot/Destroy()
	eject_brain()
	return ..()

/mob/living/simple_animal/spiderbot/can_name(var/mob/living/M)
	return FALSE

/mob/living/simple_animal/spiderbot/isSynthetic()
	return TRUE

/mob/living/simple_animal/spiderbot/attackby(obj/item/attacking_item, mob/user)

	if(istype(attacking_item, /obj/item/device/mmi))
		var/obj/item/device/mmi/B = attacking_item
		if(src.mmi)
			to_chat(user, SPAN_WARNING("There's already a brain in [src]!"))
			return
		if(!B.brainmob)
			to_chat(user, SPAN_WARNING("Sticking an empty MMI into the frame would sort of defeat the purpose."))
			return
		if(!B.brainmob.key)
			var/ghost_can_reenter = 0
			if(B.brainmob.mind)
				for(var/mob/abstract/ghost/observer/G in GLOB.player_list)
					if(G.can_reenter_corpse && G.mind == B.brainmob.mind)
						ghost_can_reenter = 1
						break
			if(!ghost_can_reenter)
				to_chat(user, SPAN_NOTICE("[attacking_item] is completely unresponsive; there's no point."))
				return

		if(B.brainmob.stat == DEAD)
			to_chat(user, SPAN_WARNING("[attacking_item] is dead. Sticking it into the frame would sort of defeat the purpose."))
			return

		if(jobban_isbanned(B.brainmob, "Cyborg"))
			to_chat(user, SPAN_WARNING("\The [attacking_item] does not seem to fit."))
			return

		to_chat(user, SPAN_NOTICE("You install \the [attacking_item] in \the [src]!"))

		if(istype(attacking_item, /obj/item/device/mmi/digital))
			positronic = 1
			add_language("Robot Talk")

		src.mmi = attacking_item
		src.transfer_personality(attacking_item)

		user.drop_from_inventory(attacking_item,src)
		src.update_icon()
		return 1

	if (attacking_item.iswelder())
		var/obj/item/weldingtool/WT = attacking_item
		if (WT.use(0))
			if(health < maxHealth)
				health += pick(1,1,1,2,2,3)
				if(health > maxHealth)
					health = maxHealth
				add_fingerprint(user)
				src.visible_message(SPAN_NOTICE("\The [user] has spot-welded some of the damage to \the [src]!"))
			else
				to_chat(user, SPAN_WARNING("\The [src] is undamaged!"))
		else
			to_chat(user, SPAN_DANGER("You need more welding fuel for this task!"))
			return
	else if(attacking_item.GetID())
		if (!mmi)
			to_chat(user, SPAN_DANGER("There's no reason to swipe your ID - \the [src] has no brain."))
			return 0

		var/obj/item/card/id/id_card = attacking_item.GetID()

		if(!istype(id_card))
			return 0

		var/choice = input(user, "Would you like to eject the brain or sync access?", "Swipe Mode") as null|anything in list("Eject", "Sync")
		if(!choice)
			return

		switch(choice)
			if("Eject")
				if(use_check_and_message(user))
					return 0
				if(ACCESS_ROBOTICS in id_card.access)
					to_chat(user, SPAN_NOTICE("You swipe your access card and pop the brain out of \the [src]."))
					eject_brain()
					if(held_item)
						held_item.forceMove(src.loc)
						held_item = null
					return 1
				else
					to_chat(user, SPAN_DANGER("You swipe your card with no effect."))
					return 0
			if("Sync")
				if(use_check_and_message(user))
					return 0

				internal_id.access.Cut()
				internal_id.access = id_card.access.Copy()
				to_chat(user, SPAN_NOTICE("Access synced with [src]."))
				to_chat(src, SPAN_NOTICE("Access codes updated."))
				return 1
	else
		attacking_item.attack(src, user, user.zone_sel.selecting)

/mob/living/simple_animal/spiderbot/emag_act(var/remaining_charges, var/mob/user)
	if (emagged)
		to_chat(user, SPAN_WARNING("[src] is already overloaded - better run."))
		return 0
	else
		to_chat(user, SPAN_NOTICE("You short out the security protocols and overload [src]'s cell, priming it to explode in a short time."))
		spawn(100)	to_chat(src, SPAN_DANGER("Your cell seems to be outputting a lot of power..."))
		spawn(200)	to_chat(src, SPAN_DANGER("Internal heat sensors are spiking! Something is badly wrong with your cell!"))
		spawn(300)	src.explode()

/mob/living/simple_animal/spiderbot/proc/transfer_personality(var/obj/item/device/mmi/M as obj)
	src.mind = M.brainmob.mind
	src.mind.key = M.brainmob.key
	src.ckey = M.brainmob.ckey
	src.name = "spider-bot ([M.brainmob.name])"
	src.voice_name = src.name

/mob/living/simple_animal/spiderbot/proc/explode() //When emagged.
	src.visible_message(SPAN_DANGER("\The [src] makes an odd warbling noise, fizzles, and explodes!"))
	explosion(get_turf(loc), -1, -1, 3, 5)
	eject_brain()
	death()

/mob/living/simple_animal/spiderbot/update_icon()
	if(mmi)
		if(positronic)
			icon_state = "spiderbot-chassis-posi"
			icon_living = "spiderbot-chassis-posi"
		else
			icon_state = "spiderbot-chassis-mmi"
			icon_living = "spiderbot-chassis-mmi"
	else
		icon_state = "spiderbot-chassis"
		icon_living = "spiderbot-chassis"

/mob/living/simple_animal/spiderbot/proc/eject_brain()
	if(mmi)
		var/turf/T = get_turf(loc)
		if(T)
			mmi.forceMove(T)
		if(mind)	mind.transfer_to(mmi.brainmob)
		mmi = null
		real_name = initial(real_name)
		name = real_name
		voice_name = name
		update_icon()
	remove_language("Robot Talk")
	positronic = null

/mob/living/simple_animal/spiderbot/get_radio()
	return radio

/mob/living/simple_animal/spiderbot/death()

	GLOB.living_mob_list -= src
	GLOB.dead_mob_list += src

	if(camera)
		camera.status = 0

	if (held_item)
		held_item.forceMove(src.loc)
		held_item = null

	eject_brain()
	gibs(loc, viruses, null, /obj/effect/gibspawner/robot) //TODO: use gib() or refactor spiderbots into synthetics.
	qdel(src)
	return

//Cannibalized from the parrot mob. ~Zuhayr
/mob/living/simple_animal/spiderbot/verb/drop_held_item()
	set name = "Drop held item"
	set category = "Spiderbot"
	set desc = "Drop the item you're holding."

	if(stat)
		return

	if(!held_item)
		to_chat(usr, SPAN_WARNING("You have nothing to drop!"))
		return 0

	if(istype(held_item, /obj/item/grenade))
		visible_message(SPAN_DANGER("\The [src] launches \the [held_item]!"), \
			SPAN_DANGER("You launch \the [held_item]!"), \
			"You hear a skittering noise and a thump!")
		var/obj/item/grenade/G = held_item
		G.forceMove(src.loc)
		G.prime()
		held_item = null
		return 1

	visible_message(SPAN_NOTICE("\The [src] drops \the [held_item]."), \
		SPAN_NOTICE("You drop \the [held_item]."), \
		"You hear a skittering noise and a soft thump.")

	held_item.forceMove(src.loc)
	held_item = null
	return 1

/mob/living/simple_animal/spiderbot/verb/get_item()
	set name = "Pick up item"
	set category = "Spiderbot"
	set desc = "Allows you to take a nearby small item."

	if(stat)
		return -1

	if(held_item)
		to_chat(src, SPAN_WARNING("You are already holding \the [held_item]"))
		return 1

	var/list/items = list()
	for(var/obj/item/I in view(1,src))
		if(I.loc != src && I.w_class <= 2 && I.Adjacent(src) )
			items.Add(I)

	var/obj/selection = input("Select an item.", "Pickup") in items

	if(selection)
		for(var/obj/item/I in view(1, src))
			if(selection == I)
				held_item = selection
				selection.forceMove(src)
				visible_message(SPAN_NOTICE("\The [src] scoops up \the [held_item]."), \
					SPAN_NOTICE("You grab \the [held_item]."), \
					"You hear a skittering noise and a clink.")
				return held_item
		to_chat(src, SPAN_WARNING("\The [selection] is too far away."))
		return 0

	to_chat(src, SPAN_WARNING("There is nothing of interest to take."))
	return 0

/mob/living/simple_animal/spiderbot/get_examine_text(mob/user, distance, is_adjacent, infix, suffix)
	. = ..()
	if(src.held_item)
		to_chat(user, "It is carrying [icon2html(src.held_item, user)] \a [src.held_item].")

/mob/living/simple_animal/spiderbot/cannot_use_vents()
	return

/mob/living/simple_animal/spiderbot/binarycheck()
	return positronic

/mob/living/simple_animal/spiderbot/Move(newloc, direct)
	. = ..()

	if (underdoor)
		underdoor = 0
		if ((layer == UNDERDOOR))//if this is false, then we must have used hide, or had our layer changed by something else. We wont do anymore checks for this move proc
			for (var/obj/machinery/door/D in loc)
				if (D.hashatch)
					underdoor = 1
					break

			if (!underdoor)
				spawn(3)//A slight delay to let us finish walking out from under the door
					layer = initial(layer)

/mob/living/simple_animal/spiderbot/zMove(direction)
	if(istype(loc, /mob/living/heavy_vehicle))
		var/mob/living/heavy_vehicle/mech = loc
		mech.zMove(direction)
		return
	..()

/mob/living/simple_animal/spiderbot/get_bullet_impact_effect_type(var/def_zone)
	return BULLET_IMPACT_METAL

/mob/living/simple_animal/spiderbot/handle_message_mode(message_mode, message, verb, speaking, used_radios, alt_name, whisper)
	switch(message_mode)
		if("whisper")
			if(!whisper)
				whisper(message, speaking, say_verb = TRUE)
				return TRUE
		if("headset")
			radio.talk_into(src, message, null, verb, speaking)
			used_radios += radio
		if("intercom")
			var/turf/T = get_turf(src)
			for(var/obj/item/device/radio/intercom/I in view(1, T))
				I.talk_into(src, message, null, verb, speaking)
				used_radios += I
	if(message_mode)
		radio.talk_into(src, message, message_mode, verb, speaking)
		used_radios += radio

/mob/living/simple_animal/spiderbot/proc/control_integrated_radio()
	set name = "Radio Settings"
	set desc = "Allows you to change settings of your radio."
	set category = "Spiderbot"

	to_chat(src, SPAN_NOTICE("Accessing Subspace Transceiver control..."))
	if(radio)
		radio.interact(src)

/mob/living/simple_animal/spiderbot/ai
	radio_type = /obj/item/device/radio/headset/heads/ai_integrated

/mob/living/simple_animal/spiderbot/ai/Initialize()
	. = ..()
	internal_id.access = get_all_station_access()
