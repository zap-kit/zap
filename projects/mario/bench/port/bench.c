// Benchmark harness for comparing this PC port with the Zap rewrite (apps/mario).
// Driven by environment variables, off unless BENCH_FRAMES is set:
//   BENCH_FRAMES=N      stop N frames after Mario can first move; print the measures
//   BENCH_UNCAPPED=1    no frame limiter, no vsync: one game tick and one render per frame, as fast as it goes
//   BENCH_WALK=1        the stick held up, A held for 10 frames every 40 (the Zap version's --walk)
//   BENCH_EYE=x,y,z BENCH_FOCUS=x,y,z   a fixed camera
//   BENCH_SHOT=file.bmp the last frame saved
//   BENCH_TRACE=1       Mario's state (place, speeds, facing, action, timers, animation) and the camera's
//                       (its yaw, Lakitu's goal and drawn place and focus, its mode) after every tick
#define PSAPI_VERSION 2
#include <windows.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define GLEW_STATIC
#include <GL/glew.h>

#include <ultra64.h>
#include "sm64.h"
#include "types.h"
#include "game/level_update.h"
#include "pc/configfile.h"
#include "level_table.h"
#include "game/object_list_processor.h"
#include "game/area.h"
#include "engine/graph_node.h"
#include "game/camera.h"

extern struct MarioState *gMarioState;
extern s16 gCurrLevelNum;

static int sOn, sFrames, sUncapped, sWalk, sHasCamera, sTrace;
static float sEye[3], sFocus[3];
static const char *sShot;
static int sFrame, sPlayStart = -1;
static LARGE_INTEGER sStart, sFreq;
static FILE *sLog;
static FILETIME sCpuKernel, sCpuUser;
static ULONG64 sCycles;

static void read3(const char *name, float *out, int *ok) {
    const char *s = getenv(name);
    if (s && sscanf(s, "%f,%f,%f", &out[0], &out[1], &out[2]) == 3) {
        *ok = 1;
    }
}

void bench_init(void) {
    const char *f = getenv("BENCH_FRAMES");
    sOn = f != NULL;
    sFrames = f ? atoi(f) : 0;
    sUncapped = getenv("BENCH_UNCAPPED") != NULL;
    sWalk = getenv("BENCH_WALK") != NULL;
    sTrace = getenv("BENCH_TRACE") != NULL;
    int eye = 0, focus = 0;
    read3("BENCH_EYE", sEye, &eye);
    read3("BENCH_FOCUS", sFocus, &focus);
    sHasCamera = eye && focus;
    sShot = getenv("BENCH_SHOT");
    QueryPerformanceFrequency(&sFreq);
    const char *out = getenv("BENCH_OUT");
    sLog = out ? fopen(out, "w") : stdout;
}

int bench_uncapped(void) {
    return sOn && sUncapped;
}

// the frames counted from when Mario can first move (-1 before)
static int play_frame(void) {
    return sPlayStart < 0 ? -1 : sFrame - sPlayStart;
}

void bench_controller(OSContPad *pad) {
    if (!sOn || !sWalk || play_frame() < 0) {
        return;
    }
    int t = play_frame();
    pad->stick_x = 0;
    pad->stick_y = 80;
    if (t % 40 < 10) {
        pad->button |= A_BUTTON;
    }
}

int bench_camera(float *pos, float *focus) {
    if (!sOn || !sHasCamera) {
        return 0;
    }
    memcpy(pos, sEye, sizeof(sEye));
    memcpy(focus, sFocus, sizeof(sFocus));
    return 1;
}

static double filetime_seconds(FILETIME t) {
    ULARGE_INTEGER u;
    u.LowPart = t.dwLowDateTime;
    u.HighPart = t.dwHighDateTime;
    return u.QuadPart / 1e7;
}

static void save_shot(const char *path) {
    GLint vp[4];
    glGetIntegerv(GL_VIEWPORT, vp);
    int w = vp[2], h = vp[3];
    unsigned char *px = malloc((size_t)w * h * 3);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadBuffer(GL_BACK);
    glReadPixels(0, 0, w, h, GL_BGR, GL_UNSIGNED_BYTE, px);
    FILE *out = fopen(path, "wb");
    if (!out) {
        free(px);
        return;
    }
    int row = (w * 3 + 3) & ~3;
    unsigned int size = 54 + row * h;
    unsigned char header[54] = { 'B', 'M' };
    memcpy(header + 2, &size, 4);
    header[10] = 54;
    header[14] = 40;
    memcpy(header + 18, &w, 4);
    memcpy(header + 22, &h, 4);
    header[26] = 1;
    header[28] = 24;
    fwrite(header, 1, 54, out);
    unsigned char pad[3] = { 0, 0, 0 };
    for (int y = 0; y < h; y++) {
        fwrite(px + (size_t)y * w * 3, 1, w * 3, out);
        fwrite(pad, 1, row - w * 3, out);
    }
    fclose(out);
    free(px);
}

// after the frame is drawn, before it is shown
void bench_frame_drawn(void) {
    if (!sOn) {
        return;
    }
    sFrame++;
    if (sFrame % 60 == 0) {
        fprintf(sLog, "frame %d level %d action 0x%08X play %d\n", sFrame, gCurrLevelNum, gMarioState->action, play_frame());
        fflush(sLog);
    }
    if (sPlayStart < 0 && gCurrLevelNum == LEVEL_CASTLE_GROUNDS && gMarioState->marioObj != NULL && gMarioState->action != ACT_UNINITIALIZED) {
        sPlayStart = sFrame;
    }
    // BENCH_TRACE: Mario's state after each tick, to set beside the rewrite's --trace
    if (sTrace && play_frame() >= 0) {
        struct MarioState *m = gMarioState;
        struct Camera *c = m->area->camera;
        fprintf(sLog, "tick %d pos %.2f %.2f %.2f forward %.2f yaw %d action 0x%08X camera %d", play_frame(), m->pos[0], m->pos[1], m->pos[2],
                m->forwardVel, (int)m->faceAngle[1], m->action, (int)c->yaw);
        fprintf(sLog, " vel %.2f %.2f %.2f pitch %d water %d timer %d state %d floor %.2f", m->vel[0], m->vel[1], m->vel[2], (int)m->faceAngle[0],
                (int)m->waterLevel, (int)m->actionTimer, (int)m->actionState, m->floorHeight);
        fprintf(sLog, " goal %.2f %.2f %.2f gfocus %.2f %.2f %.2f lpos %.2f %.2f %.2f lfocus %.2f %.2f %.2f mode %d nextyaw %d anim %d %d\n", gLakituState.goalPos[0],
                gLakituState.goalPos[1], gLakituState.goalPos[2], gLakituState.goalFocus[0], gLakituState.goalFocus[1], gLakituState.goalFocus[2],
                gLakituState.pos[0], gLakituState.pos[1], gLakituState.pos[2], gLakituState.focus[0], gLakituState.focus[1], gLakituState.focus[2],
                (int)c->mode, (int)c->nextYaw, (int)m->marioObj->header.gfx.unk38.animID, (int)m->marioObj->header.gfx.unk38.animFrame);
    }
    // measured after a warm-up of 60 frames (shaders compiled on first use), as the Zap version does
    if (play_frame() == 60) {
        QueryPerformanceCounter(&sStart);
        FILETIME a, b;
        GetProcessTimes(GetCurrentProcess(), &a, &b, &sCpuKernel, &sCpuUser);
        QueryProcessCycleTime(GetCurrentProcess(), &sCycles);
    }
    if (play_frame() != sFrames + 60) {
        return;
    }
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    double seconds = (double)(now.QuadPart - sStart.QuadPart) / sFreq.QuadPart;
    FILETIME a, b, kernel, user;
    GetProcessTimes(GetCurrentProcess(), &a, &b, &kernel, &user);
    double cpu = filetime_seconds(kernel) - filetime_seconds(sCpuKernel) + filetime_seconds(user) - filetime_seconds(sCpuUser);
    ULONG64 cycles = 0;
    QueryProcessCycleTime(GetCurrentProcess(), &cycles);
    PROCESS_MEMORY_COUNTERS_EX mem;
    mem.cb = sizeof(mem);
    GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS *)&mem, sizeof(mem));
    if (sShot) {
        save_shot(sShot);
    }
    fprintf(sLog, "bench: %d frames in %.3f s = %.1f fps, %.3f ms a frame\n", sFrames, seconds, sFrames / seconds, seconds * 1000.0 / sFrames);
    fprintf(sLog, "bench: cpu %.3f s (%.3f ms a frame, %.2f cores)\n", cpu, cpu * 1000.0 / sFrames, cpu / seconds);
    fprintf(sLog, "bench: cycles %llu a frame\n", (cycles - sCycles) / sFrames);
    fprintf(sLog, "bench: memory peak %.1f MB, private %.1f MB\n", mem.PeakWorkingSetSize / 1048576.0, mem.PrivateUsage / 1048576.0);
    fprintf(sLog, "bench: mario at %.1f %.1f %.1f yaw %d action 0x%08X forward %.2f\n", gMarioState->pos[0], gMarioState->pos[1], gMarioState->pos[2],
           (int)gMarioState->faceAngle[1], gMarioState->action, gMarioState->forwardVel);
    fprintf(sLog, "bench: area frames %u\n", gAreaUpdateCounter);
    // the objects drawn: their model id (their place in the loaded models), place, behavior
    for (int i = 0; i < OBJECT_POOL_CAPACITY; i++) {
        struct Object *o = &gObjectPool[i];
        if (!(o->activeFlags & ACTIVE_FLAG_ACTIVE)) {
            continue;
        }
        int model = -1;
        for (int m = 0; m < 256; m++) {
            if (gLoadedGraphNodes[m] != NULL && gLoadedGraphNodes[m] == o->header.gfx.sharedChild) {
                model = m;
                break;
            }
        }
        int shown = (o->header.gfx.node.flags & GRAPH_RENDER_ACTIVE) && !(o->header.gfx.node.flags & GRAPH_RENDER_INVISIBLE);
        fprintf(sLog, "object model %d shown %d at %.0f %.0f %.0f yaw %d billboard %d anim %d frame %d\n", model, shown, o->oPosX, o->oPosY, o->oPosZ,
                (int)o->oFaceAngleYaw, (o->header.gfx.node.flags & GRAPH_RENDER_BILLBOARD) != 0, o->header.gfx.unk38.animID, o->header.gfx.unk38.animFrame);
    }
    fflush(sLog);
    exit(0);
}
