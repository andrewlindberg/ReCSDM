#include "precompiled.h"

cvar_t init_csdm_version = { "csdm_version", Plugin_info.version, FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_active = { "csdm_active", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_spec_menu_always = { "csdm_spec_menu_always", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_unlimited_team_changes = { "csdm_unlimited_team_changes", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_block_endround_force = { "csdm_block_endround_force", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_block_drop_weapon = { "csdm_block_drop_weapon", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t init_csdm_remove_weapon_dead = { "csdm_remove_weapon_dead", "1", FCVAR_SERVER | FCVAR_SPONLY };
cvar_t *csdm_active = NULL;
cvar_t *csdm_version = NULL;
cvar_t *csdm_spec_menu_always = NULL;
cvar_t *csdm_unlimited_team_changes = NULL;
cvar_t *csdm_block_endround_force = NULL;
cvar_t *csdm_block_drop_weapon = NULL;
cvar_t *csdm_remove_weapon_dead = NULL;
cvar_t *g_cvar_roundend = NULL;
cvar_t *g_cvar_freeforall = NULL;

FakeCommand g_FakeCmd;
float g_LastTime;
bool g_already_ran = false;
//bool m_api_rehlds = false;
bool m_api_regame = false;

void csdm_version_cmd()
{
	print_srvconsole("[CSDM] Version %s (C)2016 Adidasman & s1lent\n", Plugin_info.version);
}

bool OnMetaAttach()
{
	CVAR_REGISTER(&init_csdm_version);
	CVAR_REGISTER(&init_csdm_active);
	CVAR_REGISTER(&init_csdm_spec_menu_always);
	CVAR_REGISTER(&init_csdm_unlimited_team_changes);
	CVAR_REGISTER(&init_csdm_block_endround_force);
	CVAR_REGISTER(&init_csdm_block_drop_weapon);
	CVAR_REGISTER(&init_csdm_remove_weapon_dead);

	csdm_version = CVAR_GET_POINTER(init_csdm_version.name);
	csdm_active = CVAR_GET_POINTER(init_csdm_active.name);
	csdm_spec_menu_always = CVAR_GET_POINTER(init_csdm_spec_menu_always.name);
	csdm_unlimited_team_changes = CVAR_GET_POINTER(init_csdm_unlimited_team_changes.name);
	csdm_block_endround_force = CVAR_GET_POINTER(init_csdm_block_endround_force.name);
	csdm_block_drop_weapon = CVAR_GET_POINTER(init_csdm_block_drop_weapon.name);
	csdm_remove_weapon_dead = CVAR_GET_POINTER(init_csdm_remove_weapon_dead.name);

	g_LastTime = gpGlobals->time;

	REG_SVR_COMMAND("csdm", csdm_version_cmd);

	g_ReGameHookchains->InstallGameRules()->registerHook(&InstallGameRules);
	g_ReGameHookchains->CSGameRules_RestartRound()->registerHook(&CSGameRules_RestartRound);
	g_ReGameHookchains->CSGameRules_CheckWinConditions()->registerHook(&CSGameRules_CheckWinConditions);
	g_ReGameHookchains->CSGameRules_FPlayerCanRespawn()->registerHook(&CSGameRules_FPlayerCanRespawn);
	g_ReGameHookchains->CSGameRules_DeadPlayerWeapons()->registerHook(&CSGameRules_DeadPlayerWeapons);
	g_ReGameHookchains->CSGameRules_DeathNotice()->registerHook(&CSGameRules_DeathNotice);
	g_ReGameHookchains->CBasePlayer_Spawn()->registerHook(&CBasePlayer_Spawn);
	g_ReGameHookchains->CBasePlayer_Killed()->registerHook(&CBasePlayer_Killed);
	g_ReGameHookchains->CBasePlayer_DropPlayerItem()->registerHook(&CBasePlayer_DropPlayerItem);
	g_ReGameHookchains->HandleMenu_ChooseTeam()->registerHook(&HandleMenu_ChooseTeam);
	g_ReGameHookchains->HandleMenu_ChooseAppearance()->registerHook(&HandleMenu_ChooseAppearance);
	g_ReGameHookchains->ShowVGUIMenu()->registerHook(&ShowVGUIMenu);

	return true;
}

void OnMetaDetach()
{
	g_ReGameHookchains->InstallGameRules()->unregisterHook(&InstallGameRules);
	g_ReGameHookchains->CSGameRules_RestartRound()->unregisterHook(&CSGameRules_RestartRound);
	g_ReGameHookchains->CSGameRules_CheckWinConditions()->unregisterHook(&CSGameRules_CheckWinConditions);
	g_ReGameHookchains->CSGameRules_FPlayerCanRespawn()->unregisterHook(&CSGameRules_FPlayerCanRespawn);
	g_ReGameHookchains->CSGameRules_DeadPlayerWeapons()->unregisterHook(&CSGameRules_DeadPlayerWeapons);
	g_ReGameHookchains->CSGameRules_DeathNotice()->unregisterHook(&CSGameRules_DeathNotice);
	g_ReGameHookchains->CBasePlayer_Spawn()->unregisterHook(&CBasePlayer_Spawn);
	g_ReGameHookchains->CBasePlayer_Killed()->unregisterHook(&CBasePlayer_Killed);
	g_ReGameHookchains->CBasePlayer_DropPlayerItem()->unregisterHook(&CBasePlayer_DropPlayerItem);
	g_ReGameHookchains->HandleMenu_ChooseTeam()->unregisterHook(&HandleMenu_ChooseTeam);
	g_ReGameHookchains->HandleMenu_ChooseAppearance()->unregisterHook(&HandleMenu_ChooseAppearance);
	g_ReGameHookchains->ShowVGUIMenu()->unregisterHook(&ShowVGUIMenu);

	ClearAllTaskCaches();
}

void ServerActivate_Post(edict_t *pEdictList, int edictCount, int clientMax)
{
	g_cvar_roundend = CVAR_GET_POINTER("mp_round_infinite");
	SERVER_COMMAND("sv_restart 1\n");

	RETURN_META(MRES_IGNORED);
}

void ServerDeactivate_Post()
{
	g_Timer.Clear();
	g_Config.Clear();
	g_SpawnMngr.Clear();
	g_already_ran = false;

	RETURN_META(MRES_IGNORED);
}

void SetActive(bool active)
{
	if (active) {
		csdm_active->value = 1;
	} else {
		csdm_active->value = 0;
	}

	g_amxxapi.ExecuteForward(g_StateChange, (active) ? CSDM_ENABLE : CSDM_DISABLE);
}

int DispatchSpawn_Post(edict_t *pEdict)
{
	if (g_already_ran) {
		RETURN_META_VALUE(MRES_IGNORED, 0);
	}

	g_already_ran = true;

	g_LastTime = gpGlobals->time;

	ClearAllPlayers();

	g_amxxapi.ExecuteForward(g_InitFwd, Plugin_info.version);
	g_amxxapi.ExecuteForward(g_CfgInitFwd);

	char file[255];
	g_amxxapi.BuildPathnameR(file, sizeof(file)-1, "%s/csdm.cfg", LOCALINFO("amxx_configsdir"));

	if (g_Config.ReadConfig(file) != Config_Ok) {
		MF_Log("Could not read config file: %s", file);
	}

	if (IsActive())
	{
		if (csdm_block_endround_force->value == 1.0f) {
			CVAR_SET_FLOAT("mp_round_infinite", 1.0f);
		}

		CVAR_SET_FLOAT("mp_roundrespawn_time", 0.0f);
	}

	RETURN_META_VALUE(MRES_IGNORED, 0);
}

void StartFrame_Post()
{
	static float gbTime;

	gbTime = gpGlobals->time;

	if ((g_LastTime + 0.1) < gbTime && IsActive())
	{
		g_LastTime = gbTime;
		g_Timer.Tick(gbTime);
	}

	RETURN_META(MRES_IGNORED);
}

CGameRules *InstallGameRules(IReGameHook_InstallGameRules *chain)
{
	return g_pGameRules = chain->callNext();
}

void CSGameRules_RestartRound(IReGameHook_CSGameRules_RestartRound *chain)
{
	chain->callNext();

	if (!IsActive()) {
		return;
	}

	if (CSGameRules()->m_bCompleteReset) {
		Forward_RoundRestart();
	}
}

void CSGameRules_CheckWinConditions(IReGameHook_CSGameRules_CheckWinConditions *chain)
{
	if (!IsActive()) {
		chain->callNext();
		return;
	}

	if (csdm_block_endround_force->value == 1.0f
		&& g_cvar_roundend
		&& g_cvar_roundend->value != 1.0f)
	{
		CVAR_SET_FLOAT("mp_round_infinite", 1.0f);
	}

	chain->callNext();
}

int CSGameRules_DeadPlayerWeapons(IReGameHook_CSGameRules_DeadPlayerWeapons *chain, CBasePlayer *pPlayer)
{
	auto ret = chain->callNext(pPlayer);

	if (csdm_remove_weapon_dead->value != 1.0f || !IsActive()) {
		return ret;
	}

	return GR_PLR_DROP_GUN_NO;
}

void CBasePlayer_DropPlayerItem(IReGameHook_CBasePlayer_DropPlayerItem *chain, CBasePlayer *pPlayer, const char *pszItemName)
{
	//CSDM_PRINT_DEBUG("CBasePlayer_DropPlayerItem   [%s]  start", pszItemName);

	if (csdm_block_drop_weapon->value != 1.0f || !IsActive()) {
		chain->callNext(pPlayer, pszItemName);
		return;
	}

/*
    int type = 0;
	auto pInfo = g_ReGameApi->GetWeaponSlot(pszItemName);

	if (pInfo == nullptr)
	{
		//CSDM_PRINT_DEBUG("CBasePlayer_DropPlayerItem   pInfo == nullptr");
		return;
	}

	auto pItem = pPlayer->m_rgpPlayerItems[pInfo->slot];

	while (pItem != nullptr)
	{
		if (pItem->m_iId == pInfo->id)
		{
			pItem = pItem->m_pNext;
			continue;
		}

		pPlayer->pev->weapons &= ~(1 << pItem->m_iId);
		pPlayer->RemovePlayerItem(pItem);
		pItem->Kill();

		pItem = pItem->m_pNext;
	}
*/

	//CSDM_PRINT_DEBUG("CBasePlayer_DropPlayerItem   [%s]  end", pszItemName);
}

void CBasePlayer_Killed(IReGameHook_CBasePlayer_Killed *chain, CBasePlayer *pthis, entvars_t *pevAttacker, int iGib)
{
	chain->callNext(pthis, pevAttacker, iGib);

	if (!IsActive()) {
		return;
	}

	player_states *pPlayer = GET_PLAYER(pthis->entindex());

	if (!pPlayer->ingame
		|| pPlayer->spawning
		|| pPlayer->blockspawn
		|| (pthis->m_iTeam != TERRORIST && pthis->m_iTeam != CT))
	{
		return;
	}

	pPlayer->spawned = 1;

	RespawnPlayer(pthis->edict());
}

void CBasePlayer_Spawn(IReGameHook_CBasePlayer_Spawn *chain, CBasePlayer *pthis)
{
	chain->callNext(pthis);

	if (csdm_spec_menu_always->value == 1.0f) {
		pthis->pev->iuser3 |= (1 << 1);
	}

	if (!IsActive() || pthis->m_bJustConnected) {
		return;
	}

	edict_t *pEdict = pthis->edict();

	if (!pEdict
		|| pEdict->v.deadflag != DEAD_NO
		|| pEdict->v.flags & FL_SPECTATOR
		|| (pthis->m_iTeam != TERRORIST && pthis->m_iTeam != CT))
	{
		return;
	}

	player_states *pPlayer = GET_PLAYER(pthis->entindex());

	if (!pPlayer->spawning)
	{
		pPlayer->spawned = 1;

		FakespawnPlayer(pEdict, pthis->entindex());
	}
}

void CSGameRules_DeathNotice(IReGameHook_CSGameRules_DeathNotice *chain, CBasePlayer *pVictim, entvars_t *pKiller, entvars_t *pevInflictor)
{
	if (!IsActive()) {
		chain->callNext(pVictim, pKiller, pevInflictor);
		return;
	}

	const char *killer_weapon_name = "world";
	int killer_index = 0;
	int victim_index = ENTINDEX(pVictim->edict());;
	int Headshot = 0;

	if (pVictim->m_bHeadshotKilled) {
		Headshot = 1;
	}

	if (pKiller->flags & FL_CLIENT)
	{
		killer_index = ENTINDEX(ENT(pKiller));

		if (pevInflictor)
		{
			if (pevInflictor == pKiller)
			{
				CBasePlayer *pAttacker = CBasePlayer::Instance(pKiller);

				if (pAttacker && pAttacker->IsPlayer() && pAttacker->m_pActiveItem) {
					killer_weapon_name = STRING(pAttacker->m_pActiveItem->pev->classname);
				}
			} else {
				killer_weapon_name = STRING(pevInflictor->classname);
			}
		}
	}
	else
	{
		if (pevInflictor) {
			killer_weapon_name = STRING(pevInflictor->classname);
		}
	}

	const char cut_weapon[] = "weapon_";
	const char cut_monster[] = "monster_";
	const char cut_func[] = "func_";

	if (!strncmp(killer_weapon_name, cut_weapon, sizeof(cut_weapon)-1))
	{
		killer_weapon_name += sizeof(cut_weapon)-1;
	}
	else if (!strncmp(killer_weapon_name, cut_monster, sizeof(cut_monster)-1))
	{
		killer_weapon_name += sizeof(cut_monster)-1;
	}
	else if (!strncmp(killer_weapon_name, cut_func, sizeof(cut_func)-1))
	{
		killer_weapon_name += sizeof(cut_func)-1;
	}

	if (pVictim->m_iTeam == TERRORIST || pVictim->m_iTeam == CT)
	{
		DeathForward(killer_index, victim_index, Headshot, killer_weapon_name, false);

		chain->callNext(pVictim, pKiller, pevInflictor);

		DeathForward(killer_index, victim_index, Headshot, killer_weapon_name, true);

		return;
	}

	chain->callNext(pVictim, pKiller, pevInflictor);
}

BOOL HandleMenu_ChooseTeam(IReGameHook_HandleMenu_ChooseTeam *chain, CBasePlayer *player, int slot)
{
	if (csdm_spec_menu_always->value == 1.0f) {
		g_pGameRules->m_bFreezePeriod = TRUE;
	}

	auto ret = chain->callNext(player, slot);

	if (csdm_spec_menu_always->value == 1.0f) {
		g_pGameRules->m_bFreezePeriod = FALSE;
	}

	if (csdm_unlimited_team_changes->value == 1.0f) {
		player->m_bTeamChanged = false;
	}

	if (!IsActive()) {
		return ret;
	}

	player_states *pPlayer = GET_PLAYER(player->entindex());

	if (!pPlayer->ingame) {
		return ret;
	}

	if (player->m_iTeam == SPECTATOR) {
		pPlayer->spawning = false;
		pPlayer->spawned = 0;
	}

	pPlayer->blockspawn = true;
	
	return ret;
}

void HandleMenu_ChooseAppearance(IReGameHook_HandleMenu_ChooseAppearance *chain, CBasePlayer *player, int slot)
{
	chain->callNext(player, slot);

	if (!IsActive()) {
		return;
	}

	player_states *pPlayer = GET_PLAYER(player->entindex());

	if (!pPlayer->ingame) {
		return;
	}

	pPlayer->blockspawn = false;

	if (!player->IsAlive())
	{
		pPlayer->spawned = 0;
		pPlayer->spawning = false;

		RespawnPlayer(player->edict());
	}
}

int CSGameRules_FPlayerCanRespawn(IReGameHook_CSGameRules_FPlayerCanRespawn *chain, class CBasePlayer *pPlayer)
{
	auto ret = chain->callNext(pPlayer);

	if (!IsActive()) {
		return ret;
	}

	// Player cannot respawn while in the Choose Appearance menu
	if (pPlayer->m_iMenu == Menu_ChooseAppearance) {
		return FALSE;
	}

	player_states *ePlayer = GET_PLAYER(pPlayer->entindex());

	if (!ePlayer->ingame || ePlayer->spawning || ePlayer->blockspawn) {
		return FALSE;
	}

	return TRUE;
}

void ShowVGUIMenu(IReGameHook_ShowVGUIMenu *chain, CBasePlayer *pPlayer, int MenuType, int BitMask, char *szOldMenu)
{
	if (csdm_spec_menu_always->value == 1.0f && !strcmp(szOldMenu, "#IG_Team_Select"))
	{
		chain->callNext(pPlayer, MenuType, BitMask | MENU_KEY_6, "#IG_Team_Select_Spect");
		return;
	}

	chain->callNext(pPlayer, MenuType, BitMask, szOldMenu);
}

void ClientPutInServer(edict_t *pEdict)
{
	player_states *pPlayer = GET_PLAYER(ENTINDEX(pEdict));

	pPlayer->ingame = true;

	if (g_IntroMsg && IsActive())
	{
		Welcome *pWelcome = new Welcome(pEdict);
		g_Timer.AddTask(pWelcome, 10.0);
	}

	RETURN_META(MRES_IGNORED);
}

void ClientDisconnect(edict_t *pEdict)
{
	ClearPlayer(ENTINDEX(pEdict));

	RETURN_META(MRES_IGNORED);
}

void ClientUserInfoChanged(edict_t *pEntity, char *infobuffer)
{
	player_states *pPlayer = GET_PLAYER(ENTINDEX(pEntity));

	if (!pPlayer->ingame && pEntity && pEntity->v.flags & FL_FAKECLIENT) {
		pPlayer->ingame = true;
	}

	RETURN_META(MRES_IGNORED);
}

BOOL ClientConnect(edict_t *pEntity, const char *pszName, const char *pszAddress, char szRejectReason[128])
{
	player_states *pPlayer = GET_PLAYER(ENTINDEX(pEntity));

	if (pEntity && pEntity->v.flags & FL_FAKECLIENT) {
		pPlayer->ingame = true;
	} else {
		pPlayer->ingame = false;
	}

	pPlayer->blockspawn = false;
	pPlayer->spawning = false;
	pPlayer->spawned = 0;

	RETURN_META_VALUE(MRES_IGNORED, true);
}

const char *Cmd_Args()
{
	if (g_FakeCmd.GetArgc()) {
		RETURN_META_VALUE(MRES_SUPERCEDE, g_FakeCmd.GetFullString());
	}

	RETURN_META_VALUE(MRES_IGNORED, NULL);
}

const char *Cmd_Argv(int argc)
{
	if (g_FakeCmd.GetArgc()) {
		RETURN_META_VALUE(MRES_SUPERCEDE, g_FakeCmd.GetArg(argc));
	}

	RETURN_META_VALUE(MRES_IGNORED, NULL);
}

int Cmd_Argc(void)
{
	if (g_FakeCmd.GetArgc()) {
		RETURN_META_VALUE(MRES_SUPERCEDE, g_FakeCmd.GetArgc());
	}

	RETURN_META_VALUE(MRES_IGNORED, 0);
}
