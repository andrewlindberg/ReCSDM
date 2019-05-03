/*
 * csdm_stop_respawn.sma
 * Allows for Counter-Strike to be played as DeathMatch.
 *
 * CDSM Stop Respawn - Plugin to let You join spectators 
 * if You don't wish to be respawned
 *
 * (C)2003-2006 David "BAILOPAN" Anderson
 * (C)2003-2006 teame06
 * Give credit where due.
 * Share the source - it sets you free
 * [url]http://www.opensource.org/[/url]
 * [url]http://www.gnu.org/[/url]
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

#pragma semicolon 1

new bool:g_StopRespawn[CSDM_MAXPLAYERS + 1];

public csdm_Init(const version[])
{
	if (version[0] == 0) {
		set_fail_state("ReCSDM failed to load.");
		return;
	}
}

public plugin_init()
{
	register_plugin("ReCDSM Stop Respawn", "1.0", "teame06");
	register_clcmd("amx_respawn", "restore_respawn", ADMIN_LEVEL_G, "Остановить/Восстановить Возрождения");
}

public csdm_PostDeath(killer, victim, headshot, const weapon[])
{
	if(g_StopRespawn[victim]) {
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public restore_respawn(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	new teamid = _:cs_get_user_team(id);

	switch(teamid)
	{
		case _TEAM_T, _TEAM_CT:
		{
			if(g_StopRespawn[id]) {
				g_StopRespawn[id] = false;
				csdm_respawn(id);
				console_print(id, "Возрождения восстановлены");

			} else {
				g_StopRespawn[id] = true;
				user_silentkill(id);
				console_print(id, "Возрождения остановлены");
			}

			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public client_connect(id)
{
	g_StopRespawn[id] = false;
}