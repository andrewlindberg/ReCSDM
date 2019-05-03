#include "precompiled.h"

int g_PreDeath = -1;
int g_PostDeath = -1;
int g_PreSpawn = -1;
int g_PostSpawn = -1;
int g_RoundRestart = -1;
int g_StateChange = -1;
int g_CfgInitFwd = -1;
int g_IntroMsg = 0;
int g_RemoveWeapon = -1;
int g_InitFwd = -1;
float g_SpawnWaitTime = 0.7;

void DeathForward(int pk, int pv, int hs, const char *wp, bool post)
{
	if (!post)
	{
		//we're not post.  let the plugins know he's just died. 
		//we also don't care about the return value
		if (g_PreDeath >= 0) {
			g_amxxapi.ExecuteForward(g_PreDeath, (cell)pk, (cell)pv, (cell)hs, wp);
		}
	}
	else
	{
		//we're post.  death has been settled.
		bool spawn = true;

		if (g_PostDeath >= 0)
		{
			if (g_amxxapi.ExecuteForward(g_PostDeath, (cell)pk, (cell)pv, (cell)hs, wp) > 0) {
				spawn = false;
			}
		}

		if (spawn) {
			RespawnPlayer(g_amxxapi.GetPlayerEdict(pv));
		}
	}
}

void SpawnForward(int pk, bool fake)
{
	if (g_SpawnMethod != -1)
	{
		SpawnMethod *pSpawn = g_SpawnMngr.GetSpawn(g_SpawnMethod);

		if (pSpawn) {
			pSpawn->Spawn(pk, fake ? 1 : 0);
		}
	}

	if (g_PostSpawn >= 0) {
		g_amxxapi.ExecuteForward(g_PostSpawn, (cell)pk, (cell)(fake ? 1 : 0));
	}
}

void OnAmxxAttach()
{
	if (m_api_regame == true) {
		g_amxxapi.AddNatives(g_CsdmNatives);
	}
}

void OnAmxxDetach() { }

void OnPluginsLoaded()
{
	if (m_api_regame == false) {
		return;
	}

	g_PreDeath = g_amxxapi.RegisterForward("csdm_PreDeath", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_DONE);
	g_PostDeath = g_amxxapi.RegisterForward("csdm_PostDeath", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_DONE);
	g_PreSpawn = g_amxxapi.RegisterForward("csdm_PreSpawn", ET_STOP, FP_CELL, FP_CELL, FP_DONE);
	g_PostSpawn = g_amxxapi.RegisterForward("csdm_PostSpawn", ET_STOP, FP_CELL, FP_CELL, FP_DONE);
	g_RoundRestart = g_amxxapi.RegisterForward("csdm_RoundRestart", ET_IGNORE, FP_CELL, FP_DONE);
	g_StateChange = g_amxxapi.RegisterForward("csdm_StateChange", ET_IGNORE, FP_CELL, FP_DONE);
	g_InitFwd = g_amxxapi.RegisterForward("csdm_Init", ET_IGNORE, FP_STRING, FP_DONE);
	g_CfgInitFwd = g_amxxapi.RegisterForward("csdm_CfgInit", ET_IGNORE, FP_DONE);
	g_RemoveWeapon = g_amxxapi.RegisterForward("csdm_RemoveWeapon", ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_DONE);
}

void OnPluginsUnloaded()
{
	g_SpawnMethod = -1;
}

extern "C" void __cxa_pure_virtual(void) { }

void CSDM_PRINT(const char *fmt, ...)
{
	va_list ap;
	uint32 len;
	char buf[1048];

	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);

	len = strlen(buf);

	if (len < sizeof(buf) - 2) {
		strcat(buf, "\n");
	} else {
		buf[len - 1] = '\n';
	}

	SERVER_PRINT(buf);
}

void CSDM_PRINT_DEBUG(const char *fmt, ...)
{
	va_list ap;
	uint32 len;
	char buf[1048];

	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);

	len = strlen(buf);

	if (len < sizeof(buf) - 2) {
		strcat(buf, "\n");
	} else {
		buf[len - 1] = '\n';
	}

	SERVER_PRINT(buf);
}
