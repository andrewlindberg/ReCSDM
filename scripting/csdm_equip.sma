/**
 * csdm_equip.sma
 * Allows for Counter-Strike to be played as DeathMatch.
 *
 * CSDM Equipment Menu
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
#include <csdm>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
#endif

//Tampering with the author and name lines can violate the copyright
new const PLUGINNAME[] = "ReCSDM Equip";
new const VERSION[] = CSDM_VERSION;
new const AUTHORS[] = "ReCSDM Team";

#define	EQUIP_PRI		(1<<0)
#define	EQUIP_SEC		(1<<1)
#define	EQUIP_ARMOR		(1<<2)
#define	EQUIP_GREN		(1<<3)
#define	EQUIP_ITEMS		(1<<4)
#define	EQUIP_ALL		(EQUIP_PRI|EQUIP_SEC|EQUIP_ARMOR|EQUIP_GREN|EQUIP_ITEMS)

#define	ITEMTYPES_NUM	42

new g_MaxPlayers;

new bool:IsRestricted[ITEMTYPES_NUM] = {false, ...};	// Contains if an item is restricted or not
new RestrictWps[ITEMTYPES_NUM] = {32, ...};
new UsedWpsT[ITEMTYPES_NUM] = {0, ...};
new UsedWpsCT[ITEMTYPES_NUM] = {0, ...};

//Menus
new const g_SecMenu[] = "Меню Первичного оружия";		// Menu Name
new g_SecMenuID = -1;													// Menu ID
new g_cSecondary;														// Menu Callback
new bool:g_mSecStatus = true;												// Menu Available?

new const g_PrimMenu[] = "Меню Вторичного оружия";
new g_PrimMenuID = -1;
new g_cPrimary;
new bool:g_mPrimStatus = true;

new const g_ArmorMenu[] = "Броня";
new g_ArmorMenuID = -1;
new bool:g_mArmorStatus = true;

new const g_NadeMenu[] = "Гранаты";
new g_NadeMenuID = -1;
new bool:g_mNadeStatus = true;

new const g_EquipMenu[] = "Экипировка";
new g_EquipMenuID = -1;
new g_cEquip;

new bool:g_mShowuser[CSDM_MAXPLAYERS + 1] = true;

new g_Teamuser[CSDM_MAXPLAYERS + 1];

new bool:g_mAutoNades = false;
new bool:g_mAutoArmor = false;
new bool:g_AlwaysAllowGunMenu = false;
new bool:g_AmmoRefill = false;
new g_WeaponStayTime = 0;

//Weapon Selections
new g_SecWeapons[CSDM_MAXPLAYERS + 1][18];
new g_PrimWeapons[CSDM_MAXPLAYERS + 1][18];
new bool:g_mNades[CSDM_MAXPLAYERS + 1];
new bool:g_mArmor[CSDM_MAXPLAYERS + 1];

//Config weapon storage holders
new g_BotPrim[MAX_WEAPONS][18];
new g_iNumBotPrim;

new g_BotSec[MAX_WEAPONS][18];
new g_iNumBotSec;

new g_Secondary[MAX_SECONDARY][18];
new bool:g_DisabledSec[MAX_WEAPONS];
new g_iNumSec;
new g_iNumUsedSec = 0;

new g_Primary[MAX_PRIMARY][18];
new bool:g_DisabledPrim[MAX_WEAPONS];
new g_iNumPrim;
new g_iNumUsedPrim = 0;

new pv_csdm_additems;

#define SILENCED_M4A1		0
#define SILENCED_USP		1
new bool:g_Silenced[CSDM_MAXPLAYERS + 1][2];

//Misc
new g_Armor = 0;
new fnadesnum = 0;
new bool:g_Flash = false;
new bool:g_Nade = false;
new bool:g_Smoke = false;
new bool:g_NightVision = false;
new bool:g_DefuseKit = false;

// page info for settings in CSDM Setting Menu
new g_SettingsMenu = 0;
new g_EquipSettMenu = 0;
new g_ItemsInMenuNr = 0;
new g_PageSettMenu = 0;

//Quick Fix for menu pages
new g_MenuState[CSDM_MAXPLAYERS + 1] = {0};

new Float:g_maxdelmenutime = 30.0;

#define	PDATA_SAFE				2
#define	OFFSET_LINUX_WEAPONS	4
#define	m_pPlayer					41
#define	m_iId						43

public csdm_Init(const version[])
{
	if (version[0] == 0) {
		set_fail_state("ReCSDM failed to load.");
		return;
	}

	// Menus and callbacks
	g_SecMenuID = menu_create(g_SecMenu, "m_SecHandler", 0);
	g_PrimMenuID = menu_create(g_PrimMenu, "m_PrimHandler", 0);
	g_ArmorMenuID = menu_create(g_ArmorMenu, "m_ArmorHandler", 0);
	g_NadeMenuID = menu_create(g_NadeMenu, "m_NadeHandler", 0);
	g_EquipMenuID = menu_create(g_EquipMenu, "m_EquipHandler", 0);

	menu_setprop(g_PrimMenuID, MPROP_EXIT, MEXIT_NEVER);
	menu_setprop(g_SecMenuID, MPROP_EXIT, MEXIT_NEVER);

	g_cSecondary = menu_makecallback("c_Secondary");
	g_cPrimary = menu_makecallback("c_Primary");
	g_cEquip = menu_makecallback("c_Equip");
}

public csdm_CfgInit()
{
	csdm_reg_cfg("settings", "cfgMainSettings");
	csdm_reg_cfg("misc", "cfgMiscSettings");

	// Config reader
	csdm_reg_cfg("equip", "cfgSetting");

	// In order for weapon menu
	csdm_reg_cfg("secondary", "cfgSecondary");
	csdm_reg_cfg("primary", "cfgPrimary");
	csdm_reg_cfg("botprimary", "cfgBotPrim");
	csdm_reg_cfg("botsecondary", "cfgBotSec");
	csdm_reg_cfg("item_restrictions", "cfgrestricts");

	set_task(2.0, "check_cvar_pointers", 790);
}

public check_cvar_pointers()
{
	pv_csdm_additems = get_cvar_pointer("csdm_add_items");
}

public plugin_init()
{
	register_plugin(PLUGINNAME, VERSION, AUTHORS);

	buildMenu(); // Build Armor/Nade/Equip Menu's

	register_clcmd("say guns", "enableMenu");
	register_clcmd("say /guns", "enableMenu");
	register_clcmd("say menu", "enableMenu");
	register_clcmd("say enablemenu", "enableMenu");
	register_clcmd("say enable_menu", "enableMenu");
	register_clcmd("csdm_equip_sett_menu", "csdm_equip_sett_menu", ADMIN_MAP, "CSDM Equip Settings Menu");
	register_event("TextMsg","eRestart","a","2&#Game_C","2&#Game_w");

	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "Weapon_SecondaryAttack_usp_Post", true);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_m4a1", "Weapon_SecondaryAttack_m4a1_Post", true);

	new main_plugin = module_exists("csdm_main") ? true : false;

	if(main_plugin)
	{
		g_SettingsMenu = csdm_settings_menu();
		g_ItemsInMenuNr = menu_items(g_SettingsMenu);
		g_PageSettMenu = g_ItemsInMenuNr / 7;

		g_EquipSettMenu = menu_create("Меню настроек экипировки", "use_csdm_equip_menu");

		menu_additem(g_SettingsMenu, "Настройки экипировки", "csdm_equip_sett_menu", ADMIN_MAP);

		if(g_EquipSettMenu)
		{
			new callback = menu_makecallback("hook_equip_sett_display");

			menu_additem(g_EquipSettMenu, "Меню первичной экипировки [вкл/выкл]", "1", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Меню вторичной экипировки [вкл/выкл]", "2", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Меню брони [вкл/выкл]", "3", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Меню гранат [вкл/выкл]", "4", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Автоматическая выдача брони [вкл/выкл]", "5", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Автоматическая выдача шлема [вкл/выкл]", "6", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Автоматическая выдача гранат [вкл/выкл]", "7", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Автоматическая выдача щипцов [вкл/выкл]", "8", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Автоматическая выдача ночного виденья [вкл/выкл]", "9", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Световые гранаты [вкл/выкл]", "10", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Дымовые гранаты [вкл/выкл]", "11", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Разрывные гранаты [вкл/выкл]", "12", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Разрешить всегда использовать меню оружия [Вкл/Выкл]", "13", ADMIN_MAP, callback);
			menu_additem(g_EquipSettMenu, "Назад", "14", 0, -1);
		}
	} else {
		log_amx("CSDM - csdm_equip - no main plugin loaded");
	}

	if(g_iNumUsedSec == 0)
		g_mSecStatus = false;

	if(g_iNumUsedPrim == 0)
		g_mPrimStatus = false;

	g_MaxPlayers = get_maxplayers();
}

public eRestart()
{
	arrayset(UsedWpsT, 0, ITEMTYPES_NUM);
	arrayset(UsedWpsCT, 0, ITEMTYPES_NUM);

	return PLUGIN_CONTINUE;
}

public client_connect(id)
{
	g_mShowuser[id] = true;
	g_mNades[id] = false;
	g_mArmor[id] = false;
	g_Silenced[id][SILENCED_M4A1] = false;
	g_Silenced[id][SILENCED_USP] = false;

	return PLUGIN_CONTINUE;
}

public client_disconnected(id)
{
	g_mShowuser[id] = false;
	g_mNades[id] = false;
	g_mArmor[id] = false;

	new weapons[MAX_WEAPONS], num, weapid;

	get_user_weapons(id, weapons, num);

	for (new i = 0; i < num; i++)
	{
		weapid = weapons[i];

		if(IsRestricted[weapid] && UsedWpsT[weapid] > 0 && g_Teamuser[id] == _TEAM_T) {
			UsedWpsT[weapid]--;
		}

		if(IsRestricted[weapid] && UsedWpsCT[weapid] > 0 && g_Teamuser[id] == _TEAM_CT) {
			UsedWpsCT[weapid]--;
		}
	}

	return PLUGIN_CONTINUE;
}

public csdm_RemoveWeapon(owner, entity_id, boxed_id)
{
	if(!pev_valid(entity_id))
		return PLUGIN_HANDLED;

	new szClassname[32], weapon, team;

	pev(entity_id, pev_classname, szClassname, charsmax(szClassname));

	weapon = get_weaponid(szClassname);

	if(owner && weapon)
	{
		team = _:cs_get_user_team(owner);

		if(IsRestricted[weapon] && UsedWpsT[weapon] > 0 && team == _TEAM_T) {
			UsedWpsT[weapon]--;
			// log_amx("[DEBUG] CSDM - restricted weapon %s removed. Currently there is %d such weapons on the map.", szClassname, UsedWpsT[weapon])
		}

		if(IsRestricted[weapon] && UsedWpsCT[weapon] > 0 && team == _TEAM_CT) {
			UsedWpsCT[weapon]--;
			//log_amx("[DEBUG] CSDM - restricted weapon %s removed. Currently there is %d such weapons on the map.", szClassname, UsedWpsCT[weapon])
		}
	}

	return PLUGIN_CONTINUE;
}

public csdm_PostDeath(killer, victim, headshot, const weapon[])
{
	/* Clean up any defusal kits we might have made! */
	if(!g_DefuseKit) return;

	g_Teamuser[victim] = _:cs_get_user_team(victim);

	/* This might have a race condition for team switches... */
	if(g_Teamuser[victim] == _TEAM_CT)
		cs_set_user_defuse(victim, 0);
}

public Weapon_SecondaryAttack_usp_Post(Ent)
{
	if(pev_valid(Ent) != PDATA_SAFE)
		return HAM_IGNORED;

	new id = get_pdata_cbase(Ent, m_pPlayer, OFFSET_LINUX_WEAPONS);

	if(id < 1 || id > g_MaxPlayers)
		return HAM_IGNORED;

	g_Silenced[id][SILENCED_USP] = cs_get_weapon_silen(Ent) ? true : false;

	return HAM_IGNORED;
}

public Weapon_SecondaryAttack_m4a1_Post(Ent)
{
	if(pev_valid(Ent) != PDATA_SAFE)
		return HAM_IGNORED;

	new id = get_pdata_cbase(Ent, m_pPlayer, OFFSET_LINUX_WEAPONS);

	if(id < 1 || id > g_MaxPlayers)
		return HAM_IGNORED;

	g_Silenced[id][SILENCED_M4A1] = cs_get_weapon_silen(Ent) ? true : false;

	return HAM_IGNORED;
}

public cfgSecondary(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		if (g_iNumSec >= MAX_SECONDARY)
			return PLUGIN_HANDLED;

		new wep[16], display[48], dis[4], cmd[6];

		parse(line, wep, charsmax(wep), display, charsmax(display), dis, charsmax(dis));

		new disabled = str_to_num(dis);

		//Copy weapon into array
		formatex(g_Secondary[g_iNumSec], charsmax(g_Secondary[]), "weapon_%s", wep);

		g_DisabledSec[g_iNumSec] = disabled ? false : true;

		formatex(cmd, 5, "%d ", g_iNumSec);

		g_iNumSec++;

		if(disabled > 0)
			g_iNumUsedSec++;

		//TODO: Add menu_destroy_items to remake menu on cfg reload
		menu_additem(g_SecMenuID, display, cmd, 0, g_cSecondary);

	} else if (readAction == CFG_RELOAD) {
		g_SecMenuID = menu_create(g_SecMenu, "m_SecHandler", 0);
		g_iNumSec = 0;
		g_iNumUsedSec = 0;

	} else if(readAction == CFG_DONE) {
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgPrimary(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		if(g_iNumPrim >= MAX_PRIMARY)
			return PLUGIN_HANDLED;

		new wep[16], display[48], dis[4], cmd[6];

		parse(line, wep, charsmax(wep), display, charsmax(display), dis, charsmax(dis));

		new disabled = str_to_num(dis);

		//Copy weapon into array
		formatex(g_Primary[g_iNumPrim], charsmax(g_Secondary[]), "weapon_%s", wep);

		g_DisabledPrim[g_iNumPrim] = disabled ? false : true;

		formatex(cmd, charsmax(cmd), "%d", g_iNumPrim);

		g_iNumPrim++;

		if(disabled > 0)
			g_iNumUsedPrim++;

		//TODO: Add menu_destroy_items to remake menu on cfg reload
		menu_additem(g_PrimMenuID, display, cmd, 0, g_cPrimary);

	} else if(readAction == CFG_RELOAD) {
		g_PrimMenuID = menu_create(g_PrimMenu, "m_PrimHandler", 0);
		g_iNumPrim = 0;
		g_iNumUsedPrim = 0;

	} else if(readAction == CFG_DONE) {
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgBotPrim(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new wep[16], display[32];

		parse(line, wep, charsmax(wep), display, charsmax(display));

		//Copy weapon into array
		formatex(g_BotPrim[g_iNumBotPrim], charsmax(g_BotPrim[]), "weapon_%s", wep);

		g_iNumBotPrim++;

	} else if(readAction == CFG_RELOAD) {
		g_iNumBotPrim = 0;

	} else if(readAction == CFG_DONE) {
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgBotSec(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new wep[16], display[32];

		parse(line, wep, charsmax(wep), display, charsmax(display));

		//Copy weapon into array
		formatex(g_BotSec[g_iNumBotSec], charsmax(g_BotPrim[]), "weapon_%s", wep);

		g_iNumBotSec++;

	} else if(readAction == CFG_RELOAD) {
		g_iNumBotSec = 0;

	} else if(readAction == CFG_DONE) {
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgSetting(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new setting[24], sign[3], value[6];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		// Menus settings
		if(contain(setting,"menus") != -1)
		{
			if(containi(value, "p") != -1)
				g_mPrimStatus = true;

			if(containi(value, "s") != -1)
				g_mSecStatus = true;

			if(containi(value, "a") != -1)
				g_mArmorStatus = true;

			if(containi(value, "g") != -1)
				g_mNadeStatus = true;

			return PLUGIN_HANDLED;

		} else if(contain(setting, "autoitems") != -1) {

			if(containi(value, "a")  != -1) {
				//Disable Armor Menu
				g_mArmorStatus = false;
				g_mAutoArmor = true;
				g_Armor = 1;
			}

			if(containi(value, "h") != -1) {
				//Disable Armor Menu
				g_mArmorStatus = false;
				g_mAutoArmor = true;
				g_Armor = 2;
			}

			if(containi(value, "g") != -1) {
				//Disable Grenade Menu
				g_mNadeStatus = false;
				g_mAutoNades = true;
			}

			if(containi(value, "d") != -1)
				g_DefuseKit = true;

			if(containi(value, "n") != -1)
				g_NightVision = true;

			return PLUGIN_HANDLED;

		} else if(contain(setting, "grenades") != -1) {

			if(containi(value, "f") != -1)
				g_Flash = true;

			if(containi(value, "h") != -1)
				g_Nade = true;

			if (containi(value, "s") != -1)
				g_Smoke = true;

		} else if(contain(setting, "fnadesnum") != -1) {
			fnadesnum = str_to_num(value);

		} else if(contain(setting, "always_allow_gunmenu") != -1) {
			g_AlwaysAllowGunMenu = str_to_num(value)? true : false;
		}

		return PLUGIN_HANDLED;

	} else if(readAction == CFG_RELOAD) {
		g_mArmorStatus = false;
		g_mNadeStatus = false;
		g_Flash = false;
		g_Nade = false;
		g_Smoke = false;
		g_Armor = 0;
		g_mSecStatus = false;
		g_mPrimStatus = false;
		g_mAutoNades = false;
		g_DefuseKit = false;
		g_NightVision = false;
		fnadesnum = 1;

	} else if(readAction == CFG_DONE) {
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgrestricts(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new itemname[24], value[32], limit;
		parse(line, itemname, charsmax(itemname), value, charsmax(value));

		limit = 0;

		if(value[0] != '0')
			limit = str_to_num(value);

		new weapname[24], weaptype;

		formatex(weapname, charsmax(weapname), "weapon_%s", itemname);

		weaptype = getWeapId(weapname);

		// weaptype = get_weaponid(weapname) // why this crap doesn't work here but works correctly during the game ?!?
		// log_amx("[DEBUG] CSDM - reading restrictions, weapon %s (weaptype = %d).", itemname, weaptype)

		if(weaptype != 0) {
			IsRestricted[weaptype] = true;
			RestrictWps[weaptype] = limit;
		}

		// log_amx("[DEBUG] CSDM - reading restrictions, restricted %s (weaptype = %d) = %d", itemname, weaptype, limit)
	}
	else if(readAction == CFG_RELOAD)
	{
		// Reset all restrictions
		arrayset(IsRestricted, false, ITEMTYPES_NUM);
		arrayset(RestrictWps, 32, ITEMTYPES_NUM);
		return PLUGIN_HANDLED;
	}
	else if(readAction == CFG_DONE)
	{
		//Nothing for now
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

public cfgMainSettings(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new setting[24], sign[3], value[32];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		if(equali(setting, "weapons_stay")) {
			g_WeaponStayTime = str_to_num(value);
		}
	}
}

public cfgMiscSettings(readAction, line[], section[])
{
	if(readAction == CFG_READ)
	{
		new setting[24], sign[3], value[32];

		parse(line, setting, charsmax(setting), sign, charsmax(sign), value, charsmax(value));

		if(equali(setting, "ammo_refill")) {
			g_AmmoRefill = str_to_num(value) ? true : false;
		}

	} else if(readAction == CFG_RELOAD) {
		g_AmmoRefill = true;
	}
}

//Equipment Menu callback
public c_Equip(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new weapon_s, weapon_p;
	weapon_s = get_weaponid(g_SecWeapons[id]);
	weapon_p = get_weaponid(g_PrimWeapons[id]);

	if(weapon_s == 0 && g_mSecStatus
		|| weapon_p == 0 && g_mPrimStatus
		|| IsRestricted[weapon_s]
		|| IsRestricted[weapon_p]) {
			return ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

//Secondary Weapon Callback
public c_Secondary(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new dis = str_to_num(cmd);
	new team = _:cs_get_user_team(id);
	new weaptype = get_weaponid(g_Secondary[dis]);

	//Check to see if item is disabled
	if(g_DisabledSec[dis]) {
		return ITEM_DISABLED;

	} else if(!IsRestricted[weaptype]) {
		return ITEM_ENABLED;

	} else if(UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T 
		|| UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT) {
		return ITEM_ENABLED;
	}

	return ITEM_DISABLED;
}

//Primary Weapon Callback
public c_Primary(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	// Get item info
	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new dis = str_to_num(cmd);
	new team = _:cs_get_user_team(id);
	new weaptype = get_weaponid(g_Primary[dis]);

	//Check to see if item is disabled
	if(g_DisabledPrim[dis]) {
		return ITEM_DISABLED;

	} else if(!IsRestricted[weaptype]) {
		return ITEM_ENABLED;

	} else if(UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T 
		|| UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT) {
			return ITEM_ENABLED;
	}

	return ITEM_DISABLED;
}

//Equipment Menu handler
public m_EquipHandler(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	// Get item info
	new cmd[2], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	switch(str_to_num(cmd))
	{
		case 1:
		{
			if(g_mSecStatus)
				menu_display(id, g_SecMenuID, 0);

			else if(g_mPrimStatus)
				menu_display(id, g_PrimMenuID, 0);

			else if(g_mArmorStatus)
				menu_display(id, g_ArmorMenuID, 0);

			else if(g_mNadeStatus)
			{
				if(g_mAutoArmor) 
					equipUser(id, EQUIP_ARMOR);

				menu_display(id, g_NadeMenuID, 0);

			} else {
				if(g_mAutoArmor) 
					equipUser(id, EQUIP_ARMOR);

				if(g_mAutoNades) 
					equipUser(id, EQUIP_GREN);

				equipUser(id, EQUIP_ITEMS);
			}
		}
		case 2:
		{
			// Equip person with last settings
			equipUser(id, EQUIP_ALL);
		}
		case 3:
		{
			g_mShowuser[id] = false;
			client_print(id, print_chat, "");
			equipUser(id, EQUIP_ALL);
		}
	}

	return PLUGIN_HANDLED;
}

//Secondary Weapon Menu handler
public m_SecHandler(id, menu, item)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	// Get item info
	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new wep = str_to_num(cmd);

	new team = _:cs_get_user_team(id);
	new weaptype = get_weaponid(g_Secondary[wep]);

	if((UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T 
		|| UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT)
		&& !g_DisabledSec[wep])
	{
		copy(g_SecWeapons[id],17,g_Secondary[wep]);
		equipUser(id, EQUIP_SEC);

	} else if(g_mSecStatus) {
		menu_display(id, g_SecMenuID, 0);
		return PLUGIN_HANDLED;
	}

	// Show next menu here

	if(g_mPrimStatus)
		menu_display(id, g_PrimMenuID, 0);

	else if(g_mArmorStatus)
		menu_display(id, g_ArmorMenuID, 0);

	else if(g_mNadeStatus)
	{
		if (g_mAutoArmor)
			equipUser(id, EQUIP_ARMOR);

		menu_display(id, g_NadeMenuID, 0);

	} else {
		if (g_mAutoArmor)
			equipUser(id, EQUIP_ARMOR);

		if (g_mAutoNades)
			equipUser(id, EQUIP_GREN);

		equipUser(id, EQUIP_ITEMS);
	}

	return PLUGIN_HANDLED;
}

//Primary Weapon Menu handler
public m_PrimHandler(id, menu, item)
{
	if (item < 0)
		return PLUGIN_HANDLED;

	// Get item info
	new cmd[6], iName[64], access, callback;

	if(menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback))
	{
		new wep = str_to_num(cmd);
		new team = _:cs_get_user_team(id);
		new weaptype = get_weaponid(g_Primary[wep]);

		if((UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T 
			|| UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT)
			&& !g_DisabledPrim[wep])
		{
			copy(g_PrimWeapons[id], charsmax(g_PrimWeapons[]), g_Primary[wep]);
			equipUser(id, EQUIP_PRI);

		} else if (g_mPrimStatus) {
			menu_display(id, g_PrimMenuID, 0);
			return PLUGIN_HANDLED;
		}
	}

	// Show next menu here
	if(g_mArmorStatus) {
		menu_display(id, g_ArmorMenuID, 0);
	}
	else if(g_mNadeStatus)
	{
		if(g_mAutoArmor)
			equipUser(id, EQUIP_ARMOR);

		menu_display(id, g_NadeMenuID, 0);

	} else {
		if (g_mAutoArmor)
			equipUser(id, EQUIP_ARMOR);

		if (g_mAutoNades)
			equipUser(id, EQUIP_GREN);

		equipUser(id, EQUIP_ITEMS);
	}

	return PLUGIN_HANDLED;
}

//Armor Menu handler
public m_ArmorHandler(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	// Get item info
	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new choice = str_to_num(cmd);

	if(choice == 1) {
		g_mArmor[id] = true;
	} else if (choice == 2) {
		g_mArmor[id] = false;
	}

	equipUser(id, EQUIP_ARMOR);

	// Show next menu here

	if(g_mNadeStatus) {
		menu_display(id, g_NadeMenuID, 0);
	} else {
		if (g_mAutoNades)
			equipUser(id, EQUIP_GREN);

		equipUser(id, EQUIP_ITEMS);
	}

	return PLUGIN_HANDLED;
}

//Nade Menu handler
public m_NadeHandler(id, menu, item)
{
	if (item < 0)
		return PLUGIN_CONTINUE;

	new cmd[6], iName[64], access, callback;

	menu_item_getinfo(menu, item, access, cmd, charsmax(cmd), iName, charsmax(iName), callback);

	new choice = str_to_num(cmd);

	if (choice == 1) {
		g_mNades[id] = true;
	} else if (choice == 2) {
		g_mNades[id] = false;
	}

	equipUser(id, EQUIP_GREN);
	equipUser(id, EQUIP_ITEMS);

	return PLUGIN_HANDLED;
}

buildMenu()
{
	//Equip Menu
	menu_additem(g_EquipMenuID, "Новая экипировка", "1", 0, -1);
	menu_additem(g_EquipMenuID, "Предыдущий выбор", "2", 0, g_cEquip);
	menu_additem(g_EquipMenuID, "Предыдущий выбор и больше не спрашивать", "3", 0, g_cEquip);
	menu_setprop(g_EquipMenuID, MPROP_EXIT, MEXIT_NEVER);

	//Armor Menu
	menu_additem(g_ArmorMenuID, "Да, выдать броню", "1", 0, -1);
	menu_additem(g_ArmorMenuID, "Без брони", "2", 0, -1);
	menu_setprop(g_ArmorMenuID, MPROP_EXIT, MEXIT_NEVER);

	//Nade Menu
	menu_additem(g_NadeMenuID, "Все гранаты", "1", 0, -1);
	menu_additem(g_NadeMenuID, "Без гранат", "2", 0, -1);
	menu_setprop(g_NadeMenuID, MPROP_EXIT, MEXIT_NEVER);

	return PLUGIN_HANDLED;
}

equipUser(id, to)
{
	if(!is_user_alive(id)) return;

	new weaptype;
	new team = _:cs_get_user_team(id);

	if((to & EQUIP_SEC) && get_weaponid(g_SecWeapons[id])) {

		//Give Secondary
		GiveUserFullWeapon(id, g_SecWeapons[id]);
	}

	if((to & EQUIP_PRI) && get_weaponid(g_PrimWeapons[id])) {

		//Give Primary
		GiveUserFullWeapon(id, g_PrimWeapons[id]);
	}

	if(to & EQUIP_ARMOR)
	{
		//Give Armor
		if(g_mAutoArmor || g_mArmor[id]) {
			new armor = g_mArmor[id] ? 2 : g_Armor;
			cs_set_user_armor(id, DEFAULT_ARMOR, CsArmorType:armor);
		}
	}

	if(to & EQUIP_GREN)
	{
		//Give Nades
		if(g_mNades[id] || g_mAutoNades)
		{
			if(g_Nade)
			{

				weaptype = get_weaponid("weapon_hegrenade");

				if(IsRestricted[weaptype])
				{

					if(UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T) {
						UsedWpsT[weaptype]++;
						GiveUserFullWeapon(id,"weapon_hegrenade");
					}

					if(UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT) {
						UsedWpsCT[weaptype]++;
						GiveUserFullWeapon(id,"weapon_hegrenade");
					}

				} else {
					GiveUserFullWeapon(id,"weapon_hegrenade");
				}
			}

			if(g_Smoke)
			{
				weaptype = get_weaponid("weapon_smokegrenade");

				if(IsRestricted[weaptype])
				{

					if(UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T) {
						UsedWpsT[weaptype]++;
						GiveUserFullWeapon(id,"weapon_smokegrenade");
					}

					if(UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT) {
						UsedWpsCT[weaptype]++;
						GiveUserFullWeapon(id,"weapon_smokegrenade");
					}

				} else {
					GiveUserFullWeapon(id, "weapon_smokegrenade");
				}
			}

			if(g_Flash && fnadesnum)
			{

				weaptype = get_weaponid("weapon_flashbang");

				if(IsRestricted[weaptype])
				{

					if(UsedWpsT[weaptype] < RestrictWps[weaptype] && team == _TEAM_T) {
						UsedWpsT[weaptype]++;
						GiveUserFullWeapon(id, "weapon_flashbang");
					}

					if(UsedWpsCT[weaptype] < RestrictWps[weaptype] && team == _TEAM_CT) {
						UsedWpsCT[weaptype]++;
						GiveUserFullWeapon(id, "weapon_flashbang");
					}

				} else {
					GiveUserFullWeapon(id, "weapon_flashbang");
				}

				if(fnadesnum == 2)
				{
					if(IsRestricted[weaptype])
					{

						if((UsedWpsT[weaptype] < RestrictWps[weaptype]) && (team == _TEAM_T)) {
							UsedWpsT[weaptype]++;
							GiveUserFullWeapon(id, "weapon_flashbang");
						}

						if((UsedWpsCT[weaptype] < RestrictWps[weaptype]) && (team == _TEAM_CT)) {
							UsedWpsCT[weaptype]++;
							GiveUserFullWeapon(id, "weapon_flashbang");
						}

					} else {
						GiveUserFullWeapon(id, "weapon_flashbang");
					}

				}
			}
		}
	}

	if (to & EQUIP_ITEMS)
	{
		if (g_DefuseKit && (_:cs_get_user_team(id) == _TEAM_CT)) {
			cs_set_user_defuse(id, 1);
		}

		if (g_NightVision) {
			cs_set_user_nvg(id, 1);
		}
	}
}

GiveUserFullWeapon(id, const wp[])
{
	if(!is_user_connected(id)) return;

	/** First check to make sure the user does not have a weapon in this slot */
	new wpnid = get_weaponid(wp);
	new weapons[MAX_WEAPONS], num, name[24], weap, slot;
	new team = _:cs_get_user_team(id);

	if(wpnid == 0)
	{
		if(equal(wp, "weapon_shield")) {
			slot = SLOT_PRIMARY;
			wpnid = -1;
		}

	} else {
		slot = g_WeaponSlots[wpnid];
	}

	if((slot == SLOT_SECONDARY || slot == SLOT_PRIMARY) && wpnid > 0)
	{
		get_user_weapons(id, weapons, num);

		for (new i = 0; i < num; i++)
		{
			weap = weapons[i];

			if(weap == wpnid)
				continue;

			if(g_WeaponSlots[weap] == slot)
			{
				if(slot == SLOT_SECONDARY && cs_get_user_shield(id)) {
					//temporary fix!
					drop_with_shield(id, weap);

				} else {
					get_weaponname(weap, name, charsmax(name));
					csdm_force_drop(id, name);
				}
			}
		}

	} else if(slot == SLOT_PRIMARY && wpnid == -1 && cs_get_user_shield(id)) {
		return;
	}

	if(slot == SLOT_PRIMARY && cs_get_user_shield(id) && wpnid > 0) {
		csdm_fwd_drop(id, -1, "weapon_shield");
	}

	new item_id = csdm_give_item(id, wp);

	if(item_id > 0)
	{
		if (wpnid == CSW_M4A1) {
			cs_set_weapon_silen(item_id, g_Silenced[id][SILENCED_M4A1], 1);
		} else if (wpnid == CSW_USP) {
			cs_set_weapon_silen(item_id, g_Silenced[id][SILENCED_USP], 1);
		}
	}

	if(wpnid > 0)
	{
		new bpammo = g_MaxBPAmmo[wpnid];

		if(bpammo)
			cs_set_user_bpammo(id, wpnid, bpammo);

		if (IsRestricted[wpnid])
		{
			if ((UsedWpsT[wpnid] < RestrictWps[wpnid]) && (team == _TEAM_T)) {
				UsedWpsT[wpnid]++;
			}

			if ((UsedWpsCT[wpnid] < RestrictWps[wpnid]) && (team == _TEAM_CT)) {
				UsedWpsCT[wpnid]++;
			}
		}
	}
}

// MAIN FUNCTION OF THE PLUGIN
public csdm_PostSpawn(player)
{
	if(pv_csdm_additems)
	{
		if(get_pcvar_num(pv_csdm_additems)) {
			return PLUGIN_CONTINUE;
		}
	}

	g_Teamuser[player] = _:cs_get_user_team(player);

	if(is_user_bot(player))
	{
		new i, weapon_p, weapon_s;
		new randPrim = random_num(0, g_iNumBotPrim-1);
		new randSec = random_num(0, g_iNumBotSec-1);

		weapon_p = get_weaponid(g_BotPrim[randPrim]);

		i = 0;

		while(i < 10 && IsRestricted[weapon_p] 
			&& (UsedWpsT[weapon_p] >= RestrictWps[weapon_p] && g_Teamuser[player] == _TEAM_T 
			|| UsedWpsCT[weapon_p] >= RestrictWps[weapon_p] && g_Teamuser[player] == _TEAM_CT))
		{
			randPrim++;

			if(randPrim >= g_iNumBotPrim)
				randPrim = 0;

			weapon_p = get_weaponid(g_BotPrim[randPrim]);

			i++;
		}

		weapon_s = get_weaponid(g_BotSec[randSec]);

		i = 0;

		while(i < 10 && IsRestricted[weapon_s] 
			&& (UsedWpsT[weapon_s] >= RestrictWps[weapon_s] && g_Teamuser[player] == _TEAM_T 
			|| UsedWpsCT[weapon_s] >= RestrictWps[weapon_s] && g_Teamuser[player] == _TEAM_CT))
		{
			randSec++;

			if(randSec >= g_iNumBotSec)
				randSec = 0;

			weapon_s = get_weaponid(g_BotSec[randSec]);

			i++;
		}

		new randArm = random_num(0, 2);
		new randGre = random_num(0, 2);

		if(g_mPrimStatus)
			GiveUserFullWeapon(player, g_BotPrim[randPrim]);

		if(g_mSecStatus)
			GiveUserFullWeapon(player, g_BotSec[randSec]);

		g_mArmor[player] = (g_mArmorStatus && randArm);
		g_mNades[player] = (g_mNadeStatus && randGre);

		if(g_mAutoArmor || g_mArmor[player])
			equipUser(player, EQUIP_ARMOR);

		if(g_mAutoNades || g_mNades[player])
			equipUser(player, EQUIP_GREN);

		if (g_DefuseKit)
			equipUser(player, EQUIP_ITEMS);

	} else {

		if(g_mShowuser[player])
		{
			new oldmenuid, newmenuid;
			new bool:bEquipMenuDisp = false;

			player_menu_info(player, oldmenuid, newmenuid); // main thing to prevent overwrite some menu by gun menu

			if(newmenuid != -1 && (newmenuid == g_SecMenuID || newmenuid == g_PrimMenuID 
				|| newmenuid == g_ArmorMenuID || newmenuid == g_EquipMenuID))
			{
				bEquipMenuDisp = true;
			}

			if(bEquipMenuDisp || oldmenuid <= 0 || g_maxdelmenutime == 0)
			{
				g_MenuState[player] = 1;
				menu_display(player, g_EquipMenuID, 0);

			} else {

				new param[1];
				param[0] = player;

				if(g_maxdelmenutime > 0)
					set_task(1.0, "checkmenu", 850 + player, param, 1, "b");

				set_task(g_maxdelmenutime, "menu_delayed", 700 + player, param, 1);
			}

		} else {
			g_MenuState[player] = 0;
			set_task(0.2, "delay_equip", player);
			// equipUser(player, EQUIP_ALL)
		}
	}

	return PLUGIN_CONTINUE;
}

public delay_equip(id)
{
	if(is_user_connected(id))
		equipUser(id, EQUIP_ALL);
}

public enableMenu(id)
{
	if(!csdm_active())
		return PLUGIN_CONTINUE;

	if(!g_mShowuser[id])
	{
		g_mShowuser[id] = true;
		client_print(id, print_chat, "[CSDM] Меню экипировки было вновь включено.");

		if(!g_MenuState[id]) {
			g_MenuState[id] = 1;
			menu_display(id, g_EquipMenuID, 0);
		}

	} else if(!g_AlwaysAllowGunMenu || !g_AmmoRefill || (g_WeaponStayTime > 5)) {

		if(!g_AlwaysAllowGunMenu) 
			client_print(id, print_chat, "[CSDM] Меню экипировки уже включено. Вы уже должны иметь оружие");

		else if(!g_AmmoRefill) 
			client_print(id, print_chat, "[CSDM] Вы не можете использовать меню экипировки т.к. у вас уже есть оружие или возможность выбрать другое оружие отключена.");

		else if(g_WeaponStayTime > 5)
			client_print(id, print_chat, "[CSDM] Вы не можете использовать меню экипировки т.к. у вас уже есть оружие слишком длительное время");
	
	} else {
		g_MenuState[id] = 1;
		menu_display(id, g_EquipMenuID, 0);
	}

	return PLUGIN_HANDLED;
}

public checkmenu(param[])
{
	new id = param[0];

	if(!id)
	{
		if(task_exists(850 + id)) {
			remove_task(850 + id);
		}

		return PLUGIN_CONTINUE;
	}

	if(!is_user_connected(id))
	{
		if (task_exists(850 + id)) {
			remove_task(850 + id);
		}

		return PLUGIN_CONTINUE;
	}

	new oldmenuid, newmenuid;
	new bool:bEquipMenuDisp = false;

	player_menu_info(id, oldmenuid, newmenuid);

	if(newmenuid != -1 && (newmenuid == g_SecMenuID || newmenuid == g_PrimMenuID 
		|| newmenuid == g_ArmorMenuID || newmenuid == g_EquipMenuID))
	{
		bEquipMenuDisp = true;
	}

	if((oldmenuid <= 0) || (bEquipMenuDisp))
	{
		g_MenuState[id] = 1;
		menu_display(id, g_EquipMenuID, 0);

		if (task_exists(850+id))
			remove_task(850+id);

		if (task_exists(700+id))
			remove_task(700+id);
	}	

	return PLUGIN_CONTINUE;
}

public menu_delayed(param[])
{
	new id = param[0];

	if (!id)
	{
		if (task_exists(700 + id)) {
			remove_task(700 + id);
		}

		return PLUGIN_HANDLED;
	}

	if(!is_user_connected(id))
	{

		if (task_exists(850 + id)) {
			remove_task(850 + id);
		}

		return PLUGIN_HANDLED;
	}

	g_MenuState[id] = 1;
	menu_display(id, g_EquipMenuID, 0);

	if (task_exists(700 + id))
		remove_task(700 + id);

	if (task_exists(850 + id))
		remove_task(850 + id);

	return PLUGIN_CONTINUE;
}

stock getWeapId(wp[]) // this one is used, because get_weaponid doesn't work when csdm_CfgInit is called (something wrong with core intitialisation?
{
	if(equal(wp, "weapon_p228")) return CSW_P228;
	else if(equal(wp, "weapon_scout")) return CSW_SCOUT;
	else if(equal(wp, "weapon_hegrenade")) return CSW_HEGRENADE;
	else if(equal(wp, "weapon_xm1014")) return CSW_XM1014;
	else if(equal(wp, "weapon_c4")) return CSW_C4;
	else if(equal(wp, "weapon_mac10")) return CSW_MAC10;
	else if(equal(wp, "weapon_aug")) return CSW_AUG;
	else if(equal(wp, "weapon_smokegrenade")) return CSW_SMOKEGRENADE;
	else if(equal(wp, "weapon_elite")) return CSW_ELITE;
	else if(equal(wp, "weapon_fiveseven")) return CSW_FIVESEVEN;
	else if(equal(wp, "weapon_ump45")) return CSW_UMP45;
	else if(equal(wp, "weapon_sg550")) return CSW_SG550;
	else if(equal(wp, "weapon_galil")) return CSW_GALIL;
	else if(equal(wp, "weapon_famas")) return CSW_FAMAS;
	else if(equal(wp, "weapon_usp")) return CSW_USP;
	else if(equal(wp, "weapon_glock18")) return CSW_GLOCK18;
	else if(equal(wp, "weapon_awp")) return CSW_AWP;
	else if(equal(wp, "weapon_mp5navy")) return CSW_MP5NAVY;
	else if(equal(wp, "weapon_m249")) return CSW_M249;
	else if(equal(wp, "weapon_m3")) return CSW_M3;
	else if(equal(wp, "weapon_m4a1")) return CSW_M4A1;
	else if(equal(wp, "weapon_tmp")) return CSW_TMP;
	else if(equal(wp, "weapon_g3sg1")) return CSW_G3SG1;
	else if(equal(wp, "weapon_flashbang")) return CSW_FLASHBANG;
	else if(equal(wp, "weapon_deagle")) return CSW_DEAGLE;
	else if(equal(wp, "weapon_sg552")) return CSW_SG552;
	else if(equal(wp, "weapon_ak47")) return CSW_AK47;
	else if(equal(wp, "weapon_knife")) return CSW_KNIFE;
	else if(equal(wp, "weapon_p90")) return CSW_P90;

	return PLUGIN_CONTINUE;
}

// stuff for settings menu - START
public csdm_equip_sett_menu(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	menu_display(id, g_EquipSettMenu, 0);

	return PLUGIN_HANDLED;
}

public use_csdm_equip_menu(id, menu, item)
{
	if(item < 0)
		return PLUGIN_CONTINUE;

	new command[6], paccess, call;

	if(!menu_item_getinfo(g_EquipSettMenu, item, paccess, command, charsmax(command), _, _, call)) {
		log_amx("Error: csdm_menu_item() failed (menu %d) (page %d) (item %d)", g_EquipSettMenu, 0, item);
		return PLUGIN_HANDLED;
	}

	if(paccess && !(get_user_flags(id) & paccess)) {
		client_print(id, print_chat, "You do not have access to this menu option.");
		return PLUGIN_HANDLED;
	}

	new iChoice = str_to_num(command);

	switch(iChoice)
	{
		case 1:
		{
			g_mPrimStatus = g_mPrimStatus? false : true;

			client_print(id, print_chat, "Отображение меню первичного оружия %s.", g_mPrimStatus ? "Включено" : "Выключено");
			log_amx("CSDM displaying primary gun menu %s.", g_mPrimStatus ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_menus_settings(id);

			return PLUGIN_HANDLED;
		}
		case 2:
		{
			g_mSecStatus = g_mSecStatus? false : true;

			client_print(id, print_chat, "Отображение меню вторичного оружия %s.", g_mSecStatus ? "Включено" : "Выключено");
			log_amx("CSDM displaying secondary gun menu %s.", g_mSecStatus ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_menus_settings(id);

			return PLUGIN_HANDLED;
		}
		case 3:
		{
			g_mArmorStatus = g_mArmorStatus? false : true;

			if(g_mArmorStatus)
				g_mAutoArmor = false;

			client_print(id, print_chat, "Отображение меню брони %s.", g_mArmorStatus ? "Включено" : "Выключено");
			log_amx("CSDM displaying armor menu %s.", g_mArmorStatus ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_menus_settings(id);

			return PLUGIN_HANDLED;
		}
		case 4:
		{
			g_mNadeStatus = g_mNadeStatus? false : true;

			if(g_mNadeStatus)
				g_mAutoNades = false;

			client_print(id, print_chat, "Отображение меню гранат %s.", g_mNadeStatus ? "Включено" : "Выключено");
			log_amx("CSDM displaying nades menu %s.", g_mNadeStatus ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_menus_settings(id);

			return PLUGIN_HANDLED;
		}
		case 5:
		{
			if(g_Armor == 1 || g_Armor == 2) {
				g_Armor = 0;
				g_mAutoArmor = false;
			}
			else if(g_Armor == 0) {
				g_Armor = 1;
				g_mAutoArmor = true;
				g_mArmorStatus = false;
			}

			client_print(id, print_chat, "Авто выдача брони %s.", g_mAutoArmor ? "Включена" : "Выключена");
			log_amx("CSDM auto equiping players with armor %s.", g_mAutoArmor ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_autoequip_settings(id);

			return PLUGIN_HANDLED;
		}
		case 6:
		{
			if(g_Armor == 0 || g_Armor == 1) {
				g_Armor = 2;
				g_mAutoArmor = true;
				g_mArmorStatus = false;
			}
			else if(g_Armor == 2) {
				g_Armor = 1;
				g_mAutoArmor = true;
				g_mArmorStatus = false;
			}

			client_print(id, print_chat, "Авто выдача шлема %s.", (g_Armor == 2) ? "Включена" : "Выключена");
			log_amx("CSDM auto equiping players with helmet %s.", (g_Armor == 2) ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_autoequip_settings(id);

			return PLUGIN_HANDLED;
		}
		case 7:
		{
			g_mAutoNades = g_mAutoNades? false : true;

			if(g_mAutoNades)
				g_mNadeStatus = false;

			client_print(id, print_chat, "Авто выдача гранат %s.", g_mAutoNades ? "Включена" : "Выключена");
			log_amx("CSDM auto equiping players with grenades %s.", g_mAutoNades ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 0);
			write_autoequip_settings(id);

			return PLUGIN_HANDLED;
		}
		case 8:
		{
			g_DefuseKit = g_DefuseKit? false : true;

			client_print(id, print_chat, "Авто выдача щипцов (только спецназ) %s.", g_DefuseKit ? "Включена" : "Выключена");
			log_amx("CSDM auto equiping players with defuser (CTs) %s.", g_DefuseKit ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			write_autoequip_settings(id);

			return PLUGIN_HANDLED;
		}
		case 9:
		{
			g_NightVision = g_NightVision? false : true;

			client_print(id, print_chat, "Авто выдача ночного выденья %s.", g_NightVision ? "Включена" : "Выключена");
			log_amx("CSDM auto equiping players with nightvision %s.", g_NightVision ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			write_autoequip_settings(id);

			return PLUGIN_HANDLED;
		}
		case 10:
		{
			g_Flash = g_Flash? false : true;

			client_print(id, print_chat, "Использование световых гранат %s.", g_Flash ? "Включено" : "Выключено");
			log_amx("CSDM usage of flashbangs is %s.", g_Flash ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			write_nades_settings(id);

			return PLUGIN_HANDLED;
		}
		case 11:
		{
			g_Smoke = g_Smoke? false : true;

			client_print(id, print_chat, "Использование дымовых гранат %s.", g_Smoke ? "Включено" : "Выключено");
			log_amx("CSDM usage of smoke grenades is %s.", g_Smoke ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			write_nades_settings(id);

			return PLUGIN_HANDLED;
		}
		case 12:
		{
			g_Nade = g_Nade? false : true;

			client_print(id, print_chat, "Использование всех гранат %s.", g_Nade ? "Включено" : "Выключено");
			log_amx("CSDM usage of he nades is %s.", g_Nade ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			write_nades_settings(id);

			return PLUGIN_HANDLED;
		}
		case 13:
		{
			g_AlwaysAllowGunMenu = g_AlwaysAllowGunMenu? false : true;

			client_print(id, print_chat, "Использование меню экипировки всегда %s.", g_AlwaysAllowGunMenu ? "Включено" : "Выключено");
			log_amx("CSDM Always Allow Gun Menu is %s.", g_AlwaysAllowGunMenu ? "enabled" : "disabled");

			menu_display(id, g_EquipSettMenu, 1);
			csdm_write_cfg(id, "equip", "always_allow_gunmenu", g_AlwaysAllowGunMenu ? "1" : "0");

			return PLUGIN_HANDLED;
		}
		case 14:
		{
			menu_display(id, g_SettingsMenu, g_PageSettMenu);

			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_HANDLED;
}

public hook_equip_sett_display(player, menu, item)
{
	new paccess, command[24], call;

	menu_item_getinfo(menu, item, paccess, command, charsmax(command), _, _, call);

	if (equali(command, "1")) {
		if (g_mPrimStatus) menu_item_setname(menu, item, "Меню первичного оружия включено");
		else menu_item_setname(menu, item, "Меню первичного оружия выключено");
	} else if (equali(command, "2")) {
		if (g_mSecStatus) menu_item_setname(menu, item, "Меню вторичного оружия включено");
		else menu_item_setname(menu, item, "Меню вторичного оружия выключено");
	} else if (equali(command, "3")) {
		if (g_mArmorStatus) menu_item_setname(menu, item, "Меню брони включено");
		else menu_item_setname(menu, item, "Меню брони выключено");
	} else if (equali(command, "4")) {
		if (g_mNadeStatus) menu_item_setname(menu, item, "Equip Menu Grenades Enabled");
		else menu_item_setname(menu, item, "Equip Menu Grenades Disabled");
	} else if (equali(command, "5")) {
		if (g_mAutoArmor) menu_item_setname(menu, item, "Авто экипировка броней включена");
		else menu_item_setname(menu, item, "Авто экипировка броней выключена");
	} else if (equali(command, "6")) {
		if (g_mAutoArmor && g_Armor == 2) menu_item_setname(menu, item, "Авто экипировка шлемом включена");
		else menu_item_setname(menu, item, "Авто экипировка шлемом выключена");
	} else if (equali(command, "7")) {
		if (g_mAutoNades) menu_item_setname(menu, item, "Авто экипировка гранатами включена");
		else menu_item_setname(menu, item, "Авто экипировка гранатами включена");
	} else if (equali(command, "8")) {
		if (g_DefuseKit) menu_item_setname(menu, item, "Авто экипировка щипцами включена");
		else menu_item_setname(menu, item, "Авто экипировка щипцами включена");
	} else if (equali(command, "9")) {
		if (g_NightVision) menu_item_setname(menu, item, "Авто экипировка ночным виденьем включена");
		else menu_item_setname(menu, item, "Авто экипировка ночным виденьем включена");
	} else if (equali(command, "10")) {
		if (g_Flash) menu_item_setname(menu, item, "Световые гранаты включены");
		else menu_item_setname(menu, item, "Световые гранаты выключены");
	} else if (equali(command, "11")) {
		if (g_Smoke) menu_item_setname(menu, item, "Дымовые гранаты включены");
		else menu_item_setname(menu, item, "Дымовые гранаты выключены");
	} else if (equali(command, "12")) {
		if (g_Nade) menu_item_setname(menu, item, "Разрывные гранаты включены");
		else menu_item_setname(menu, item, "Разрывные гранаты выключены");
	} else if (equali(command, "13")) {
		if (g_AlwaysAllowGunMenu) menu_item_setname(menu, item, "Использование меню экипировки всегда, включено");
		else menu_item_setname(menu, item, "Использование меню экипировки всегда, выключено");
	}
}

public write_menus_settings(id)
{
	new flags[5] = "";
	new menu_flags = 0;

	if(g_mPrimStatus)
		menu_flags |= (1<<0);
	if(g_mSecStatus)
		menu_flags |= (1<<1);
	if(g_mArmorStatus)
		menu_flags |= (1<<2);
	if(g_mNadeStatus)
		menu_flags |= (1<<3);

	get_flags(menu_flags, flags, charsmax(flags));

	replace(flags, charsmax(flags), "a", "p");
	replace(flags, charsmax(flags), "b", "s");
	replace(flags, charsmax(flags), "c", "a");
	replace(flags, charsmax(flags), "d", "g");

	csdm_write_cfg(id, "equip", "menus", flags);
}

public write_autoequip_settings(id)
{
	new flags[6] = "";
	new auto_flags = 0;

	if(g_mAutoArmor)
		auto_flags |= (1<<0);
	if(g_mAutoArmor && g_Armor == 2)
		auto_flags |= (1<<1);
	if(g_mAutoNades)
		auto_flags |= (1<<2);
	if(g_DefuseKit)
		auto_flags |= (1<<3);
	if(g_NightVision)
		auto_flags |= (1<<4);

	get_flags(auto_flags, flags, charsmax(flags));

	// replace(flags, charsmax(flags), "a", "a");
	replace(flags, charsmax(flags), "b", "h");
	replace(flags, charsmax(flags), "c", "g");
	// replace(flags, charsmax(flags), "d", "d");
	replace(flags, charsmax(flags), "e", "n");

	csdm_write_cfg(id, "equip", "autoitems", flags);
}

public write_nades_settings(id)
{
	new flags[4] = "";
	new nade_flags = 0;

	if(g_Flash)
		nade_flags |= (1<<0);
	if(g_Nade)
		nade_flags |= (1<<1);
	if(g_Smoke)
		nade_flags |= (1<<2);

	get_flags(nade_flags, flags, charsmax(flags));

	replace(flags, charsmax(flags), "a", "f");
	replace(flags, charsmax(flags), "b", "h");
	replace(flags, charsmax(flags), "c", "s");

	csdm_write_cfg(id, "equip", "grenades", flags);
}
// stuff for settings menu - END