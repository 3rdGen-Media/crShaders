//
//  cr_file.h
//  CRViewer
//
//  Created by Joe Moulton on 2/9/19.
//  Copyright © 2019 Abstract Embedded. All rights reserved.
//

#ifndef cr_file_h
#define cr_file_h

#ifndef CR_SYSTEM_API
#define CR_SYSTEM_API
#define CR_SYSTEM_INLINE
#endif

//mmap
#include <stdint.h>
#include <string.h>
#include <stdlib.h> //malloc
#include <stdio.h>
#include <errno.h>
//#include <unistd.h>
//#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#ifndef _WIN32
//darwin system file open
#include <sys/mman.h>
#include <sys/fcntl.h>
//#include <sys/fadvise.h>
#include <unistd.h>
#else
#include <Windows.h>
#include <io.h>
#include <assert.h>
#endif

//lseeko
#define _LARGEFILE64_SOURCE
#define _FILE_OFFSET_BITS 64 //define off_t to be 64 bits
#include <sys/types.h>

#include <errno.h>


#ifndef O_BINARY
#define O_BINARY 0
#endif

#ifndef O_TEXT
#define O_TEXT 0
#endif

#ifndef O_LARGEFILE
#define O_LARGEFILE 0
#endif

//on Darwin file I/O is 64 bit by default
#ifdef __APPLE__
#  define off64_t off_t
#  define fopen64 fopen
#endif

#ifdef _WIN32
#define open _open

#ifndef PROT_READ
#define PROT_READ PAGE_READONLY
#define PROT_WRITE PAGE_READWRITE
#define PROT_READWRITE PAGE_READWRITE
#endif


#ifndef MAP_SHARED
#define MAP_SHARED 0
#define MAP_NORESERVE 0
#endif

#endif


typedef enum CRFileError
{
	CRFileTruncateError = -40,
	CRFileMapViewError = -30,
	CRFileMapError = -20,
	CRFileOpenError = -10,
	CRFileSuccess = 0
}CTFileError;

typedef struct CRFile
{
	char* buffer;
	unsigned long size;
	int fd;
#ifdef _WIN32
	HANDLE  hFile;
	HANDLE  mFile;
#endif
	char* path;
}CRFile;

typedef struct CRFileCursor
{
	union { //8 bytes + sizeof(CTFile)
		//overlap the header for various defined protocols
		//ReqlQueryMessageHeader * header;
		struct {
			void* buffer;
			size_t size;
		};
		CRFile file;
	};
	//unsigned long				headerLength;
	//unsigned long				contentLength;
	//CTConnection* conn;
	//CTTarget* target;
	//struct CTOverlappedResponse		overlappedResponse;
	//char						requestBuffer[65536L];
	//uint64_t					queryToken;
	//CTCursorHeaderLengthFunc	headerLengthCallback;
	//CTCursorCompletionClosure	responseCallback;
	//CTCursorCompletionClosure	queryCallback;

	//Reql
}CRFileCursor;
//typedef int CTStatus;

/*** cr_file API ***/

CR_SYSTEM_API CR_SYSTEM_INLINE int cr_file_open(const char * filepath);
CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_close(int fileDescriptor);
CR_SYSTEM_API CR_SYSTEM_INLINE off_t cr_file_size(int fileDescriptor);
CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_allocate_storage(int fileDescriptor, off_t size);

CR_SYSTEM_API CR_SYSTEM_INLINE int cr_file_create_w(char* filepath);																								//for creating a new file that is writeable
CR_SYSTEM_API CR_SYSTEM_INLINE void* cr_file_map_to_buffer( char ** buffer, size_t filesize, int filePrivelege, int mapOptions, int fileDescriptor, off_t offset);  //for mapping an open file for reading
CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_unmap(void * mFile, char * fbuffer);

CR_SYSTEM_API CR_SYSTEM_INLINE void* cr_file_map_to_buffer(char** buffer, size_t filesize, int filePrivelege, int mapOptions, int fileDescriptor, off_t offset);  //for mapping an open file for reading
CR_SYSTEM_API CR_SYSTEM_INLINE void* cr_file_map_to_buffer(char** buffer, size_t filesize, int filePrivelege, int mapOptions, int fileDescriptor, off_t offset);  //for mapping an open file for reading


/*** CRFileCursor API ***/

CR_SYSTEM_API CR_SYSTEM_INLINE CTFileError CRFileOpenMap(CRFile* file, char* filepath, unsigned long fileSize);
CR_SYSTEM_API CR_SYSTEM_INLINE void CRFileCloseMap(CRFile* file, unsigned long fileSize);
CR_SYSTEM_API CR_SYSTEM_INLINE void CRFileClose(CRFile * file);



#endif /* cr_file_h */
