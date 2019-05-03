/**
 * csdm_misc.sma
 * Allows for Counter-Strike to be played as DeathMatch.
 *
 * CSDM Miscellanious Settings
 *
 * By Freecode and BAILOPAN
 * (C)2003-2006 David "BAILOPAN" Anderson
 *
 * Give credit where due.
 * Share the source - it sets you free
 * http://www.opensource.org/
 * http://www.gnu.org/
 *
 *
 *
 * Modification from ReCSDM Team (C) 2016
 * http://www.dedicated-server.ru/
 *
 */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <csdm>

#pragma semicolon 1

#define MAPSTRIP_VIP			(1<<0)
#define MAPSTRIP_BUY			(1<<1)
#define MAPSTRIP_HOSTAGE		(1<<2)
#define MAPSTRIP_BOMB			(1<<3)

#define HIDE_HUD_TIMER			(1<<4)
#define HIDE_HUD_MONEY		(1<<5)

new bool:g_bBlockBuy = true;
new bool:g_bAmmoRefill = true;
new bool:g_bRadioMsg = false;
new bool:g_bHideMoney = false;
new bool:g_bHideTimer = false;
new bool:g_bPluginInitiated = false;

#define MAXMENUPOS 34

new const g_sBuyMsg[] = "#Hint_press_buy_"; // full: #Hint_press_buy_to_purchase
new g_msgMoney, g_msgHideWeapon, g_msgRoundTime;

// new g_msgItemPickup, g_msgAmmoPickup

new g_Aliases[MAXMENUPOS][] = {
	"usp","glock","deagle","p228","elites","fn57","m3","xm1014","mp5","tmp","p90","mac10","ump45","ak47","galil","famas","sg552","m4a1",
	"aug","scout","awp","g3sg1","sg550","m249","vest","vesthelm","flash","hegren","sgren","defuser","nvgs","shield","primammo","secammo"
};

new g_Aliases2[MAXMENUPOS][] = {
	"km45","9x19mm","nighthawk","228compact","elites","fiveseven","12gauge","autoshotgun","smg","mp","c90","mac10","ump45","cv47","defender",
	"clarion","krieg552","m4a1","bullpup","scout","magnum","d3au1","krieg550","m249","vest","vesthelm","flash","hegren","sgren","defuser",
	"nvgs","shield","primammo","secammo"
};

//Tampering with the author and name lines can violate the copyright
new PLUGINNAME[] = "ReCSDM Misc";
new VERSION[] = CSDM_VERSION;
new AUTHORS[] = "ReCSDM Team";

new g_MapStripFlags;

// page info for settings in CSDM Setting Menu
new g_SettingsMenu;
new g_MiscSettMenu;
new g_ItemsInMenuNr;
new g_PageSettMenu;
new g_MsgStatusIcon;

public plugin_precache()
{
	precache_sound("radio/locknload.wav");
	precache_sound("radio/letsgo.wav");

	register_forward(FM_Spawn, "OnEntSpawn");
}

public csdm_Init(const version[])
{
	if (version[0] == 0) {
		set_fail_state("ReCSDM failed to load.");
		return;
	}
}

public csdm_CfgInit()
{
	csdm_reg_cfg("misc", "read_cfg");
}

public plugin_init()
{
	register_plugin(PLUGINNAME, VERSION, AUTHORS);

	g_msgMoney = get_user_msgid("Money");
	g_msgRoundTime = get_user_msgid("RoundTime");

	// g_msgItemPickup = get_user_msgid("ItemPickup");
	// g_msgAmmoPickup = get_user_msgid("AmmoPickup");

	g_msgHideWeapon = get_user_msgid("HideWeapon");

	register_message(get_user_msgid("HudTextArgs"), "msgHudTextArgs");
	register_message(g_msgHideWeapon, "msgHideWeapon");

	register_event("StatusIcon", "hook_buyzone", "be", "1=1", "1=2", "2=buyzone");
	register_event("ResetHUD", "onResetHUD", "b");

	register_clcmd("buy", "generic_block");
	register_clcmd("buyammo1", "generic_block");
	register_clcmd("buyammo2", "generic_block");
	register_clcmd("buyequip", "generic_block");
	register_clcmd("cl_autobuy", "generic_block");
	register_clcmd("cl_rebuy", "generic_block");
	register_clcmd("cl_setautobuy", "generic_block");
	register_clcmd("cl_setrebuy", "generic_block");
	register_clcmd("csdm_misc_sett_menu", "csdm_misc_sett_menu", ADMIN_MAP, "Меню настроек CSDM Разное");

	register_concmd("csdm_pvlist", "pvlist");

	register_forward(FM_ServerDeactivate, "forward_server_deactivate");

	new main_plugin = module_exists("csdm_main") ? true : false;

	if (main_plugin)
	{
		g_SettingsMenu = csdm_settings_menu();
		g_ItemsInMenuNr = menu_items(g_SettingsMenu);
		g_PageSettMenu = g_ItemsInMenuNr / 7;

		g_MiscSettMenu = menu_create("Меню настроек CSDM Разное", "use_csdm_misc_menu");

		menu_additem(g_SettingsMenu, "Настройки CSDM Разное", "csdm_misc_sett_menu", ADMIN_MAP);

		if (g_MiscSettMenu)
		{
			new callback = menu_makecallback("hook_misc_sett_display");

			menu_additem(g_MiscSettMenu, "Скрыть задания на as_ картах [вкл/выкл]", "1", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Скрыть закупочные зоны [вкл/выкл]", "2", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Скрыть заданияна cs_ картах [вкл/выкл]", "3", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Скрыть задания на de_ картах [вкл/выкл]", "4", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Блокировать закупку [вкл/выкл]", "5", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Показывать запас боеприпасов [вкл/выкл]", "6", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Сообщать по радио о возрождении игрока [вкл/выкл]", "7", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Скрыть деньги [вкл/выкл]", "8", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Скрыть тайиер [вкл/выкл]", "9", ADMIN_MAP, callback);
			menu_additem(g_MiscSettMenu, "Назад", "10", 0, -1);
		}
	}

	set_task(2.0, "DoMapStrips");

	g_bPluginInitiated = true;

	g_MsgStatusIcon = get_user_msgid("StatusIcon");
}

public plugin_cfg()
{
	if (csdm_active() && g_bHideMoney && g_bBlockBuy && get_msg_block(g_msgMoney) != BLOCK_SET) {
		set_msg_block(g_msgMoney, BLOCK_SET);
	}

	new bool:bRemoveAllObjectives = (g_MapStripFlags & MAPSTRIP_VIP) 
		&& (g_MapStripFlags & MAPSTRIP_HOSTAGE)
		&& (g_MapStripFlags & MAPSTRIP_BOMB);

	if(csdm_active() && bRemoveAllObjectives && g_bHideTimer && get_msg_block(g_msgRoundTime) != BLOCK_SET) {
		set_msg_block(g_msgRoundTime, BLOCK_SET);
	}

	if(get_cvar_num("mp_refill_bpammo_weapons") != 2) {
		register_event("CurWeapon", "hook_CurWeapon", "be", "1=1");
	}
}

public csdm_StateChange(csdm_state)
{
	if (csdm_state == CSDM_ENABLE && g_bPluginInitiated) {
	   set_task(2.0, "DoMapStrips");
	}
	else if (csdm_state == CSDM_DISABLE)
	{
		if (!g_msgMoney)
			g_msgMoney = get_user_msgid("Money");

		if (g_msgMoney)
		{
			if(get_msg_block(g_msgMoney) == BLOCK_SET) {
				set_msg_block(g_msgMoney, BLOCK_NOT);
			}
		}

		if (!g_msgRoundTime)
			g_msgRoundTime = get_user_msgid("RoundTime");

		if (g_msgRoundTime)
		{
			if(get_msg_block(g_msgRoundTime) == BLOCK_SET) {
				set_msg_block(g_msgRoundTime, BLOCK_NOT);
			}
		}
	}
}

public forward_server_deactivate()
{
	g_bPluginInitiated = false;

	return FMRES_IGNORED;
}

public hook_buyzone(id)
{
	if (!csdm_active())
		return PLUGIN_CONTINUE;

	if (g_MapStripFlags & MAPSTRIP_BUY) {	
		message_begin(MSG_ONE, g_MsgStatusIcon, {0,0,0}, id);
		write_byte(0); 				// status (0=hide, 1=show, 2=flash)
		write_string("buyzone"); 		// sprite name
		write_byte(0); 				// red
		write_byte(0); 				// green
		write_byte(0); 				// blue
		message_end();		
	}

	return PLUGIN_CONTINUE;
}

public msgHudTextArgs(msg_id, msg_dest, msg_entity)
{
	if (!csdm_active())
		return PLUGIN_CONTINUE;

	if ((g_MapStripFlags & MAPSTRIP_BUY) || g_bBlockBuy)
	{
		static sTemp[sizeof(g_sBuyMsg)];

		get_msg_arg_string(1, sTemp, sizeof(sTemp) - 1);

		if(equal(sTemp, g_sBuyMsg))
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public onResetHUD(id)
{
	if(!csdm_active() || !id || is_user_bot(id)) return;

	new iHideFlags = GetHudHideFlags();

	if(iHideFlags) {
		message_begin(MSG_ONE, g_msgHideWeapon, _, id);
		write_byte(iHideFlags);
		message_end();
	}
}

public msgHideWeapon()
{
	if(!csdm_active()) return;

	new iHideFlags = GetHudHideFlags();

	if(iHideFlags)
		set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | iHideFlags);
}

stock GetHudHideFlags()
{
	new iFlags;

	if(g_bBlockBuy && g_bHideMoney)
		iFlags |= HIDE_HUD_MONEY;

	new bool:bRemoveAllObjectives = (g_MapStripFlags & MAPSTRIP_VIP) 
		&& (g_MapStripFlags & MAPSTRIP_HOSTAGE)
		&& (g_MapStripFlags & MAPSTRIP_BOMB);

	if (bRemoveAllObjectives && g_bHideTimer)
		iFlags |= HIDE_HUD_TIMER;

	return iFlags;
}

public OnEntSpawn(ent)
{
	if ((g_MapStripFlags & MAPSTRIP_HOSTAGE) && csdm_active())
	{
		new szClassName[32];

		if (pev_valid(ent))
		{
			pev(ent, pev_classname, szClassName, charsmax(szClassName));

			if (equal(szClassName, "hostage_entity")) {
				engfunc(EngFunc_RemoveEntity, ent);
				return FMRES_SUPERCEDE;
			}
		}
	}

	return FMRES_IGNORED;
}

public pvlist(id, level, cid)
{
	new players[32], num, pv, name[32];

	get_players(players, num);

	for (new i = 0; i < num; i++) {
		pv = players[i];
		get_user_name(pv, name, charsmax(name));
		console_print(id, "[CSDM] Player %s flags: %d deadflags: %d", name, pev(pv, pev_flags), pev(pv, pev_deadflag));
	}

	return PLUGIN_HANDLED;
}

public generic_block(id, level, cid)
{
	if (g_bBlockBuy && csdm_active()) {
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public csdm_PostSpawn(player, bool:fake)
{
	if (g_bRadioMsg && !is_user_bot(player) && csdm_active())
	{
		if(_:cs_get_user_team(player) == _TEAM_T) {
			client_cmd(player, "spk radio/letsgo");
		} else {
			client_cmd(player, "spk radio/locknload");
		}
	}
}

public client_command(id)
{
	if (g_bBlockBuy && csdm_active())
	{
		static arg[13], a;

		if (read_argv(0, arg, charsmax(arg)) > 11)
			return PLUGIN_CONTINUE;

		a = 0;
		do {
			if (equali(g_Aliases[a], arg) || equali(g_Aliases2[a], arg)) {
				return PLUGIN_HANDLED;
			}
		} while(++a < MAXMENUPOS);
	}

	return PLUGIN_CONTINUE; 
} 

public hook_CurWeapon(id)
{
	if (!g_bAmmoRefill || !csdm_active()) return;

	new wp = read_data(2);

	if (g_WeaponSlots[wp] == SLOT_PRIMARY || g_WeaponSlots[wp] == SLOT_SECONDARY)
	{
		new ammo = cs_get_user_bpammo(id, wp);

		if (ammo < g_MaxBPAmmo[wp])
			cs_set_user_bpammo(id, wp, g_MaxBPAmmo[wp]);
	}
}

public DoMapStrips()
{
	if(!csdm_active()) return;

	new mapname[24];

	get_mapname(mapname, charsmax(mapname));

	if ((g_MapStripFlags & MAPSTRIP_BOMB)) {
		csdm_remove_entity_all("func_bomb_target");
		csdm_remove_entity_all("info_bomb_target");
	}

	if ((g_MapStripFlags & MAPSTRIP_VIP)) {
		csdm_remove_entity_all("func_vip_safetyzone");
		csdm_remove_entity_all("info_vip_start");
	}

	if ((g_MapStripFlags & MAPSTRIP_HOSTAGE)) {
		csdm_remove_entity_all("func_hostage_rescue");
		csdm_remove_entity_all("info_hostage_rescue");
	}

	if (g_MapStripFlags & MAPSTRIP_BUY) {
		csdm_remove_entity_all("func_buyzone");
	}
}

public read_cfg(readAction, line[], section[])
{		
	if (readAction == CFG_READ)
	{
		new setting[24], sign[3], value[32];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		if (equali(setting, "remove_objectives"))
		{
			new mapname[24];

			get_mapname(mapname, charsmax(mapname));

			if (containi(value, "d") != -1)
				g_MapStripFlags |= MAPSTRIP_BOMB;

			if (containi(value, "a") != -1)
				g_MapStripFlags |= MAPSTRIP_VIP;

			if (containi(value, "c") != -1)
				g_MapStripFlags |= MAPSTRIP_HOSTAGE;

			if (containi(value, "b") != -1)
				g_MapStripFlags |= MAPSTRIP_BUY;

		} else if (equali(setting, "block_buy")) {
			g_bBlockBuy = str_to_num(value) ? true : false;

		} else if (equali(setting, "ammo_refill")) {
			g_bAmmoRefill = str_to_num(value) ? true : false;

		} else if (equali(setting, "spawn_radio_msg")) {
			g_bRadioMsg = str_to_num(value) ? true : false;

		} else if (equali(setting, "hide_money")) {
			g_bHideMoney = str_to_num(value) ? true : false;

		} else if (equali(setting, "hide_timer")) {
			g_bHideTimer = str_to_num(value) ? true : false;
		}

	} else if (readAction == CFG_RELOAD) {
		g_MapStripFlags = 0;
		g_bBlockBuy = true;
		g_bAmmoRefill = true;
		g_bRadioMsg = false;
	}
}

public csdm_misc_sett_menu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1)) {
		return PLUGIN_HANDLED;
	}

	menu_display(id, g_MiscSettMenu, 0);

	return PLUGIN_HANDLED;
}

public use_csdm_misc_menu(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	new command[6], paccess, call;

	if (!menu_item_getinfo(g_MiscSettMenu, item, paccess, command, charsmax(command), _, 0, call)) {
		log_amx("Error: csdm_menu_item() failed (menu %d) (page %d) (item %d)", g_MiscSettMenu, 0, item);
		return PLUGIN_HANDLED;
	}

	if (paccess && !(get_user_flags(id) & paccess))	{
		client_print(id, print_chat, "У вас нет прав доступа к этой опции.");
		return PLUGIN_HANDLED;
	}

	new iChoice = str_to_num(command);

	switch(iChoice)
	{
		case 1:
		{
			new strip_as = g_MapStripFlags & MAPSTRIP_VIP;

			if (strip_as) {
				g_MapStripFlags &= ~MAPSTRIP_VIP;
			} else {
				g_MapStripFlags |= MAPSTRIP_VIP;
			}

			client_print(id, print_chat, "Скрытие заданий на as_ картах %s.", (g_MapStripFlags & MAPSTRIP_VIP) ? "Включено" : "Выключено");
			log_amx("CSDM removig objectives for as_ maps %s.", (g_MapStripFlags & MAPSTRIP_VIP) ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);

			new flags[5] = "";
			get_flags(g_MapStripFlags, flags, charsmax(flags));

			csdm_write_cfg(id, "misc", "remove_objectives", flags);
			client_print(id,print_chat,"Данные настройки вступят в силу после смены карты.");

			return PLUGIN_HANDLED;
		}
		case 2:
		{
			new strip_buy = g_MapStripFlags & MAPSTRIP_BUY;

			if (strip_buy) {
				g_MapStripFlags &= ~MAPSTRIP_BUY;
			} else {
				g_MapStripFlags |= MAPSTRIP_BUY;
			}

			client_print(id, print_chat, "Скрытие закупочной зоны %s.", (g_MapStripFlags & MAPSTRIP_BUY) ? "Включено" : "Выключено");
			log_amx("CSDM removig buyzones for maps %s.", (g_MapStripFlags & MAPSTRIP_BUY) ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);

			new flags[5] = "";
			get_flags(g_MapStripFlags, flags, charsmax(flags));

			csdm_write_cfg(id, "misc", "remove_objectives", flags);
			client_print(id,print_chat,"Данные настройки вступят в силу после смены карты.");

			return PLUGIN_HANDLED;
		}
		case 3:
		{
			new strip_cs = g_MapStripFlags & MAPSTRIP_HOSTAGE;

			if (strip_cs) {
				g_MapStripFlags &= ~MAPSTRIP_HOSTAGE;
			} else {
				g_MapStripFlags |= MAPSTRIP_HOSTAGE;
			}

			client_print(id, print_chat, "Скрытие заданий на cs_ картах %s.", (g_MapStripFlags & MAPSTRIP_HOSTAGE) ? "Включено" : "Выключено");
			log_amx("CSDM removig objectives for cs_ maps %s.", (g_MapStripFlags & MAPSTRIP_HOSTAGE) ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);

			new flags[5] = "";
			get_flags(g_MapStripFlags, flags, charsmax(flags));

			csdm_write_cfg(id, "misc", "remove_objectives", flags);
			client_print(id,print_chat,"Данные настройки вступят в силу после смены карты.");

			return PLUGIN_HANDLED;
		}
		case 4:
		{
			new strip_de = g_MapStripFlags & MAPSTRIP_BOMB;

			if (strip_de) {
				g_MapStripFlags &= ~MAPSTRIP_BOMB;
			} else {
				g_MapStripFlags |= MAPSTRIP_BOMB;
			}

			client_print(id, print_chat, "Скрытие заданий на de_ картах %s.", (g_MapStripFlags & MAPSTRIP_BOMB) ? "Включено" : "Выключено");
			log_amx("CSDM removig objectives for de_ maps %s.", (g_MapStripFlags & MAPSTRIP_BOMB) ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);

			new flags[5] = "";
			get_flags(g_MapStripFlags, flags, 4);

			csdm_write_cfg(id, "misc", "remove_objectives", flags);
			client_print(id,print_chat,"Данные настройки вступят в силу после смены карты.");

			return PLUGIN_HANDLED;
		}
		case 5:
		{
			g_bBlockBuy = g_bBlockBuy ? false : true;

			client_print(id, print_chat, "Скрытие закупочной зоны %s.", g_bBlockBuy ? "Включено" : "Выключено");
			log_amx("CSDM block buy %s.", g_bBlockBuy ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);
			csdm_write_cfg(id, "misc", "block_buy", g_bBlockBuy ? "1" : "0");

			if (g_bHideMoney && g_bBlockBuy && (get_msg_block(g_msgMoney) != BLOCK_SET) && csdm_active()) {
				set_msg_block(g_msgMoney, BLOCK_SET);
			} else if(get_msg_block(g_msgMoney) == BLOCK_SET) {	
				set_msg_block(g_msgMoney, BLOCK_NOT);
			}

			return PLUGIN_HANDLED;
		}
		case 6:
		{
			g_bAmmoRefill = g_bAmmoRefill? false : true;

			client_print(id, print_chat, "Скрытие запаса боеприпасов %s.", g_bAmmoRefill ? "Включено" : "Выключено");
			log_amx("CSDM ammo refill %s.", g_bAmmoRefill ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);
			csdm_write_cfg(id, "misc", "ammo_refill", g_bAmmoRefill ? "1" : "0");

			return PLUGIN_HANDLED;
		}
		case 7:
		{
			g_bRadioMsg = g_bRadioMsg? false : true;

			client_print(id, print_chat, "Скрытие радио сообщений %s.", g_bRadioMsg ? "Включено" : "Выключено");
			log_amx("CSDM radio message %s.", g_bRadioMsg ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 0);
			csdm_write_cfg(id, "misc", "spawn_radio_msg", g_bRadioMsg ? "1" : "0");

			return PLUGIN_HANDLED;
		}
		case 8:
		{
			g_bHideMoney = g_bHideMoney? false : true;

			client_print(id, print_chat, "Скрытие денег %s.", g_bHideMoney ? "Включено" : "Выключено");
			log_amx("CSDM hide money %s.", g_bHideMoney ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 1);
			csdm_write_cfg(id, "misc", "hide_money", g_bHideMoney ? "1" : "0");

			if (g_bHideMoney && g_bBlockBuy && (get_msg_block(g_msgMoney) != BLOCK_SET) && csdm_active()) {
				set_msg_block(g_msgMoney, BLOCK_SET);
			} else if(get_msg_block(g_msgMoney) == BLOCK_SET) {
				set_msg_block(g_msgMoney, BLOCK_NOT);
			}

			return PLUGIN_HANDLED;
		}
		case 9:
		{
			g_bHideTimer = g_bHideTimer? false : true;

			client_print(id, print_chat, "Скрытие таймера %s.", g_bHideTimer ? "Включено" : "Выключено");
			log_amx("CSDM hide timer %s.", g_bHideTimer ? "enabled" : "disabled");

			menu_display(id, g_MiscSettMenu, 1);
			csdm_write_cfg(id, "misc", "hide_timer", g_bHideTimer ? "1" : "0");

			new bool:bRemoveAllObjectives = (g_MapStripFlags & MAPSTRIP_VIP) 
				&& (g_MapStripFlags & MAPSTRIP_HOSTAGE)
				&& (g_MapStripFlags & MAPSTRIP_BOMB);

			if(bRemoveAllObjectives && g_bHideTimer && (get_msg_block(g_msgRoundTime) != BLOCK_SET) && csdm_active()) {
				set_msg_block(g_msgRoundTime, BLOCK_SET);
			} else if(get_msg_block(g_msgRoundTime) == BLOCK_SET) {
				set_msg_block(g_msgRoundTime, BLOCK_NOT);
			}

			return PLUGIN_HANDLED;
		}
		case 10:
		{
			menu_display(id, g_SettingsMenu, g_PageSettMenu);
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_HANDLED;
}

public hook_misc_sett_display(player, menu, item)
{
	new paccess, command[6], call;

	menu_item_getinfo(menu, item, paccess, command, charsmax(command), _, 0, call);

	if (equali(command, "1"))
	{
		if (g_MapStripFlags & MAPSTRIP_VIP) {
			menu_item_setname(menu, item, "Скрытие заданий на as_ картах включено");
		} else {
			menu_item_setname(menu, item, "Скрытие заданий на as_ картах выключено");
		}

	} else if (equali(command, "2")) {

		if (g_MapStripFlags & MAPSTRIP_BUY) {
			menu_item_setname(menu, item, "Скрытие закупочной заоны включено");
		} else {
			menu_item_setname(menu, item, "Скрытие закупочной заоны выключено");
		}

	} else if (equali(command, "3")) {

		if (g_MapStripFlags & MAPSTRIP_HOSTAGE) {
			menu_item_setname(menu, item, "Скрытие заданий на cs_ картах включено");
		} else {
			menu_item_setname(menu, item, "Скрытие заданий на cs_ картах выключено");
		}

	} else if (equali(command, "4")) {

		if (g_MapStripFlags & MAPSTRIP_BOMB) {
			menu_item_setname(menu, item, "Скрытие заданий на de_ картах включено");
		} else {
			menu_item_setname(menu, item, "Скрытие заданий на de_ картах выключено");
		}

	} else if (equali(command, "5")) {

		if (g_bBlockBuy) {
			menu_item_setname(menu, item, "Блокировка закупки включена");
		} else {
			menu_item_setname(menu, item, "Блокировка закупки выключена");
		}

	} else if (equali(command, "6")) {

		if (g_bAmmoRefill) {
			menu_item_setname(menu, item, "Запас боеприпасов включен");
		} else {
			menu_item_setname(menu, item, "Запас боеприпасов выключен");
		}

	} else if (equali(command, "7")) {

		if (g_bRadioMsg) {
			menu_item_setname(menu, item, "Сообщения по радио о возрождении игрока включено");
		} else {
			menu_item_setname(menu, item, "Сообщения по радио о возрождении игрока выключено");
		}

	} else if (equali(command, "8")) {

		if (g_bHideMoney) {
			menu_item_setname(menu, item, "Скрытие денег включено");
		} else {
			menu_item_setname(menu, item, "Скрытие денег выключено");
		}

	} else if (equali(command, "9")) {

		if (g_bHideTimer) {
			menu_item_setname(menu, item, "Скрытие таймера включено");
		} else {
			menu_item_setname(menu, item, "Скрытие таймера выключено");
		}
	}
}