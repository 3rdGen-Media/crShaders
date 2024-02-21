//
//  cr_file.c
//  CRViewer
//
//  Created by Joe Moulton on 2/9/19.
//  Copyright © 2019 Abstract Embedded. All rights reserved.
//

#include "cr_file.h"

#ifndef _WIN32
#include "assert.h"
#endif

CR_SYSTEM_API CR_SYSTEM_INLINE int cr_file_open(const char * filepath)
{
    int fileDescriptor = open(filepath, O_RDONLY, 0700);
    
    //check if the file descriptor is valid
    if (fileDescriptor < 0) {
        
        printf("\nUnable to open file: %s\n", filepath);
        printf("errno is %d and fd is %d",errno,fileDescriptor);
        
    }
    
    //printf("\nfile size = %lld\n", filesize);
    
    //disabling disk caching will allow zero performance reads
    //According to John Carmack:  I am pleased to report that fcntl( fd, F_NOCACHE ) works exactly as desired on iOS – I always worry about behavior of historic unix flags on Apple OSs. Using
    //this and page aligned target memory will bypass the file cache and give very repeatable performance ranging from the page fault bandwidth with 32k reads up to 30 mb/s for one meg reads (22
    //mb/s for the old iPod). This is fractionally faster than straight reads due to the zero copy, but the important point is that it won’t evict any other buffer data that may have better
    //temporal locality.
    
#ifndef _WIN32
    //this takes care preventing caching, but we also need to ensure that "target memory" is page aligned
    if ( fcntl( fileDescriptor, F_NOCACHE ) < 0 )
    {
        printf("\nF_NOCACHE failed!\n");
    }
#endif
    return fileDescriptor;

}


CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_unmap(void* mFile, char * fbuffer)
{
#ifdef _WIN32
	if (mFile)
	{
		//Unmap the file backing buffer
		if (fbuffer)
			UnmapViewOfFile(fbuffer);

		//close the file mapping
		CloseHandle(mFile);
	}
	return;

	/*
	//check if this is a memory mapped file
	HANDLE mFile;
	char handleStr[sizeof(HANDLE)+1] = "\0";
	HANDLE hFile = (HANDLE)_get_osfhandle( fileDescriptor );
	memcpy(handleStr, &(hFile), sizeof(HANDLE));
	handleStr[sizeof(HANDLE)] = '\0';

	//TO DO:  how to lookup the correct file privelege
	mFile = OpenFileMapping( FILE_MAP_READ, 0, handleStr );

	if( mFile )
	{
		//Unmap the file backing buffer
		if (fbuffer)
		  UnmapViewOfFile(fbuffer);

		//close the file mapping
		CloseHandle(mFile);
	}
	else //we assume the fdescriptor has already been closed if mmapped
	*/
#else

#endif
    //close(fileDescriptor);
    return;
}


/*
CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_close(int fileDescriptor)
{
#ifdef _WIN32

#else

#endif
    close(fileDescriptor);
    return;
}
*/

CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_close(int fileDescriptor)
{
#ifdef _WIN32
	//check if this is a memory mapped file
	HANDLE hFile = (HANDLE)_get_osfhandle(fileDescriptor);
	if (hFile != INVALID_HANDLE_VALUE)
		CloseHandle(hFile);
	else //we didn't create the file with a WIN32 HANDLE, just a descriptor
#else

#endif
	close(fileDescriptor);
	return;
}

CR_SYSTEM_API CR_SYSTEM_INLINE off_t cr_file_size(int fileDescriptor)
{
    off_t filesize = 0;
    filesize =lseek(fileDescriptor, 0, SEEK_END);
    lseek(fileDescriptor, 0, SEEK_SET);
    return filesize;
}

CR_SYSTEM_API CR_SYSTEM_INLINE void cr_file_allocate_storage(int fileDescriptor, off_t size)
{
    //first we need to preallocate a contiguous range of memory for the file
    //if this fails we won't have enough space to reliably map a file for zero copy lookup
#ifndef _WIN32
    fstore_t fst;
    fst.fst_flags = F_ALLOCATECONTIG;
    fst.fst_posmode = F_PEOFPOSMODE;
    fst.fst_offset = 0;
    fst.fst_length = size;
    fst.fst_bytesalloc = 0;
    
    if( fcntl( fileDescriptor, F_ALLOCATECONTIG, &fst ) < 0 )
    {
        printf("F_PREALLOCATED failed!");
    }
#else
	assert(1==0);
#endif
    return;
}



//to do change file size to an unsigned long long specifier
CR_SYSTEM_API CR_SYSTEM_INLINE void*  cr_file_map_to_buffer( char ** buffer, size_t filesize, int filePrivelege, int mapOptions, int fileDescriptor, off_t offset)
{
#ifdef _WIN32

	DWORD dwMaximumSizeHigh, dwMaximumSizeLow;

	HANDLE mFile;
	char handleStr[sizeof(HANDLE)+1] = "\0";
	HANDLE hFile = (HANDLE)_get_osfhandle( fileDescriptor );
	memcpy(handleStr, &(hFile), sizeof(HANDLE));
	handleStr[sizeof(HANDLE)] = '\0';
	dwMaximumSizeHigh = (unsigned long long)filesize >> 32;
	dwMaximumSizeLow = filesize & 0xffffffffu;

    /*
	// try to allocate and map our space
    if ( !(mFile = CreateFileMappingA(hFile, NULL, filePrivelege, dwMaximumSizeHigh, dwMaximumSizeLow, handleStr)) ||
         !(*buffer = (char *)MapViewOfFileEx(mFile, FILE_MAP_READ, 0, 0, filesize, NULL)) )//||
          //!MapViewOfFileEx(buffer->mapping, FILE_MAP_ALL_ACCESS, 0, 0, ring_size, (char *)desired_addr + ring_size))
    {
      // something went wrong - clean up
	  printf("cr_file_map_to_buffer failed:  OS Virtual Mapping failed");
      //jrm_circ_buffer_cleanup(buffer);
    }
    else // success!
	{
	  printf("cr_file_map_to_buffer Success:  OS Virtual Mapping succeeded");
	}
    */

	// try to allocate and map our space (get a win32 mapped file handle)
	if (!(mFile = CreateFileMappingA(hFile, NULL, PAGE_READONLY, dwMaximumSizeHigh, dwMaximumSizeLow, NULL)))//||
		//!MapViewOfFileEx(buffer->mapping, FILE_MAP_ALL_ACCESS, 0, 0, ring_size, (char *)desired_addr + ring_size))
	{
		// something went wrong - clean up
		fprintf(stderr, "cr_file_map_to_buffer failed:  OS Virtual Mapping failed with error (%ld)", GetLastError());
		assert(1 == 0);
		//err = CTFileMapError;
		//return err;
	}

	// Offsets must be a multiple of the system's allocation granularity.  We
	// guarantee this by making our view size equal to the allocation granularity.
	if (!(*buffer = (char*)MapViewOfFileEx(mFile, FILE_MAP_READ, 0, 0, filesize, NULL)))
	{
		fprintf(stderr, "cr_file_map_to_buffer failed:  OS Virtual Mapping failed2 ");
		assert(1 == 0);
		//err = CTFileMapViewError;
		//return err;
	}

    return mFile;

#else
    return mmap(*buffer, (size_t)(filesize), filePrivelege, mapOptions, fileDescriptor, offset);
#endif
}



CR_SYSTEM_API CR_SYSTEM_INLINE int cr_file_create_w(char* filepath)
{
	int fileDescriptor;// = open(filepath, O_RDWR | O_APPEND | O_CREAT | O_TRUNC | O_TEXT | O_SEQUENTIAL, 0700);
#ifdef _WIN32

	HANDLE fh;
	DWORD dwErr;

	printf("cr_file_create_w::filepath = %s\n", filepath);
	fh = CreateFileA(filepath, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (fh == INVALID_HANDLE_VALUE)
	{
		printf("\ncr_file_create_w::CreateFileA failed: %s\n", filepath);

		dwErr = GetLastError();
		if (dwErr > 0) {
			printf("ncr_file_create_w::CreateFileA Error Code: %lu\n", dwErr);
			fileDescriptor = (int)dwErr;
		}

	}

	//asociate int fd with WIN32 file HANDLE
	fileDescriptor = _open_osfhandle((intptr_t)fh, O_RDWR | O_APPEND);

	//check if the file descriptor is valid
	if (fileDescriptor < 0) {

		printf("\nUnable to open osfhandle: %s\n", filepath);
		printf("errno is %d and fd is %d", errno, fileDescriptor);
		fileDescriptor = errno;

	}
#else
	fileDescriptor = open(filepath, O_RDWR | O_APPEND | O_CREAT | O_TRUNC | O_TEXT /*| O_SEQUENTIAL*/, 0700);
	//check if the file descriptor is valid
	if (fileDescriptor < 0) {

		printf("\nUnable to open file: %s\n", filepath);
		printf("errno is %d and fd is %d", errno, fileDescriptor);
		fileDescriptor = errno;
	}

	//printf("\nfile size = %lld\n", filesize);

	//disabling disk caching will allow zero performance reads
	//According to John Carmack:  I am pleased to report that fcntl( fd, F_NOCACHE ) works exactly as desired on iOS � I always worry about behavior of historic unix flags on Apple OSs. Using
	//this and page aligned target memory will bypass the file cache and give very repeatable performance ranging from the page fault bandwidth with 32k reads up to 30 mb/s for one meg reads (22
	//mb/s for the old iPod). This is fractionally faster than straight reads due to the zero copy, but the important point is that it won�t evict any other buffer data that may have better
	//temporal locality.

	//this takes care preventing caching, but we also need to ensure that "target memory" is page aligned
	//if (fcntl(fileDescriptor, F_NOCACHE) < 0)
	//{
	//	printf("\nF_NOCACHE failed!\n");
	//}
#endif
	return fileDescriptor;

}


/***
 *	CRFileCursor API
***/


CTFileError CRFileMapForWrite(CRFile* file, unsigned long fileSize)
{
	CTFileError err = CRFileSuccess;
#ifdef _WIN32
	//DWORD dwErr;

	//open file descriptor/buffer
	DWORD dwMaximumSizeHigh, dwMaximumSizeLow;
	//LPVOID mapAddress = NULL;
	char handleStr[sizeof(HANDLE) + 1] = "\0";

	//set the desired file size on the cursor
	file->size = fileSize;

	//get a win32 file handle from the file descriptor
	file->hFile = (HANDLE)_get_osfhandle(file->fd);

	memcpy(handleStr, &(file->hFile), sizeof(HANDLE));
	handleStr[sizeof(HANDLE)] = '\0';
	dwMaximumSizeHigh = (unsigned long long)file->size >> 32;
	dwMaximumSizeLow = file->size & 0xffffffffu;

	//fprintf(stderr, "GetLastError (%d)", GetLastError());

	// try to allocate and map our space (get a win32 mapped file handle)
	if (!(file->mFile = CreateFileMappingA(file->hFile, NULL, PAGE_READWRITE, dwMaximumSizeHigh, dwMaximumSizeLow, NULL)))//||
		//!MapViewOfFileEx(buffer->mapping, FILE_MAP_ALL_ACCESS, 0, 0, ring_size, (char *)desired_addr + ring_size))
	{
		// something went wrong - clean up
		fprintf(stderr, "cr_file_map_to_buffer failed:  OS Virtual Mapping failed with error (%ld)", GetLastError());
		err = CRFileMapError;
		return err;
	}

	// Offsets must be a multiple of the system's allocation granularity.  We
	// guarantee this by making our view size equal to the allocation granularity.
	if (!(file->buffer = (char*)MapViewOfFileEx(file->mFile, FILE_MAP_ALL_ACCESS, 0, 0, file->size, NULL)))
	{
		fprintf(stderr, "cr_file_map_to_buffer failed:  OS Virtual Mapping failed2 ");
		err = CRFileMapViewError;
		return err;
	}
	//filebuffer = (char*)ct_file_map_to_buffer(&(filebuffer), fileSize, PROT_READWRITE, MAP_SHARED | MAP_NORESERVE, fileDescriptor, 0);
#else
	//set the desired file size on the cursor
	if (ftruncate(file->fd, fileSize) == -1)
	{
		printf("CRFileMapForWrite: ftruncate (size = %lu) failed with error: %d", fileSize, errno);
        err = CRFileTruncateError;
		return err;
	}
	file->size = fileSize;
	file->buffer = (char*)cr_file_map_to_buffer(&(file->buffer), fileSize, PROT_READ | PROT_WRITE, MAP_SHARED, file->fd, 0);
	if (!(file->buffer) || file->buffer == (void*)-1)
	{
		printf("CRFileMapForWrite: ct_file_map_to_buffer failed::mmap failed with error: %d", errno);
		err = CRFileMapError;
		assert(1 == 0);
	}

	if (madvise(file->buffer, (size_t)fileSize, MADV_SEQUENTIAL | MADV_WILLNEED) == -1)
	{
		fprintf(stderr, "\nCRFileMapForWrite:: madvise failed\n");
	}
#endif
	return err;
}

CR_SYSTEM_API CR_SYSTEM_INLINE CTFileError CRFileOpenMap(CRFile* file, char* filepath, unsigned long fileSize)
{
	CTFileError err;

	//create/overwrite a file on disk with write privelege 
	file->fd = cr_file_create_w(filepath);

	//map the file to virtual memory with write privelege
	err = CRFileMapForWrite(file, fileSize);
	return err;
}



CR_SYSTEM_API CR_SYSTEM_INLINE void CRFileCloseMap(CRFile * file, unsigned long fileSize)
{
	//ALWAYS Use this function to close a system level file mapping:
	//
	// --NEVER use vt_map_file/vt_unmap_file directly
	// --On Win32 this function unmaps the "view" of file with fileSize as input, then unmaps the file buffer itself
	// --On Linux there is no concept of a Map View distinguished from the file mapping, so it just unmaps the file buffer with fileSize as input
	// --This function *DOES NOT* close the actual file descriptor
#ifdef _WIN32
	DWORD dwCurrentFilePosition;
	DWORD dwMaximumSizeHigh = (unsigned long long)fileSize >> 32;
	DWORD dwMaximumSizeLow = fileSize & 0xffffffffu;
	LONG offsetHigh = (LONG)dwMaximumSizeHigh;
	LONG offsetLow = (LONG)dwMaximumSizeLow;

	FlushViewOfFile(file->buffer, fileSize);
	UnmapViewOfFile(file->buffer);
	CloseHandle(file->mFile);
	file->size = fileSize;

	fprintf(stderr, "CRFileCloseMap::Closing file mapping with size = %lu bytes\n", fileSize);
	dwCurrentFilePosition = SetFilePointer(file->hFile, offsetLow, &offsetHigh, FILE_BEGIN); // provides offset from current position
	SetEndOfFile(file->hFile);

	//We may want close the system virtual memory mapping associated with the file descriptor for the client automatically
	//come back to this later
	//ct_file_unmap(cursor->file.fd, cursor->file.buffer);

#else
	//truncate file to size of buffer
	if (ftruncate(file->fd, fileSize) == -1)
	{
		fprintf(stderr, "CTCursorCloseMappingWithSize: ftruncate (size = %lu) failed with error: %d", fileSize, errno);
		//err = VTFileTruncateError;
		//return err;
	}

	/*
	int ret = 0;
	if( (ret = msync(cursor->file.buffer, fileSize, MS_SYNC)) != 0 )
	{
		fprintf(stderr, "CTCursorCloseMappingWithSize:msync failed with error: %d", errno);\
		assert(1==0);
	}
	*/

	//unmap the file's mapped buffer linux style with size as input 
	//and close the system virtual memory mapping associated with the file in one shot 
	if (munmap(file->buffer, (size_t)fileSize) < 0)
	{
		fprintf(stderr, "CTCursorCloseMappingWithSize munmap failed with error: %s\n", strerror(errno));
		assert(1 == 0);
	}


#endif

}

CR_SYSTEM_API CR_SYSTEM_INLINE void CRFileClose(CRFile* file)
{
#ifndef WIN32 
	cr_file_unmap(&(file->fd), file->buffer);
#else
    //cr_file_unmap(file->mFile, file->buffer);
#endif
    
	cr_file_close(file->fd);
}
