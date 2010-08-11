//taken from fceux on 27-oct-2008
//subsequently modified for desmume

#ifndef _STRINGUTIL_H_
#define _STRINGUTIL_H_

#include <string>
#include <string.h>
#include <stdlib.h>
#include <vector>
#include <iostream>
#include <cstdio>

//definitions for str_strip() flags
#define STRIP_SP	0x01 // space
#define STRIP_TAB	0x02 // tab
#define STRIP_CR	0x04 // carriage return
#define STRIP_LF	0x08 // line feed


int str_ucase(char *str);
int str_lcase(char *str);
int str_ltrim(char *str, int flags);
int str_rtrim(char *str, int flags);
int str_strip(char *str, int flags);
int chr_replace(char *str, char search, char replace);
int str_replace(char *str, char *search, char *replace);

std::string strsub(const std::string& str, int pos, int len);
std::string strmid(const std::string& str, int pos, int len);
std::string strleft(const std::string& str, int len);
std::string strright(const std::string& str, int len);
std::string toupper(const std::string& str);

int HexStringToBytesLength(const std::string& str);
int Base64StringToBytesLength(const std::string& str);
std::string u32ToHexString(unsigned int val);
std::string BytesToString(const void* data, int len);
bool StringToBytes(const std::string& str, void* data, int len);

std::vector<std::string> tokenize_str(const std::string & str,const std::string & delims);
void splitpath(const char* path, char* drv, char* dir, char* name, char* ext);

unsigned short FastStrToU16(char* s, bool& valid);
char *U16ToDecStr(unsigned short a);
char *U32ToDecStr(unsigned int a);
char *U32ToDecStr(char* buf, unsigned int a);
char *U8ToDecStr(unsigned char a);
char *U8ToHexStr(unsigned char a);
char *U16ToHexStr(unsigned short a);

std::string stditoa(int n);

std::string readNullTerminatedAscii(std::istream* is);

std::string mass_replace(const std::string &source, const std::string &victim, const std::string &replacement);

std::wstring mbstowcs(std::string str);
std::string wcstombs(std::wstring str);



//TODO - dont we already have another  function that can do this
std::string getExtension(const char* input);


#endif
