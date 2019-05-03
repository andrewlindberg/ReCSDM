#ifndef _REGAMEDLL_API_H_
#define _REGAMEDLL_API_H_

#pragma once

extern IReGameApi *g_ReGameApi;
extern const ReGameFuncs_t *g_ReGameFuncs;
extern IReGameHookchains *g_ReGameHookchains;
extern CGameRules *g_pGameRules;
extern bool RegamedllApi_Init();


extern CGameRules *InstallGameRules(IReGameHook_InstallGameRules *chain);
extern void CSGameRules_RestartRound(IReGameHook_CSGameRules_RestartRound *chain);
extern void CSGameRules_DeathNotice(IReGameHook_CSGameRules_DeathNotice *chain, CBasePlayer *pVictim, entvars_t *pKiller, entvars_t *pevInflictor);
extern void CSGameRules_CheckWinConditions(IReGameHook_CSGameRules_CheckWinConditions *chain);
extern int CSGameRules_DeadPlayerWeapons(IReGameHook_CSGameRules_DeadPlayerWeapons *chain, CBasePlayer *pPlayer);
extern int CSGameRules_FPlayerCanRespawn(IReGameHook_CSGameRules_FPlayerCanRespawn *chain, class CBasePlayer *pPlayer);
extern void CBasePlayer_Killed(IReGameHook_CBasePlayer_Killed *chain, CBasePlayer *pthis, entvars_t *pevAttacker, int iGib);
extern void CBasePlayer_Spawn(IReGameHook_CBasePlayer_Spawn *chain, CBasePlayer *pthis);
extern void CBasePlayer_DropPlayerItem(IReGameHook_CBasePlayer_DropPlayerItem *chain, CBasePlayer *pPlayer, const char *pszItemName);
extern void HandleMenu_ChooseAppearance(IReGameHook_HandleMenu_ChooseAppearance *chain, CBasePlayer *player, int slot);
extern BOOL HandleMenu_ChooseTeam(IReGameHook_HandleMenu_ChooseTeam *chain, CBasePlayer *player, int slot);
extern void ShowVGUIMenu(IReGameHook_ShowVGUIMenu *chain, CBasePlayer *pPlayer, int MenuType, int BitMask, char *szOldMenu);


#endif //_REGAMEDLL_API_H_
