#ifndef _INCLUDE_CSDM_PLAYER_H
#define _INCLUDE_CSDM_PLAYER_H

#define	GET_PLAYER(id)	(&Players[ (id) ])

struct player_states {
	bool ingame;
	bool spawning;
	bool blockspawn;
	int spawned;
};

extern player_states Players[33];
extern void ClearAllPlayers();
extern void ClearPlayer(int index);

#if defined __linux__
	#define EXTRAOFFSET_WEAPONS		4	// weapon offsets are obviously only 4 steps higher on Linux!
#else
	#define EXTRAOFFSET_WEAPONS		0
#endif // defined __linux__

#endif //_INCLUDE_CSDM_PLAYER_H
