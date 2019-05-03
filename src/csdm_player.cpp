#include "precompiled.h"

player_states Players[33];
player_states *g_player = NULL;

void ClearAllPlayers()
{
	for (int i = 1; i <= gpGlobals->maxClients; i++) {
		ClearPlayer(i);
	}
}

void ClearPlayer(int index)
{
	player_states *pPlayer = GET_PLAYER(index);
	pPlayer->ingame = false;
	pPlayer->spawning = false;
	pPlayer->blockspawn = false;
	pPlayer->spawned = 0;
}
