#include "burnint.h"
#include "burn_sound.h"
#include "burn_y8950.h"
#include "m6809_intf.h"
#include "hd6309_intf.h"
#include "m6800_intf.h"
#include "m6502_intf.h"

// Timer Related

#define MAX_TIMER_VALUE ((1 << 30) - 65536)

static double dTimeY8950;									// Time elapsed since the emulated machine was started

static int nTimerCount[2], nTimerStart[2];

// Callbacks
static int (*pTimerOverCallback)(int, int);
static double (*pTimerTimeCallback)();

static int nCPUClockspeed = 0;
static int (*pCPUTotalCycles)() = NULL;
static int (*pCPURun)(int) = NULL;
static void (*pCPURunEnd)() = NULL;

// ---------------------------------------------------------------------------
// Running time

static double BurnTimerTimeCallbackDummy()
{
	return 0.0;
}

extern "C" double BurnTimerGetTimeY8950()
{
	return dTimeY8950 + pTimerTimeCallback();
}

// ---------------------------------------------------------------------------
// Update timers

static int nTicksTotal, nTicksDone, nTicksExtra;

int BurnTimerUpdateY8950(int nCycles)
{
	int nIRQStatus = 0;

	nTicksTotal = MAKE_TIMER_TICKS(nCycles, nCPUClockspeed);

//	bprintf(PRINT_NORMAL, _T(" -- Ticks: %08X, cycles %i\n"), nTicksTotal, nCycles);

	while (nTicksDone < nTicksTotal) {
		int nTimer, nCyclesSegment, nTicksSegment;

		// Determine which timer fires first
		if (nTimerCount[0] <= nTimerCount[1]) {
			nTicksSegment = nTimerCount[0];
		} else {
			nTicksSegment = nTimerCount[1];
		}
		if (nTicksSegment > nTicksTotal) {
			nTicksSegment = nTicksTotal;
		}

		nCyclesSegment = MAKE_CPU_CYLES(nTicksSegment + nTicksExtra, nCPUClockspeed);
//		bprintf(PRINT_NORMAL, _T("  - Timer: %08X, %08X, %08X, cycles %i, %i\n"), nTicksDone, nTicksSegment, nTicksTotal, nCyclesSegment, pCPUTotalCycles());

		pCPURun(nCyclesSegment - pCPUTotalCycles());

		nTicksDone = MAKE_TIMER_TICKS(pCPUTotalCycles() + 1, nCPUClockspeed) - 1;
//		bprintf(PRINT_NORMAL, _T("  - ticks done -> %08X cycles -> %i\n"), nTicksDone, pCPUTotalCycles());

		nTimer = 0;
		if (nTicksDone >= nTimerCount[0]) {
			if (nTimerStart[0] == MAX_TIMER_VALUE) {
				nTimerCount[0] = MAX_TIMER_VALUE;
			} else {
				nTimerCount[0] += nTimerStart[0];
			}
//			bprintf(PRINT_NORMAL, _T("  - timer 0 fired\n"));
			nTimer |= 1;
		}
		if (nTicksDone >= nTimerCount[1]) {
			if (nTimerStart[1] == MAX_TIMER_VALUE) {
				nTimerCount[1] = MAX_TIMER_VALUE;
			} else {
				nTimerCount[1] += nTimerStart[1];
			}
//			bprintf(PRINT_NORMAL, _T("  - timer 1 fired\n"));
			nTimer |= 2;
		}
		if (nTimer & 1) {
			nIRQStatus |= pTimerOverCallback(0, 0);
		}
		if (nTimer & 2) {
			nIRQStatus |= pTimerOverCallback(0, 1);
		}
	}

	return nIRQStatus;
}

void BurnTimerEndFrameY8950(int nCycles)
{
	int nTicks = MAKE_TIMER_TICKS(nCycles, nCPUClockspeed);

	BurnTimerUpdateY8950(nCycles);

	if (nTimerCount[0] < MAX_TIMER_VALUE) {
		nTimerCount[0] -= nTicks;
	}
	if (nTimerCount[1] < MAX_TIMER_VALUE) {
		nTimerCount[1] -= nTicks;
	}

	nTicksDone -= nTicks;
	if (nTicksDone < 0) {
//		bprintf(PRINT_ERROR, _T(" -- ticks done -> %08X\n"), nTicksDone);
		nTicksDone = 0;
	}
}

void BurnTimerUpdateEndY8950()
{
//	bprintf(PRINT_NORMAL, _T("  - end %i\n"), pCPUTotalCycles());

	pCPURunEnd();

	nTicksTotal = 0;
}

void BurnOPLTimerCallbackY8950(int c, double period)
{
	pCPURunEnd();

	if (period == 0.0) {
		nTimerCount[c] = MAX_TIMER_VALUE;
//		bprintf(PRINT_NORMAL, _T("  - timer %i stopped\n"), c);
		return;
	}

	nTimerCount[c]  = (int)(period * (double)TIMER_TICKS_PER_SECOND);
	nTimerCount[c] += MAKE_TIMER_TICKS(pCPUTotalCycles(), nCPUClockspeed);

//	bprintf(PRINT_NORMAL, _T("  - timer %i started, %08X ticks (fires in %lf seconds)\n"), c, nTimerCount[c], period);
}

void BurnTimerScanY8950(int nAction, int* pnMin)
{
	if (pnMin && *pnMin < 0x029521) {
		*pnMin = 0x029521;
	}

	if (nAction & ACB_DRIVER_DATA) {
		SCAN_VAR(nTimerCount);
		SCAN_VAR(nTimerStart);
		SCAN_VAR(dTimeY8950);

		SCAN_VAR(nTicksDone);
	}
}

void BurnTimerExitY8950()
{
	nCPUClockspeed = 0;
	pCPUTotalCycles = NULL;
	pCPURun = NULL;
	pCPURunEnd = NULL;

	return;
}

void BurnTimerResetY8950()
{
	nTimerCount[0] = nTimerCount[1] = MAX_TIMER_VALUE;
	nTimerStart[0] = nTimerStart[1] = MAX_TIMER_VALUE;

	dTimeY8950 = 0.0;

	nTicksDone = 0;
}

int BurnTimerInitY8950(int (*pOverCallback)(int, int), double (*pTimeCallback)())
{
	BurnTimerExitY8950();

	pTimerOverCallback = pOverCallback;
	pTimerTimeCallback = pTimeCallback ? pTimeCallback : BurnTimerTimeCallbackDummy;

	BurnTimerResetY8950();

	return 0;
}

int BurnTimerAttachSekY8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = SekTotalCycles;
	pCPURun = SekRun;
	pCPURunEnd = SekRunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachZetY8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = ZetTotalCycles;
	pCPURun = ZetRun;
	pCPURunEnd = ZetRunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachM6809Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = M6809TotalCycles;
	pCPURun = M6809Run;
	pCPURunEnd = M6809RunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachHD6309Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = HD6309TotalCycles;
	pCPURun = HD6309Run;
	pCPURunEnd = HD6309RunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachM6800Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = M6800TotalCycles;
	pCPURun = M6800Run;
	pCPURunEnd = M6800RunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachHD63701Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = M6800TotalCycles;
	pCPURun = HD63701Run;
	pCPURunEnd = HD63701RunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachM6803Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = M6800TotalCycles;
	pCPURun = M6803Run;
	pCPURunEnd = M6803RunEnd;

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

int BurnTimerAttachM6502Y8950(int nClockspeed)
{
	nCPUClockspeed = nClockspeed;
	pCPUTotalCycles = m6502TotalCycles;
	pCPURun = m6502Run;
	pCPURunEnd = M6800RunEnd; // doesn't do anything...

	nTicksExtra = MAKE_TIMER_TICKS(1, nCPUClockspeed) - 1;

//	bprintf(PRINT_NORMAL, _T("--- timer cpu speed %iHz, one cycle = %i ticks.\n"), nClockspeed, MAKE_TIMER_TICKS(1, nCPUClockspeed));

	return 0;
}

// Sound Related

void (*BurnY8950Update)(short* pSoundBuf, int nSegmentEnd);

static int (*BurnY8950StreamCallback)(int nSoundRate);

static int nBurnY8950SoundRate;

static short* pBuffer;
static short* pY8950Buffer;

static int nY8950Position;

static unsigned int nSampleSize;
static unsigned int nFractionalPosition;

static int bY8950AddSignal;

// ----------------------------------------------------------------------------
// Dummy functions

static void Y8950UpdateDummy(short* , int /* nSegmentEnd */)
{
	return;
}

static int Y8950StreamCallbackDummy(int /* nSoundRate */)
{
	return 0;
}

// ----------------------------------------------------------------------------
// Execute Y8950 for part of a frame

static void Y8950Render(int nSegmentLength)
{
	if (nY8950Position >= nSegmentLength) {
		return;
	}

//	bprintf(PRINT_NORMAL, _T("    Y8950 render %6i -> %6i\n", nY8950Position, nSegmentLength));

	nSegmentLength -= nY8950Position;

	Y8950UpdateOne(0, pBuffer + 0 * 4096 + 4 + nY8950Position, nSegmentLength);

	nY8950Position += nSegmentLength;
}

// ----------------------------------------------------------------------------
// Update the sound buffer

static void Y8950UpdateResample(short* pSoundBuf, int nSegmentEnd)
{
	int nSegmentLength = nSegmentEnd;
	int nSamplesNeeded = nSegmentEnd * nBurnY8950SoundRate / nBurnSoundRate + 1;

//	bprintf(PRINT_NORMAL, _T("    Y8950 update        -> %6i\n", nSegmentLength));

	if (nSamplesNeeded < nY8950Position) {
		nSamplesNeeded = nY8950Position;
	}

	if (nSegmentLength > nBurnSoundLen) {
		nSegmentLength = nBurnSoundLen;
	}
	nSegmentLength <<= 1;

	Y8950Render(nSamplesNeeded);

	pY8950Buffer = pBuffer + 0 * 4096 + 4;

	for (int i = (nFractionalPosition & 0xFFFF0000) >> 15; i < nSegmentLength; i += 2, nFractionalPosition += nSampleSize) {
		short nSample =  INTERPOLATE4PS_16BIT((nFractionalPosition >> 4) & 0x0FFF,
												pY8950Buffer[(nFractionalPosition >> 16) - 3],
												pY8950Buffer[(nFractionalPosition >> 16) - 2],
												pY8950Buffer[(nFractionalPosition >> 16) - 1],
												pY8950Buffer[(nFractionalPosition >> 16) - 0]);
		if (bY8950AddSignal) {
			pSoundBuf[i + 0] += nSample;
			pSoundBuf[i + 1] += nSample;
		} else {
			pSoundBuf[i + 0] = nSample;
			pSoundBuf[i + 1] = nSample;
		}
	}

	if (nSegmentEnd >= nBurnSoundLen) {
		int nExtraSamples = nSamplesNeeded - (nFractionalPosition >> 16);

//		bprintf(PRINT_NORMAL, _T("   %6i rendered, %i extra, %i <- %i\n"), nSamplesNeeded, nExtraSamples, nExtraSamples, (nFractionalPosition >> 16) + nExtraSamples - 1);

		for (int i = -4; i < nExtraSamples; i++) {
			pY8950Buffer[i] = pY8950Buffer[(nFractionalPosition >> 16) + i];
		}

		nFractionalPosition &= 0xFFFF;

		nY8950Position = nExtraSamples;
	}
}

static void Y8950UpdateNormal(short* pSoundBuf, int nSegmentEnd)
{
	int nSegmentLength = nSegmentEnd;

//	bprintf(PRINT_NORMAL, _T("    Y8950 render %6i -> %6i\n"), nY8950Position, nSegmentEnd);

	if (nSegmentEnd < nY8950Position) {
		nSegmentEnd = nY8950Position;
	}

	if (nSegmentLength > nBurnSoundLen) {
		nSegmentLength = nBurnSoundLen;
	}

	Y8950Render(nSegmentEnd);

	pY8950Buffer = pBuffer + 4 + 0 * 4096;

	for (int i = nFractionalPosition; i < nSegmentLength; i++) {
		if (bY8950AddSignal) {
			pSoundBuf[(i << 1) + 0] += pY8950Buffer[i];
			pSoundBuf[(i << 1) + 1] += pY8950Buffer[i];
		} else {
			pSoundBuf[(i << 1) + 0] = pY8950Buffer[i];
			pSoundBuf[(i << 1) + 1] = pY8950Buffer[i];
		}
	}

	nFractionalPosition = nSegmentLength;

	if (nSegmentEnd >= nBurnSoundLen) {
		int nExtraSamples = nSegmentEnd - nBurnSoundLen;

		for (int i = 0; i < nExtraSamples; i++) {
			pY8950Buffer[i] = pY8950Buffer[nBurnSoundLen + i];
		}

		nFractionalPosition = 0;

		nY8950Position = nExtraSamples;

	}
}

// ----------------------------------------------------------------------------
// Callbacks for Y8950 core

void BurnY8950UpdateRequest(int, int)
{
	Y8950Render(BurnY8950StreamCallback(nBurnY8950SoundRate));
}

// ----------------------------------------------------------------------------
// Initialisation, etc.

void BurnY8950Reset()
{
	BurnTimerResetY8950();

	Y8950ResetChip(0);
}

void BurnY8950Exit()
{
	Y8950Shutdown();

	BurnTimerExitY8950();

	free(pBuffer);
	
	bY8950AddSignal = 0;
}

int BurnY8950Init(int nClockFrequency, unsigned char* Y8950ADPCMROM, int nY8950ADPCMSize, OPL_IRQHANDLER IRQCallback, int (*StreamCallback)(int), int bAddSignal)
{
	BurnTimerInitY8950(&Y8950TimerOver, NULL);

	if (nBurnSoundRate <= 0) {
		BurnY8950StreamCallback = Y8950StreamCallbackDummy;

		BurnY8950Update = Y8950UpdateDummy;

		Y8950Init(1, nClockFrequency, 11025);
		return 0;
	}

	BurnY8950StreamCallback = StreamCallback;

	if (nFMInterpolation == 3) {
		// Set Y8950 core samplerate to match the hardware
		nBurnY8950SoundRate = nClockFrequency / 72;
		// Bring Y8950 core samplerate within usable range
		while (nBurnY8950SoundRate > nBurnSoundRate * 3) {
			nBurnY8950SoundRate >>= 1;
		}

		BurnY8950Update = Y8950UpdateResample;

		nSampleSize = (unsigned int)nBurnY8950SoundRate * (1 << 16) / nBurnSoundRate;
		nFractionalPosition = 0;
	} else {
		nBurnY8950SoundRate = nBurnSoundRate;

		BurnY8950Update = Y8950UpdateNormal;
	}

	Y8950Init(1, nClockFrequency, nBurnY8950SoundRate);
	Y8950SetIRQHandler(0, IRQCallback, 0);
	Y8950SetTimerHandler(0, &BurnOPLTimerCallbackY8950, 0);
	Y8950SetUpdateHandler(0, &BurnY8950UpdateRequest, 0);
	Y8950SetDeltaTMemory(0, Y8950ADPCMROM, nY8950ADPCMSize);

	pBuffer = (short*)malloc(4096 * sizeof(short));
	memset(pBuffer, 0, 4096 * sizeof(short));

	nY8950Position = 0;

	nFractionalPosition = 0;
	
	bY8950AddSignal = bAddSignal;

	return 0;
}

void BurnY8950Scan(int nAction, int* pnMin)
{
	BurnTimerScanY8950(nAction, pnMin);
	
	if (nAction & ACB_DRIVER_DATA) {
		SCAN_VAR(nY8950Position);
	}
}
