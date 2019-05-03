#include "precompiled.h"

static int g_TextMsg = 0;
float g_last_ff_set = 0.0f;

void FFA_Disable()
{
	CVAR_SET_FLOAT("mp_friendlyfire", g_last_ff_set);
	CVAR_SET_STRING("mp_freeforall", "0");

	g_amxxapi.ExecuteForward(g_StateChange, CSDM_FFA_DISABLE);
}

void FFA_Enable()
{
	g_last_ff_set = CVAR_GET_FLOAT("mp_friendlyfire");

	CVAR_SET_FLOAT("mp_friendlyfire", 1.0f);
	CVAR_SET_STRING("mp_freeforall", "1");

	g_amxxapi.ExecuteForward(g_StateChange, CSDM_FFA_ENABLE);
}

void InternalSpawnPlayer(edict_t *pEdict)
{
	CBasePlayer *pPlayer = (CBasePlayer *)pEdict->pvPrivateData;

	if (pPlayer)
	{
		pEdict->v.deadflag = DEAD_RESPAWNABLE;
		pEdict->v.flags |= FL_FROZEN;

		pPlayer->RoundRespawn();
	}
}

FakeCommand::~FakeCommand()
{
	Clear();
}

void FakeCommand::Reset()
{
	num_args = 0;
}

int FakeCommand::GetArgc() const
{
	return num_args;
}

void FakeCommand::SetFullString(const char *fmt, ...)
{
	char buffer[1024];
	va_list ap;

	va_start(ap, fmt);
	vsnprintf(buffer, sizeof(buffer)-1, fmt, ap);
	va_end(ap);

	full.assign(buffer);
}

const char *FakeCommand::GetFullString() const
{
	return full.c_str();
}

const char *FakeCommand::GetArg(int i) const
{
	if (i < 0 || i > GetArgc()) {
		return "";
	}

	return args[i]->c_str();
}

void FakeCommand::Clear()
{
	Reset();

	for (unsigned int i = 0; i < args.size(); i++)
	{
		delete args[i];
		args[i] = NULL;
	}

	args.clear();
}

void FakeCommand::AddArg(const char *str)
{
	num_args++;

	if (num_args > args.size()) {
		String *pString = new String(str);
		args.push_back(pString);
	} else {
		args[num_args - 1]->assign(str);
	}
}

void RespawnPlayer(edict_t *pEdict)
{
	Respawn *pRespawn;
	int send;

	if (g_PreSpawn == -1) {
		send = -2;
	} else {
		send = g_PreSpawn;
	}

	player_states *pPlayer = GET_PLAYER(ENTINDEX(pEdict));

	//player is already respawning!
	if (pPlayer->spawning) {
		return;
	}
	
	pPlayer->spawning = true;

	pRespawn = Respawn::NewRespawn(pEdict, send);

	g_Timer.AddTask(pRespawn, g_SpawnWaitTime);
}

void FakespawnPlayer(edict_t *pEdict, int index)
{
	player_states *pPlayer = GET_PLAYER(index);

	if (pPlayer->spawning) {
		return;
	}

	pPlayer->spawning = true;

	if (g_PreSpawn > 0 && g_amxxapi.ExecuteForward(g_PreSpawn, (cell)index, (cell)1) > 0)
	{
		pPlayer->spawning = false;

		return;
	}

	SpawnForward(index, true);

	pPlayer->spawning = false;
}

edict_t *GetEdict(int index)
{
	if (index < 1 || index > gpGlobals->maxClients) {
		return NULL;
	}

	edict_t *pEdict = g_amxxapi.GetPlayerEdict(index);

	if (!pEdict) {
		return NULL;
	}

	if (pEdict->v.flags & FL_FAKECLIENT)
	{
		player_states *pPlayer = GET_PLAYER(index);

		pPlayer->ingame = true;

		return pEdict;
	}

	if (pEdict->v.flags & FL_CLIENT) {
		return pEdict;
	}

	return NULL;
}

void print_srvconsole( const char *fmt, ...)
{
	va_list argptr;
	static char string[384];

	va_start(argptr, fmt);
	vsnprintf(string, sizeof(string) - 1, fmt, argptr);
	string[sizeof(string) - 1] = '\0';
	va_end(argptr);

	SERVER_PRINT(string);
}

void print_client(edict_t *pEdict, int type, const char *fmt, ...)
{
	//don't do this to bots
	if (pEdict->v.flags & FL_FAKECLIENT) {
		return;
	}

	char buffer[255];
	va_list ap;

	va_start(ap, fmt);
	vsnprintf(buffer, sizeof(buffer)-1, fmt, ap);
	va_end(ap);

	if (!g_TextMsg)
	{
		g_TextMsg = GET_USER_MSG_ID(PLID, "TextMsg", NULL);

		if (!g_TextMsg) {
			return;
		}
	}

	MESSAGE_BEGIN(pEdict ? MSG_ONE : MSG_BROADCAST, g_TextMsg, NULL, pEdict);
		WRITE_BYTE(type);
		WRITE_STRING(buffer);
	MESSAGE_END();
}

bool NotifyForRemove(unsigned int owner, edict_t *ent, edict_t *box)
{
	cell idx1 = (cell)ENTINDEX(ent);
	cell idx2 = box ? (cell)ENTINDEX(box) : 0;

	return (g_amxxapi.ExecuteForward(g_RemoveWeapon, (cell)owner, idx1, idx2) == 0);
}
