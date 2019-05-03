#ifndef _INCLUDE_CSDM_AMXX_H
#define _INCLUDE_CSDM_AMXX_H

#define CSDM_FFA_ENABLE		3
#define CSDM_FFA_DISABLE	2
#define CSDM_ENABLE			1
#define CSDM_DISABLE		0
#define EntityPevOffset     4

extern int g_PreDeath;
extern int g_PostDeath;
extern int g_SpawnMethod;
extern int g_PreSpawn;
extern int g_PostSpawn;
extern int g_RoundRestart;
extern int g_StateChange;
extern int g_InitFwd;
extern int g_CfgInitFwd;
extern int g_IntroMsg;
extern int g_RemoveWeapon;
extern float g_SpawnWaitTime;
extern bool g_load_okay;
extern cvar_t *csdm_active;
extern cvar_t *csdm_spec_menu_always;
extern cvar_t *csdm_unlimited_team_changes;
extern cvar_t *csdm_block_endround_force;
extern cvar_t *csdm_block_drop_weapon;
extern cvar_t *csdm_remove_weapon_dead;
extern cvar_t *g_cvar_roundend;
extern cvar_t *g_cvar_freeforall;
extern AMX_NATIVE_INFO g_CsdmNatives[];
extern void CSDM_PRINT(const char *fmt, ...);
extern void CSDM_PRINT_DEBUG(const char *fmt, ...);
extern void Forward_RoundRestart();
extern void Forward_Respawn_All_Player();
extern bool OnMetaAttach();
extern void OnMetaDetach();
extern void DeathForward(int pk, int pv, int hs, const char *wp, bool post);
extern void SpawnForward(int pk, bool fake);
extern void SetActive(bool active);

//bool m_api_rehlds = false;

extern bool m_api_regame;

inline bool IsActive()
{
	return ((int)csdm_active->value != 0);
}

#endif //_INCLUDE_CSDM_AMXX_H
