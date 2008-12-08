#include "burner.h"
#include "png.h"

#define PNG_SIG_CHECK_BYTES 8

static int bImageOrientation;
static int xAspect, yAspect;

typedef struct tagIMAGE {
	LONG    width;
	LONG    height;
	DWORD   rowbytes;
	DWORD   imgbytes;
	BYTE**	rowptr;
	BYTE*	bmpbits;
} IMAGE;

void img_free(IMAGE* img)
{
	free(img->rowptr);
	free(img->bmpbits);
}

int img_alloc(IMAGE* img)
{
	img->rowbytes = ((DWORD)img->width * 24 + 31) / 32 * 4;
	img->imgbytes = img->rowbytes * img->height;
	img->rowptr = (BYTE**)malloc((size_t)img->height * sizeof(BYTE*));
	img->bmpbits = (BYTE*)malloc((size_t)img->imgbytes);

	if (img->rowptr == NULL || img->bmpbits == NULL) {
		img_free(img);
		return 0;
	}

	for (int y = 0; y < img->height; y++) {
		img->rowptr[img->height - y - 1] = img->bmpbits + y * img->rowbytes;
	}

	return 1;
}

// Resize the image to the required size using point filtering
int img_resize(IMAGE* img, int nHorMaxSize, int nVerMaxSize, int Screenshot)
{
	IMAGE new_img;
	memset(&new_img, 0, sizeof(IMAGE));
	
	double AspRatio = (double)xAspect / yAspect;
	
	if (!Screenshot && bGameInfoOpen) {
		AspRatio = (double)img->width / img->height;
	}	
	
	if (AspRatio > 1) {
		new_img.width = nHorMaxSize;
		new_img.height = (int)((double)nHorMaxSize / AspRatio);
		
		if (new_img.height > nVerMaxSize) {
			new_img.height = nVerMaxSize;
			new_img.width = (int)((double)nVerMaxSize * AspRatio);
		}
		bImageOrientation = 0;
	} else {
		new_img.height = nVerMaxSize;
		new_img.width = (int)((double)nVerMaxSize * AspRatio);
		bImageOrientation = 1;
	}
	
	img_alloc(&new_img);
	
	for (int y = 0; y < new_img.height; y++) {
		int row = img->height * y / new_img.height;
		for (int x = 0; x < new_img.width; x++) {
			new_img.rowptr[y][x * 3 + 0] = img->rowptr[row][img->width * x / new_img.width * 3 + 0];
			new_img.rowptr[y][x * 3 + 1] = img->rowptr[row][img->width * x / new_img.width * 3 + 1];
			new_img.rowptr[y][x * 3 + 2] = img->rowptr[row][img->width * x / new_img.width * 3 + 2];
		}
	}

	img_free(img);
	memcpy(img, &new_img, sizeof(IMAGE));

	return 0;
}

HBITMAP LoadPNG(HWND hDlg, FILE* fp, int nHorMaxSize, int nVerMaxSize, int Screenshot)
{
	IMAGE img;
	png_uint_32 width, height;
	int bit_depth, color_type;

	// check signature
	unsigned char pngsig[PNG_SIG_CHECK_BYTES];
	fread(pngsig, 1, PNG_SIG_CHECK_BYTES, fp);
	if (png_sig_cmp(pngsig, 0, PNG_SIG_CHECK_BYTES)) {
		return 0;
	}

	png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!png_ptr) {
		return 0;
	}

	png_infop info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr) {
		png_destroy_read_struct(&png_ptr, (png_infopp)NULL, (png_infopp)NULL);
		return 0;
	}

	memset(&img, 0, sizeof(IMAGE));
	png_init_io(png_ptr, fp);
	png_set_sig_bytes(png_ptr, PNG_SIG_CHECK_BYTES);
	png_read_info(png_ptr, info_ptr);
	png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type, NULL, NULL, NULL);

	if (setjmp(png_jmpbuf(png_ptr))) {
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
		return 0;
	}

	if (width > 1024 || height > 1024) {
		longjmp(png_ptr->jmpbuf, 1);
	}

	// Instruct libpng to convert the image to 24-bit RGB format
	if (color_type == PNG_COLOR_TYPE_PALETTE) {
		png_set_palette_to_rgb(png_ptr);
	}
	if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
		png_set_gray_to_rgb(png_ptr);
	}
	if (bit_depth == 16) {
		png_set_strip_16(png_ptr);
	}
	if (color_type & PNG_COLOR_MASK_ALPHA) {
		png_set_strip_alpha(png_ptr);
	}

	img.width = (LONG)width;
	img.height = (LONG)height;

	// Initialize our img structure
	if (!img_alloc(&img)) {
		longjmp(png_ptr->jmpbuf, 1);
	}

	// If bad things happen in libpng we need to do img_free(&img) as well
	if (setjmp(png_jmpbuf(png_ptr))) {
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
		img_free(&img);
		return 0;
	}

	// Read the .PNG image
	png_set_bgr(png_ptr);
	png_read_update_info(png_ptr, info_ptr);
	png_read_image(png_ptr, img.rowptr);
	png_read_end(png_ptr, (png_infop)NULL);
	png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);

	if(nHorMaxSize != 0 && nVerMaxSize != 0) {
		if (img_resize(&img, nHorMaxSize, nVerMaxSize, Screenshot)) {
			img_free(&img);
			return 0;
		}
	}

	// Create a bitmap for the image
	BITMAPINFO* bi = (BITMAPINFO*)LocalAlloc(LPTR, sizeof(BITMAPINFOHEADER) + sizeof(RGBQUAD));
	if (bi == NULL) {
		img_free(&img);
		return 0;
	}

	bi->bmiHeader.biSize			= sizeof(BITMAPINFOHEADER);
	bi->bmiHeader.biWidth			= img.width;
	bi->bmiHeader.biHeight			= img.height;
	bi->bmiHeader.biPlanes			= 1;
	bi->bmiHeader.biBitCount		= 24;
	bi->bmiHeader.biCompression		= BI_RGB;
	bi->bmiHeader.biSizeImage		= img.imgbytes;
	bi->bmiHeader.biXPelsPerMeter	= 0;
	bi->bmiHeader.biYPelsPerMeter	= 0;
	bi->bmiHeader.biClrUsed			= 0;
	bi->bmiHeader.biClrImportant	= 0;

	HDC hDC = GetDC(hDlg);
	BYTE* pBits = NULL;
	HBITMAP hNewBmp = CreateDIBSection(hDC, (BITMAPINFO*)bi, DIB_RGB_COLORS, (void**)&pBits, NULL, 0);
	if (pBits) {
		memcpy(pBits, img.bmpbits, img.imgbytes);
	}
	ReleaseDC(hDlg, hDC);
	LocalFree(bi);
	img_free(&img);

	return hNewBmp;
}

// Display 'Downloading, please wait' image
void DisplayDlWaitImg(HWND hDlg) 
{
	if(bGameInfoOpen) {
		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_FILEDL)));
	} else {
		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_FILEDL_SMALL)));
	}
}

void UpdatePreview(bool bPrevReset, HWND hDlg, TCHAR* szPreviewDir)
{
	nBurnDrvSelect = nDialogSelect;
	BurnDrvGetAspect(&xAspect, &yAspect);

	TCHAR szBaseName[MAX_PATH];
	TCHAR szFileName[MAX_PATH];
	FILE *fp = NULL;
	HBITMAP hNewImage = NULL;

	static int nIndex;
	int nOldIndex;	
	
	nOldIndex = nIndex;
	nIndex++;
	if (bPrevReset) {
		nIndex = 1;
		nOldIndex = -1;
		if (bGameInfoOpen == false) {
			if (hPrevBmp) {
				DeleteObject((HGDIOBJ)hPrevBmp);
				hPrevBmp = NULL;
			}
			if (nTimer) {
				KillTimer(hDlg, nTimer);
				nTimer = 0;
			}
		} else {
			if (hGiBmp) {
				DeleteObject((HGDIOBJ)hGiBmp);
				hGiBmp = NULL;
			}
		}
	}
	
	do {
		static TCHAR szServDir[MAX_PATH] = _T("");
		if(szPreviewDir == szAppPreviewsPath)	_stprintf(szServDir, _T("previews/"));
		if(szPreviewDir == szAppTitlesPath)		_stprintf(szServDir, _T("titles/"));
		if(szPreviewDir == szAppFlyersPath)		_stprintf(szServDir, _T("flyers/"));
		if(szPreviewDir == szAppCabinetsPath)	_stprintf(szServDir, _T("cabinets/"));
		if(szPreviewDir == szAppMarqueesPath)	_stprintf(szServDir, _T("marquees/"));
		if(szPreviewDir == szAppControlsPath)	_stprintf(szServDir, _T("controls/"));
		if(szPreviewDir == szAppPCBsPath)		_stprintf(szServDir, _T("pcbs/"));

		// Try to load a .PNG preview image
		_tcscpy(szBaseName, szPreviewDir);
		_tcscat(szBaseName, BurnDrvGetText(DRV_NAME));
		if (nIndex == 1) {
			_stprintf(szFileName, _T("%s.png"), szBaseName);
			fp = _tfopen(szFileName, _T("rb"));
			if (fp) break;
		}
		if (!fp) {
			_stprintf(szFileName, _T("%s-p%02i.png"), szBaseName, nIndex);
			fp = _tfopen(szFileName, _T("rb"));
			if (fp) break;
		}

		if (!fp && BurnDrvGetText(DRV_PARENT)) {						// Try the parent
			_tcscpy(szBaseName, szPreviewDir);
			_tcscat(szBaseName, BurnDrvGetText(DRV_PARENT));
			if (nIndex == 1) {
				_stprintf(szFileName, _T("%s.png"), szBaseName);
				fp = _tfopen(szFileName, _T("rb"));
				if (fp) break;
			}
			if (!fp) {
				_stprintf(szFileName, _T("%s-p%02i.png"), szBaseName, nIndex);
				fp = _tfopen(szFileName, _T("rb"));
				if (fp) break;
			}
		}

		if(bEnableAutoSupportFileDownload == false)	{
			//
		} else {
			// - - -
			// Download image code
		
			if(!fp) {
				TCHAR szImageFile[256] = _T("");
				_tcscpy(szBaseName, szPreviewDir);
				_tcscat(szBaseName, BurnDrvGetText(DRV_NAME));

				// Main Image
				if (nIndex == 1) {				
					_stprintf(szFileName, _T("%s.png"), szBaseName);
					_stprintf(szImageFile, _T("%s.png"), BurnDrvGetText(DRV_NAME));
					SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

					// Display 'Downloading, please wait' image
					DisplayDlWaitImg(hDlg);

					if(FileDownload(szPreviewDir, szFileName, szImageFile, szServDir)) {
						fp = _tfopen(szFileName, _T("rb"));
						if (fp) break;
					} 
				}

				// Try parent
				if (!fp && BurnDrvGetText(DRV_PARENT)) {
					_tcscpy(szBaseName, szPreviewDir);
					_tcscat(szBaseName, BurnDrvGetText(DRV_PARENT));

					if (nIndex == 1) {		
						_stprintf(szFileName, _T("%s.png"), szBaseName);
						_stprintf(szImageFile, _T("%s.png"), BurnDrvGetText(DRV_PARENT));
						//SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

						// Display 'Downloading, please wait' image
						DisplayDlWaitImg(hDlg);

						if(FileDownload(szPreviewDir, szFileName, szImageFile, szServDir)) {
							fp = _tfopen(szFileName, _T("rb"));
							if (fp) break;
						}	
					}
				}
			}
			// - - -
		}

		if (nIndex == 1) break;		
		if (!fp) nIndex = 1;

	} while (!fp);

	if (fp && nIndex != nOldIndex) {
		if(bGameInfoOpen == false) {
			hNewImage = LoadPNG(hDlg, fp, 230, 230, 1);
		} else {
			int Screenshot = 0;
			if (szPreviewDir == szAppPreviewsPath || szPreviewDir == szAppTitlesPath) Screenshot = 1;
			hNewImage = LoadPNG(hDlg, fp, 740, 360, Screenshot);
		}
		fclose(fp);
	}

	if (hNewImage) {
		if(bGameInfoOpen == false) {
			if(hPrevBmp) DeleteObject((HGDIOBJ)hPrevBmp);
			hPrevBmp = hNewImage;
		} else {
			if(hGiBmp) DeleteObject((HGDIOBJ)hGiBmp);
			hGiBmp = hNewImage;
		}

		if (bImageOrientation == 0) {
			if(bGameInfoOpen == false) {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPrevBmp);
			} else {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hGiBmp);
			}
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
			ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_HIDE);
		} else {
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
			ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_SHOW);
			if(bGameInfoOpen == false) {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPrevBmp);
			} else {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hGiBmp);
			}
		}
		if(bGameInfoOpen == false) {
			nTimer = SetTimer(hDlg, 1, 2500, NULL);
		}

	} else {
		// We couldn't load a new image for this game, so kill the timer (it will be restarted when a new game is selected)
		if ((nTimer) && (bGameInfoOpen == false)) {
			KillTimer(hDlg, nTimer);
			nTimer = 0;
		}
		if(bGameInfoOpen == false) {
			if (!hPrevBmp) {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_PREVIEW)));
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
				ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_HIDE);
			}
		} else {
			if (!hGiBmp) {
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_PREVIEW_ALT)));
				SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
				ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_HIDE);
			}
		}
	}
}
