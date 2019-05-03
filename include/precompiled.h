#pragma once

#ifdef __linux__
	#define _vsnprintf vsnprintf
#endif

#include <extdll.h>
#include <meta_api.h>

#include "amxxmodule.h"
#include "osconfig.h"

#include "cbase.h"
#include "gamerules.h"
#include "entity_state.h"
#include "client.h"

#include "regamedll_api.h"
#include "gamedll_api.h"
#include "rehlds_api.h"

#include "CString.h"
#include "CVector.h"
#include "sh_list.h"
#include "sh_stack.h"
#include "util.h"

#include "csdm_util.h"
#include "csdm_amxx.h"
#include "csdm_config.h"
#include "csdm_spawning.h"
#include "csdm_player.h"
#include "csdm_timer.h"
#include "csdm_tasks.h"

#undef C_DLLEXPORT

#ifdef _WIN32
	#define C_DLLEXPORT extern "C" __declspec(dllexport)
#else
	#include <sys/mman.h>
	#define C_DLLEXPORT extern "C" __attribute__((visibility("default")))
#endif
