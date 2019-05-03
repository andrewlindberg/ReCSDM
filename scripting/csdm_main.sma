/**
 * csdm_main.sma
 * Allows for Counter-Strike to be played as DeathMatch.
 *
 * CSDM Main - Main plugin to communicate with module
 *
 * (C)2003-2013 David "BAILOPAN" Anderson
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

#if AMXX_VERSION_NUM < 183
	#define send_client_cmd client_cmd
#else
	#define send_client_cmd amxclient_cmd
#endif

#define CSDM_OPTIONS_TOTAL 2

new D_PLUGIN[] = "ReCSDM Main";
new D_ACCESS = ADMIN_MAP;
new const g_wbox_model[] = "models/w_weaponbox.mdl";
new const g_shield_model[] = "models/w_shield.mdl";
new bool:g_StripWeapons = true;
new bool:g_RemoveBomb = true;
new g_StayTime;
new g_drop_fwd;
new g_options[CSDM_OPTIONS_TOTAL];
new g_MainMenu = -1;
new g_SettingsMenu = -1;
new g_MainSettMenu = -1;
new g_max_clients;
new g_filename[128];

public plugin_natives()
{
	register_native("csdm_main_menu", "native_main_menu");
	register_native("csdm_settings_menu", "native_settings_menu");
	register_native("csdm_set_mainoption", "__csdm_allow_option");
	register_native("csdm_fwd_drop", "__csdm_fwd_drop");
	register_native("csdm_write_cfg", "native_write_cfg");
	register_library("csdm_main");
}

public native_main_menu(id, num)
{
	return g_MainMenu;
}

public native_settings_menu(id, num)
{
	return g_SettingsMenu;
}

public __csdm_allow_option(id, num)
{
	new option = get_param(1);

	if (option <= 0 || option >= CSDM_OPTIONS_TOTAL) {
		log_error(AMX_ERR_NATIVE, "Invalid option number: %d", option);
		return 0;
	}

	g_options[option] = get_param(2);

	return 1;
}

public __csdm_fwd_drop(id, num) { }

public native_write_cfg(id,num)
{
	new cfgdir[128], section[32], parameter[32], value[16], sect[32];
	new id, sect_length, param_length;

	get_configsdir(cfgdir, charsmax(cfgdir));
	formatex(g_filename, charsmax(g_filename), "%s/csdm.cfg", cfgdir);

	id = get_param(1);
	get_string(2, section, charsmax(section));
	get_string(3, parameter, charsmax(parameter));
	get_string(4, value, charsmax(value));
	sect_length = strlen(section) + 1;
	param_length = strlen(parameter) - 1;
	formatex(sect, charsmax(sect), "[%s]", section);

	if (file_exists(g_filename))
	{
		new Data[124], len, line;
		new bool:bFoundSec = false;
		new bool:bFoundPar = false;
		new bool:bErrorFindSect = true;
		new bool:bErrorFindParam = false;

		while((line = read_file(g_filename, line, Data, charsmax(Data), len)) != 0)
		{
			if (Data[0] == ';' || strlen(Data) < 2) {
				continue;
			}

			if (Data[0] == '[')
			{
				if (bFoundSec) {
					bErrorFindParam = true;
					break;

				} else if (equali(Data, sect, sect_length)) {
					bFoundSec = true;
					bErrorFindSect = false;
				}

			}
			else if (bFoundSec && equali(Data, parameter, param_length)) {
					bFoundPar = true;
					break;
			}
		}

		if (bFoundPar && line > 0)
		{
			new text[32];
			formatex(text, charsmax(text), "%s = %s", parameter, value);

			if (write_file(g_filename, text, line - 1)) {
				client_print(id, print_chat, "Конфигурация успешно сохранена");
			}
	
		} else if (!bFoundSec || bErrorFindSect)  {
			client_print(id, print_chat, "Конфигурация не сохранена. Не верно выбрано имя.");
	
		} else if (!bFoundPar || bErrorFindParam) {
			client_print(id, print_chat, "Конфигурация не сохранена. Не верно указан параметр.");
		}
	}
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
	csdm_reg_cfg("settings", "read_cfg");
}

public plugin_init()
{
	register_plugin(D_PLUGIN, CSDM_VERSION, "ReCSDM Team");

	register_clcmd("say respawn", "say_respawn");
	register_clcmd("say /respawn", "say_respawn");

	register_clcmd("csdm_menu", "csdm_menu", ADMIN_MENU, "CSDM Меню");
	register_clcmd("csdm_sett_menu", "csdm_sett_menu", ADMIN_MENU, "Меню настроек CSDM");
	register_clcmd("csdm_main_sett_menu", "csdm_main_sett_menu", ADMIN_MENU, "Меню основных настроек CSDM");

	register_concmd("csdm_enable", "csdm_enable", D_ACCESS, "Включить CSDM");
	register_concmd("csdm_disable", "csdm_disable", D_ACCESS, "Выключить CSDM");
	register_concmd("csdm_ctrl", "csdm_ctrl", D_ACCESS, "");
	register_concmd("csdm_reload", "csdm_reload", D_ACCESS, "Перезагрузить конфигурацию CSDM");
	register_concmd("csdm_cache", "cacheInfo", ADMIN_MAP, "Показать кешированную информацию");

	AddMenuItem("CSDM Menu", "csdm_menu", D_ACCESS, D_PLUGIN);
	g_MainMenu = menu_create("CSDM Menu", "use_csdm_menu");

	new callback = menu_makecallback("hook_item_display");

	g_SettingsMenu = menu_create("CSDM Settings Menu", "use_csdm_sett_menu");
	menu_additem(g_MainMenu, "CSDM [вкл/выкл]", "csdm_ctrl", D_ACCESS, callback);
	menu_additem(g_MainMenu, "Настройки CSDM", "csdm_sett_menu", D_ACCESS);
	menu_additem(g_MainMenu, "Перезагрузить конфигурацию", "csdm_reload", D_ACCESS);

	g_MainSettMenu = menu_create("Меню основных настроек CSDM", "use_csdm_mainsett_menu");
	menu_additem(g_SettingsMenu, "Основные настройки CSDM", "csdm_main_sett_menu", D_ACCESS);

	if (g_MainSettMenu)
	{
		new str_callback = menu_makecallback("hook_settings_display");

		menu_additem(g_MainSettMenu, "Скрывать оружие [вкл/выкл]", "strip_weap_ctrl", D_ACCESS, str_callback);
		menu_additem(g_MainSettMenu, "Удалять бомбу [вкл/выкл]", "bomb_rem_ctrl", D_ACCESS, str_callback);
		menu_additem(g_MainSettMenu, "Пердустановленные места возрождения [вкл/выкл]", "spawn_mode_ctrl", D_ACCESS, str_callback);
		menu_additem(g_MainSettMenu, "Назад", "csdm_sett_back", D_ACCESS);
	}

	g_drop_fwd = CreateMultiForward("csdm_HandleDrop", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_options[CSDM_OPTION_SAYRESPAWN] = CSDM_SET_ENABLED;

	g_max_clients = get_maxplayers();

	if(get_cvar_num("csdm_block_drop_weapon") != 1) {
		register_forward(FM_SetModel, "forward_set_model");
	}
}

public cacheInfo(id)
{
	if(!(get_user_flags(id) & ADMIN_MAP)) {
		return PLUGIN_HANDLED;
	}

	new ar[6];
	csdm_cache(ar);

	console_print(id, "[ReCSDM] Free tasks: respawn=%d, findweapon=%d", ar[0], ar[5]);
	console_print(id, "[ReCSDM] Weapon removal cache: %d total, %d live", ar[4], ar[3]);
	console_print(id, "[ReCSDM] Live tasks: %d (%d free)", ar[2], ar[1]);

	return PLUGIN_HANDLED;
}

public csdm_PreSpawn(id, bool:fake)
{
	if (!csdm_active()) {
		return;
	}

	new useShield = cs_get_user_shield(id);

	if (useShield) {
		return;
	}

	new team = _:cs_get_user_team(id);

	if (g_StripWeapons)
	{
		if (team == _TEAM_T)
		{
			if (useShield) {
				drop_with_shield(id, CSW_GLOCK18);
			} else {
				csdm_force_drop(id, "weapon_glock18");
			}

		} else if (team == _TEAM_CT) {

			if (useShield) {
				drop_with_shield(id, CSW_USP);
			} else {
				csdm_force_drop(id, "weapon_usp");
			}
		}
	}

	if (g_RemoveBomb && team == _TEAM_T)
	{
		new weapons[MAX_WEAPONS], num, i;
		get_user_weapons(id, weapons, num);

		for (i = 0; i < num; i++)
		{
			if (weapons[i] == CSW_C4)
			{
				if (useShield) {
					drop_with_shield(id, CSW_C4);
				} else {
					csdm_force_drop(id, "weapon_c4");
				}

				break;
			}
		}
	}
}

public csdm_main_sett_menu(id)
{
	if( !(get_user_flags(id) & ADMIN_MENU) ) {
		return PLUGIN_HANDLED;
	}

	menu_display(id, g_MainSettMenu, 0);

	return PLUGIN_HANDLED;
}

public hook_item_display(player, menu, item)
{
	new paccess, command[24], call;

	menu_item_getinfo(menu, item, paccess, command, charsmax(command), _, 0, call);

	if (equali(command, "csdm_ctrl"))
	{
		if (!csdm_active()) {
			menu_item_setname(menu, item, "CSDM Выключен");
		} else {
			menu_item_setname(menu, item, "CSDM Включен");
		}
	}
}

public read_cfg(readAction, line[], section[])
{
	if (readAction == CFG_READ)
	{
		new setting[24], sign[3], value[32];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		if (equali(setting, "strip_weapons")) {
			g_StripWeapons = str_to_num(value) ? true : false;

		} else if (equali(setting, "weapons_stay")) {
			g_StayTime = str_to_num(value);

		}
		else if (equali(setting, "spawnmode"))
		{
			new var = csdm_setstyle(value);

			if (var) {
				log_amx("CSDM spawn mode set to %s", value);
			} else {
				log_amx("CSDM spawn mode %s not found", value);
			}

		} else if (equali(setting, "remove_bomb")) {
			g_RemoveBomb = str_to_num(value) ? true : false;

		} else if (equali(setting, "enabled")) {
			csdm_set_active(str_to_num(value));

		} else if (equali(setting, "spawn_wait_time")) {
			csdm_set_spawnwait(str_to_float(value));
		}
	}
}

public csdm_reload(id)
{
	if( !(get_user_flags(id) & D_ACCESS) ) {
		return PLUGIN_HANDLED;
	}

	if (csdm_reload_cfg(g_filename)) {
		client_print(id, print_chat, "Конфигурация перезагруженна из файла.");
	} else {
		client_print(id, print_chat, "Не найден файл конфигурации.");
	}

	return PLUGIN_HANDLED;
}

public csdm_menu(id)
{
	if( !(get_user_flags(id) & ADMIN_MENU) ) {
		return PLUGIN_HANDLED;
	}

	menu_display(id, g_MainMenu, 0);

	return PLUGIN_HANDLED;
}

public csdm_sett_menu(id)
{
	if( !(get_user_flags(id) & ADMIN_MENU) ) {
		return PLUGIN_HANDLED;
	}

	menu_display(id, g_SettingsMenu, 0);

	return PLUGIN_HANDLED;
}

public csdm_ctrl(id)
{
	if( !(get_user_flags(id) & D_ACCESS) ) {
		return PLUGIN_HANDLED;
	}

	csdm_set_active( csdm_active() ? 0 : 1);
	client_print(id, print_chat, "CSDM %s.", csdm_active()? "Включен" : "Выключен");
	csdm_write_cfg(id, "settings", "enabled", csdm_active() ? "1" : "0");
	client_print(id, print_chat, "Карта будет перезагружена, что бы применить эти изменения.");
	set_task(3.0, "do_changelevel");

	return PLUGIN_HANDLED;
}

public use_csdm_menu(id, menu, item)
{
	if (item < 0)
		return PLUGIN_CONTINUE;

	new command[24], paccess, call;

	if (!menu_item_getinfo(g_MainMenu, item, paccess, command, charsmax(command), _, 0, call)) {
		log_amx("Error: csdm_menu_item() failed (menu %d) (page %d) (item %d)", g_MainMenu, 0, item);
		return PLUGIN_HANDLED;
	}

	if (paccess && !(get_user_flags(id) & paccess)) {
		client_print(id, print_chat, "У вас нет доступа к этой опции.");
		return PLUGIN_HANDLED;
	}

	if(item == 0) {
		csdm_ctrl(id);

	} else if(item == 1) {
		csdm_sett_menu(id);

	} else if(item == 2) {
		csdm_reload(id);

	} else if(item == 3) {
		send_client_cmd(id, command);
	}

	return PLUGIN_HANDLED;
}

public use_csdm_sett_menu(id, menu, item)
{
	if (item < 0)
		return PLUGIN_CONTINUE;

	new command[24], paccess, call;

	if (!menu_item_getinfo(g_SettingsMenu, item, paccess, command, charsmax(command), _, 0, call)) {
		log_amx("Error: csdm_menu_item() failed (menu %d) (page %d) (item %d)", g_SettingsMenu, 0, item);
		return PLUGIN_HANDLED;
	}

	if (paccess && !(get_user_flags(id) & paccess)) {
		client_print(id, print_chat, "У вас нет доступа к этой опции.");
		return PLUGIN_HANDLED;
	}

	if(item == 0) {
		csdm_main_sett_menu(id);
	} else {
		send_client_cmd(id, command);
	}

	return PLUGIN_HANDLED;
}

public use_csdm_mainsett_menu(id, menu, item)
{
	if (item < 0)
		return PLUGIN_CONTINUE;

	new command[24], paccess, call;

	if (!menu_item_getinfo(g_MainSettMenu, item, paccess, command, charsmax(command), _, 0, call)) {
		log_amx("Error: csdm_menu_item() failed (menu %d) (page %d) (item %d)", g_MainSettMenu, 0, item);
		return PLUGIN_HANDLED;
	}

	if (paccess && !(get_user_flags(id) & paccess)) {
		client_print(id, print_chat, "У вас нет доступа к этой опции.");
		return PLUGIN_HANDLED;
	}

	if (equali(command,"strip_weap_ctrl")) {
		g_StripWeapons = (g_StripWeapons ? false:true);
		menu_display(id, g_MainSettMenu, 0);
		client_print(id, print_chat, "Скрытие оружия %s", g_StripWeapons ? "Включено" : "Выключено");
		log_amx("CSDM strip weapons %s", g_StripWeapons ? "enabled" : "disabled");
		csdm_write_cfg(id, "settings", "strip_weapons", g_StripWeapons ? "1" : "0");
		return PLUGIN_HANDLED;

	} else if (equali(command,"bomb_rem_ctrl")) {
		g_RemoveBomb = (g_RemoveBomb ? false:true);
		menu_display(id, g_MainSettMenu, 0);
		client_print(id, print_chat, "Удаление бомбы %s", g_RemoveBomb ? "Включено" : "Выключено");
		log_amx("CSDM removing bomb %s", g_RemoveBomb ? "enabled" : "disabled");
		csdm_write_cfg(id, "settings", "remove_bomb", g_RemoveBomb ? "1" : "0");
		client_print(id,print_chat,"Данные изменения вступят в силу после смены карты.");
		return PLUGIN_HANDLED;

	} else if (equali(command,"spawn_mode_ctrl")) {
		
		new stylename[24], style = csdm_curstyle();

		if (style == -1) {
			csdm_setstyle("preset");
		} else {
			csdm_setstyle("none");
		}

		style = csdm_curstyle();

		if (style == -1) {
			formatex(stylename, charsmax(stylename),"none");
		} else {
			formatex(stylename, charsmax(stylename),"preset");
		}

		menu_display(id, g_MainSettMenu, 0);
		client_print(id, print_chat, "Режим возрождения игроков установлен как %s", stylename);
		log_amx("CSDM spawn mode set to %s", stylename);
		csdm_write_cfg(id, "settings", "spawnmode", (style == -1) ? "none" : "preset");

		return PLUGIN_HANDLED;

	} else if (equali(command,"csdm_sett_back")) {
		menu_display(id, g_SettingsMenu, 0);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public hook_settings_display(player, menu, item)
{
	new paccess, command[24], call;

	menu_item_getinfo(menu, item, paccess, command, charsmax(command), _, 0, call);

	if (equali(command, "strip_weap_ctrl"))
	{
		if (!g_StripWeapons) {
			menu_item_setname(menu, item, "Скрытие оружия отключено");
		} else {
			menu_item_setname(menu, item, "Скрытие оружия включено");
		}

	} else if (equali(command, "bomb_rem_ctrl")) {

		if (!g_RemoveBomb) {
			menu_item_setname(menu, item, "Удаление бомбы отключено");
		} else {
			menu_item_setname(menu, item, "Удаление бомбы включено");
		}

	} else if (equali(command,"spawn_mode_ctrl")) {

		new style = csdm_curstyle();

		if (style == -1) {
			menu_item_setname(menu, item, "Предустановленные точки возрождения включены");
		} else {
			menu_item_setname(menu, item, "Предустановленные точки возрождения выключены");
		}
	}
}

public csdm_enable(id)
{
	if(!(get_user_flags(id) & D_ACCESS)) {
		return PLUGIN_HANDLED;
	}

	if (!csdm_active()) {
		csdm_set_active(1);
		client_print(id, print_chat, "CSDM включен.");
		csdm_write_cfg(id, "settings", "enabled", "1");
		client_print(id, print_chat, "Эти настройки вступят в силу после смены карты.");
		set_task(3.0, "do_changelevel");
	}

	return PLUGIN_HANDLED;
}

public csdm_disable(id)
{
	if( !(get_user_flags(id) & D_ACCESS) ) {
		return PLUGIN_HANDLED;
	}

	if (csdm_active()) {
		csdm_set_active(0);
		client_print(id, print_chat, "CSDM выключен.");
		csdm_write_cfg(id, "settings", "enabled", "0");
		client_print(id, print_chat, "Эти настройки вступят в силу после смены карты.");
		set_task(3.0, "do_changelevel");
	}

	return PLUGIN_HANDLED;
}

public say_respawn(id)
{
	if (g_options[CSDM_OPTION_SAYRESPAWN] == CSDM_SET_DISABLED || !csdm_active()) {
		client_print(id, print_chat, "Эта команда отключена!");
		return PLUGIN_HANDLED;
	}

	if (!is_user_alive(id))
	{
		new team = _:cs_get_user_team(id);

		if (team == _TEAM_T || team == _TEAM_CT) {
			csdm_respawn(id);
		}
	}

	return PLUGIN_CONTINUE;
}

public do_changelevel()
{
	new current_map[32];
	get_mapname(current_map, charsmax(current_map));

	if(is_map_valid(current_map)) {
		server_cmd("changelevel %s", current_map);
	}
}

public forward_set_model(ent, const model[]) 
{
	if (!csdm_active()) {
		return FMRES_IGNORED;
	}

	if (!pev_valid(ent) || (!equali(model, g_wbox_model) && !equali(model, g_shield_model))) {
		return FMRES_IGNORED;
	}

	static id, args[2];

	id = pev(ent, pev_owner);

	if (!(1 <= id <= g_max_clients)) {
		return FMRES_IGNORED;
	}

	args[0] = ent;
	args[1] = id;

	set_task(0.2, "delay_find_weapon", ent, args, 2);

	return FMRES_IGNORED;
}

public delay_find_weapon(args[])
{
	static ent, id;

	ent = args[0];
	id = args[1];

	if (!pev_valid(ent) || !is_user_connected(id)) {
		return;
	}

	new class[15];

	pev(ent, pev_classname, class, charsmax(class));

	if (equali(class, "weaponbox")) {
		run_drop_wbox(id, ent, 0);
	} else if (equali(class, "weapon_shield")) {
		run_drop_wbox(id, ent, 1);
	}
}

stock run_drop_wbox(id, ent, shield)
{
	static ret;

	ExecuteForward(g_drop_fwd, ret, id, ent, 0);

	if (ret == CSDM_DROP_REMOVE)
	{
		if (shield) {
			csdm_remove_weaponbox(id, ent, 0, 1, 1);
		} else {
			csdm_remove_weaponbox(id, ent, 0, 1, 0);
		}

		return 1;

	} else if (ret == CSDM_DROP_IGNORE) {
		return 0;
	}

	if (g_StayTime > 20 || g_StayTime < 0) {
		return 0;
	}

	if (ent)
	{
		new model[23];

		pev(ent, pev_model, model, charsmax(model));

		if (g_StripWeapons)
		{
			if(equali(model,"models/w_usp.mdl") || equali(model,"models/w_glock18.mdl")) {
				csdm_remove_weaponbox(id, ent, 0, 0, 0);
			}

		}
		else if (g_RemoveBomb)
		{
			if(equali(model,"models/w_backpack.mdl")) {
				csdm_remove_weaponbox(id, ent, 0, 0, 0);
			}

		} else if (shield) {
			csdm_remove_weaponbox(id, ent, g_StayTime, 1, 1);
		} else {
			csdm_remove_weaponbox(id, ent, g_StayTime, 1, 0);
		}

		return 1;
	}

	return 0;
}