/**
 * csdm_stripper.sma
 * Allows for Counter-Strike to be played as DeathMatch.
 *
 * CSDM Stripping entities plugin
 *
 * By KWo
 * (C)2007 KWo
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
#include <csdm>

#pragma semicolon 1

#define MAX_ENT_REM 100

new PLUGINNAME[] = "ReCSDM Stripper";
new VERSION[] = CSDM_VERSION;
new AUTHORS[] = "KWo";

new bool:g_Enabled = false;
new EntRemClass[MAX_ENT_REM][32];
new EntRemCount = 0;
new g_sett_menu = 0;
new g_ItemsInMenuNr = 0;
new g_PageStrExEn = 0;

public csdm_Init(const version[])
{
	if (version[0] == 0) {
		set_fail_state("ReCSDM failed to load.");
		return;
	}
}

public csdm_CfgInit()
{
	csdm_reg_cfg("stripper", "read_cfg");
}

public plugin_init()
{
	register_plugin(PLUGINNAME, VERSION, AUTHORS);

	register_concmd("stripper_ctrl", "stripper_ctrl", ADMIN_MAP, "Скрытие дополнительных объектов");

	new main_plugin = module_exists("csdm_main") ? true : false;

	if (main_plugin)
	{
		g_sett_menu = csdm_settings_menu();
		g_ItemsInMenuNr = menu_items(g_sett_menu);

		new callback = menu_makecallback("hook_strip_sett_display");
		menu_additem(g_sett_menu, "Скрытие дополнительных объектов [вкл/выкл]", "stripper_ctrl", ADMIN_MAP, callback);

		g_PageStrExEn = g_ItemsInMenuNr / 7;
	}

	set_task(2.0, "DoMapStrips");
}

public DoMapStrips()
{
	if (!g_Enabled || !csdm_active()) return;

	for(new i = 0; i < EntRemCount; i++) {
		csdm_remove_entity_all(EntRemClass[i]);
	}
}

public read_cfg(readAction, line[], section[])
{
	if (readAction == CFG_READ)
	{
		new setting[24], sign[3], value[32];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		if (equali(setting, "enabled")) {
			g_Enabled =  str_to_num(value) ? true : false;

		} else if (equali(setting, "class")) {

			if (EntRemCount < MAX_ENT_REM && !equali(value,"hostage_entity") && !equali(value, "player")) {	
				formatex(EntRemClass[EntRemCount], charsmax(value), value);
				EntRemCount++;
			}
		}

	} else if (readAction == CFG_RELOAD) {

		g_Enabled = false;

		for (new i = 0; i < EntRemCount; i++) {
			EntRemClass[i] = "\0";
		}

		EntRemCount = 0;
	}
}

public stripper_ctrl(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1)) {
	 	return PLUGIN_HANDLED;
	}

	g_Enabled = g_Enabled ? false : true;

	client_print(id, print_chat, "Скрытие дополнительных объектов на картах %s.", g_Enabled ? "Включено" : "Выключено");
	log_amx("CSDM removig extra entities from maps %s.", g_Enabled ? "enabled" : "disabled");

	menu_display(id, g_sett_menu, g_PageStrExEn);
	csdm_write_cfg(id, "stripper", "enabled", g_Enabled ? "1" : "0");
	client_print(id, print_chat,"Данные настройки вступят в силу после смены карты");

	return PLUGIN_HANDLED;
}

public hook_strip_sett_display(player, menu, item)
{
	new paccess, command[24], call;

	menu_item_getinfo(menu, item, paccess, command, charsmax(command), _, 0, call);

	if (equali(command, "stripper_ctrl")) {

		if (g_Enabled) {
			menu_item_setname(menu, item, "Скрытие дополнительных объектов включено");

		} else {
			menu_item_setname(menu, item, "Скрытие дополнительных объектов выключено");
		}
	}
}