#include <windows.h>
#include <vfw.h>
#include "burner.h"

#define VIDEO_STREAM	0
#define AUDIO_STREAM	1

static struct AVIFile
{
	bool				valid;
	int					fps;
	int					fps_scale;

	bool				video_added;
	BITMAPINFOHEADER	bitmap_format;

	bool				sound_added;
	WAVEFORMATEX		wave_format;

	AVISTREAMINFO		avi_video_header;
	AVISTREAMINFO		avi_sound_header;
	PAVIFILE			avi_file;
	PAVISTREAM			streams[2];
	PAVISTREAM			compressed_streams[2];

	AVICOMPRESSOPTIONS	compress_options[2];
	AVICOMPRESSOPTIONS*	compress_options_ptr[2];

	int					video_frames;
	int					sound_samples;
} *avi_file = NULL;

int bAviRecording = 0;


static bool truncate_existing(const char* filename)
{
	// this is only here because AVIFileOpen doesn't seem to do it for us
	FILE* fd = fopen(filename, "wb");
	if(fd)
	{
		fclose(fd);
		return true;
	}

	return false;
}

static void avi_create(struct AVIFile** avi_out)
{
	*avi_out = new AVIFile;
	memset(*avi_out, 0, sizeof(AVIFile));
	AVIFileInit();
}

static void avi_destroy(struct AVIFile** avi_out)
{
	AVIFile*& p_avi_file = *avi_out;
	if(!p_avi_file)
	{
		return;
	}

	AVIFile& avi = *p_avi_file;

	if(avi.sound_added)
	{
		if(avi.compressed_streams[AUDIO_STREAM])
		{
			AVIStreamClose(avi.compressed_streams[AUDIO_STREAM]);
			avi.compressed_streams[AUDIO_STREAM] = NULL;
			avi.streams[AUDIO_STREAM] = NULL;				// compressed_streams[AUDIO_STREAM] is just a copy of streams[AUDIO_STREAM]
		}
	}

	if(avi.video_added)
	{
		if(avi.compressed_streams[VIDEO_STREAM])
		{
			AVIStreamClose(avi.compressed_streams[VIDEO_STREAM]);
			avi.compressed_streams[VIDEO_STREAM] = NULL;
		}

		if(avi.streams[VIDEO_STREAM])
		{
			AVIStreamClose(avi.streams[VIDEO_STREAM]);
			avi.streams[VIDEO_STREAM] = NULL;
		}
	}

	if(avi.avi_file)
	{
		AVIFileClose(avi.avi_file);
		avi.avi_file = NULL;
	}

	delete *avi_out;
	*avi_out = NULL;
	AVIFileExit();
}

static void set_framerate(const int fps, const int fps_scale, struct AVIFile* avi_out)
{
	(*avi_out).fps = fps;
	(*avi_out).fps_scale = fps_scale;
}

static void set_video_format(const BITMAPINFOHEADER* bitmap_format, struct AVIFile* avi_out)
{
	memcpy(&((*avi_out).bitmap_format), bitmap_format, sizeof(BITMAPINFOHEADER));
	(*avi_out).video_added = true;
}

static void set_sound_format(const WAVEFORMATEX* wave_format, struct AVIFile* avi_out)
{
	memcpy(&((*avi_out).wave_format), wave_format, sizeof(WAVEFORMATEX));
	(*avi_out).sound_added = true;
}

static int avi_open(const char* filename, const BITMAPINFOHEADER* pbmih, const WAVEFORMATEX* pwfex)
{
	int result = 0;

	do
	{
		// close existing first
		AviEnd();

		if(!truncate_existing(filename))
			break;

		if(!pbmih)
			break;

		// create the object
		avi_create(&avi_file);

		// set framerate
		set_framerate(nAppVirtualFps, 100, avi_file);

		// open the file
		if(FAILED(AVIFileOpen(&avi_file->avi_file, filename, OF_CREATE | OF_WRITE, NULL)))
			break;

		// create the video stream
		set_video_format(pbmih, avi_file);

		memset(&avi_file->avi_video_header, 0, sizeof(AVISTREAMINFO));
		avi_file->avi_video_header.fccType = streamtypeVIDEO;
		avi_file->avi_video_header.dwScale = avi_file->fps_scale;
		avi_file->avi_video_header.dwRate = avi_file->fps;
		avi_file->avi_video_header.dwSuggestedBufferSize = avi_file->bitmap_format.biSizeImage;
		if(FAILED(AVIFileCreateStream(avi_file->avi_file, &avi_file->streams[VIDEO_STREAM], &avi_file->avi_video_header)))
			break;

		// get compression options
		memset(&avi_file->compress_options[VIDEO_STREAM], 0, sizeof(AVICOMPRESSOPTIONS));
		avi_file->compress_options_ptr[VIDEO_STREAM] = &avi_file->compress_options[0];
		if(!AVISaveOptions(hScrnWnd, 0, 1, &avi_file->streams[VIDEO_STREAM], &avi_file->compress_options_ptr[VIDEO_STREAM]))
			break;

		// create compressed stream
		if(FAILED(AVIMakeCompressedStream(&avi_file->compressed_streams[VIDEO_STREAM], avi_file->streams[VIDEO_STREAM], &avi_file->compress_options[VIDEO_STREAM], NULL)))
			break;

		// set the stream format
		if(FAILED(AVIStreamSetFormat(avi_file->compressed_streams[VIDEO_STREAM], 0, (void*)&avi_file->bitmap_format, avi_file->bitmap_format.biSize)))
			break;

		// add sound (if requested)
		if(pwfex)
		{
			// add audio format
			set_sound_format(pwfex, avi_file);

			// create the audio stream
			memset(&avi_file->avi_sound_header, 0, sizeof(AVISTREAMINFO));
			avi_file->avi_sound_header.fccType = streamtypeAUDIO;
			avi_file->avi_sound_header.dwQuality = (DWORD)-1;
			avi_file->avi_sound_header.dwScale = avi_file->wave_format.nBlockAlign;
			avi_file->avi_sound_header.dwRate = avi_file->wave_format.nAvgBytesPerSec;
			avi_file->avi_sound_header.dwSampleSize = avi_file->wave_format.nBlockAlign;
			avi_file->avi_sound_header.dwInitialFrames = 1;
			if(FAILED(AVIFileCreateStream(avi_file->avi_file, &avi_file->streams[AUDIO_STREAM], &avi_file->avi_sound_header)))
				break;

			// AVISaveOptions doesn't seem to work for audio streams
			// so here we just copy the pointer for the compressed stream
			avi_file->compressed_streams[AUDIO_STREAM] = avi_file->streams[AUDIO_STREAM];

			// set the stream format
			if(FAILED(AVIStreamSetFormat(avi_file->compressed_streams[AUDIO_STREAM], 0, (void*)&avi_file->wave_format, sizeof(WAVEFORMATEX))))
				break;
		}

		// initialize counters
		avi_file->video_frames = 0;
		avi_file->sound_samples = 0;

		// success
		result = 1;
		avi_file->valid = true;

	} while(false);

	if(!result)
	{
		avi_destroy(&avi_file);
	}

	return result;
}

//------------------------------------
//
// Interface implementation
//
//------------------------------------

static void MakeOfn()
{
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hScrnWnd;
	ofn.lpstrFilter = "AVI Files (*.avi)\0*.avi\0\0";
	ofn.lpstrFile = szChoice;
	ofn.nMaxFile = sizeof(szChoice);
	ofn.lpstrInitialDir = ".\\recordings";
	ofn.Flags = OFN_NOCHANGEDIR | OFN_HIDEREADONLY;
	ofn.lpstrDefExt = "avi";

	return;
}

void AviBegin()
{
	int nRet;
	int bOldPause;

	sprintf(szChoice, "%.8s", BurnDrvGetText(DRV_NAME));
	MakeOfn();
	ofn.lpstrTitle = "Record to AVI File";
	ofn.Flags |= OFN_OVERWRITEPROMPT;

	bOldPause = bRunPause;
	bRunPause = 1;
	nRet = GetSaveFileName(&ofn);
	bRunPause = bOldPause;

	if (nRet == 0) {
		return;
	}

	int width, height;
	BurnDrvGetVisibleSize(&width, &height);

	BITMAPINFOHEADER bi;
	memset(&bi, 0, sizeof(bi));
	bi.biSize = 0x28;    
	bi.biPlanes = 1;
	bi.biBitCount = 32;
	bi.biWidth = width;
	bi.biHeight = height;
	bi.biSizeImage = 4 * bi.biWidth * bi.biHeight;

	WAVEFORMATEX* wfex = NULL;

	if(nAudSampleRate > 0)
	{
		wfex = (WAVEFORMATEX*)malloc(sizeof(WAVEFORMATEX));
		memset(wfex, 0, sizeof(WAVEFORMATEX));
		wfex->wFormatTag = WAVE_FORMAT_PCM;
		wfex->nChannels = 2;
		wfex->nSamplesPerSec = nAudSampleRate[0];
		wfex->nAvgBytesPerSec = nAudSampleRate[0] * 2 * 2;		// stereo * 16-bit samples
		wfex->nBlockAlign = 2 * 2;							// stereo * 16-bit samples
		wfex->wBitsPerSample = 16;
		wfex->cbSize = 0;
	}

	if(!avi_open(szChoice, &bi, wfex))
	{
//		AppError("Error Creating File", 1);
		FBAPopupDisplay(PUF_TYPE_ERROR);
		free(wfex);
		return;
	}
	
	bAviRecording = 1;
	MenuEnableItems();

	free(wfex);

#ifdef _DEBUG
	printf("*** AVI recording started to file %s.\n", szChoice);
#endif
}

void AviVideoUpdate()
{
	if(!avi_file || !avi_file->valid)
	{
		return;
	}

	unsigned char* pScreenImage = ConvertVidImage(1);
	
    if(FAILED(AVIStreamWrite(avi_file->compressed_streams[VIDEO_STREAM],
                             avi_file->video_frames,
                             1,
                             pScreenImage,
                             avi_file->bitmap_format.biSizeImage,
                             AVIIF_KEYFRAME, NULL, NULL)))
	{
		avi_file->valid = false;
		if(pScreenImage != pVidImage)
		{
			free(pScreenImage);
		}
		return;
	}

	avi_file->video_frames++;

	if(pScreenImage != pVidImage)
	{
		free(pScreenImage);
	}
}

void AviSoundUpdate()
{
	if(!avi_file || !avi_file->valid || !pBurnSoundOut || !avi_file->sound_added)
	{
		return;
	}

	int nBytes = nBurnSoundLen * avi_file->wave_format.nBlockAlign;
    if(FAILED(AVIStreamWrite(avi_file->compressed_streams[AUDIO_STREAM],
                             avi_file->sound_samples,
                             nBurnSoundLen,
                             pBurnSoundOut,
                             nBytes,
                             0, NULL, NULL)))
	{
		avi_file->valid = false;
		return;
	}

	avi_file->sound_samples += nBurnSoundLen;
}

void AviEnd()
{
	if(!avi_file)
	{
		return;
	}

	avi_destroy(&avi_file);
	bAviRecording = 0;
	MenuEnableItems();
#ifdef _DEBUG
	printf("*** AVI recording ended.\n");
#endif
}
