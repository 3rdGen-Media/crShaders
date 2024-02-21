
#include "crSystem/cr_file.h"

#include <stdlib.h>
#include <stdio.h>

#ifndef _WIN32
#define _mkdir(X) mkdir(X, 0700)
#include <assert.h>
#else
#include <direct.h> //_mkdir
#endif


static void ParseIncludeFile(CRFile* includeFile, FILE* outFile);
static void ParseSourceIncludeFiles(CRFile* sourceFile, FILE* outFile, char** lines, size_t* lineLengths, int nIncludes, size_t sourceFileDirLength);
static size_t ParseSourceFile(CRFile* sourceFile, const char* outDirPath);


//parse the includes of an include file
static void ParseIncludeFile(CRFile* includeFile, FILE* outFile)
{
    int     nIncludes = 0;
    char*   firstInclude = NULL;

    //vars to store #include lines and line lengths
    char** lines = NULL;
    int* lineLengths = NULL;

    // find first line starting with #include
    char* line = includeFile->buffer;

    //count additional lines starting with #include
    while (line && (line - includeFile->buffer) < includeFile->size - 1)// ((fgets(line, sizeof(line), file))
    {

        if (strncmp(line, "#include ", 9) == 0) //found an include line
        {
            nIncludes++;
        }

        line = strchr(line, '\n'); line += 1;
        if (line == '\r' && line + 1 == '\n') line += 2; //eat return carriages
    }

    //record the placement of each line starting with #include
    if (nIncludes >= 1)
    {
        lines = (char**)malloc(nIncludes * sizeof(char*));
        lineLengths = (size_t*)malloc(nIncludes * sizeof(size_t*));

        //iterate again to record pointers to lines starting with #include
        line = includeFile->buffer;
        nIncludes = 0;
        while (line && (line - includeFile->buffer) < includeFile->size - 1)// ((fgets(line, sizeof(line), file))
        {
            if (strncmp(line, "#include ", 9) == 0) //found an include line
            {
                lines[nIncludes] = line;

                line = strchr(line, '\n');
                lineLengths[nIncludes] = line - lines[nIncludes];
                nIncludes++;
            }
            else
            {
                line = strchr(line, '\n');
            }
            line += 1;

            if (line == '\r' && line + 1 == '\n') line += 2; //eat return carriages
        }
    }

    fprintf(stderr, "\nnSubincludes found = %d", nIncludes);
    
    //if (nIncludes > 0)
    //{
     //find the exact size of the strings we will need
     //so we can allocate memory on the stack
    size_t includeFileNameLength;
    size_t includeFileDirLength;
    size_t includeFilePathLength = strlen(includeFile->path);
    //char outFilePath[1024] = "\0";// outDirPath;

    //find the last slash in the file, so we can remove the file component
    includeFileDirLength = includeFilePathLength - 1;
#ifndef _WIN32
    if (strchr(includeFile->path, '/')) while (includeFile->path[includeFileDirLength] != '/')  includeFileDirLength--;
    else assert(1==0);
#else
    if (strchr(includeFile->path, '\\')) { while (includeFile->path[includeFileDirLength] != '\\') includeFileDirLength--; }
    else if (strchr(includeFile->path, '//')) { while (includeFile->path[includeFileDirLength] != '/')  includeFileDirLength--; }
    else   { fprintf(stderr, "\nUnable to detect path slash format"); /*strncat(outFilePath, "./", 2);*/ includeFileDirLength = -1; }
#endif
    includeFileDirLength++; //advance past the slash, we want to keep it

    includeFileNameLength = includeFilePathLength - includeFileDirLength;
    //fprintf(stderr, "\nincludeFileDirLength  = %lld", includeFileDirLength);
    //fprintf(stderr, "\nincludeFilePathLength = %lld", includeFilePathLength);

    /*
    //build path to output file on disk
    if (!includeFile)
    {
        if (includeFileDirLength > 0) strncat(outFilePath, includeFile->path, includeFileDirLength);
        strncat(outFilePath, "preprocessed/", strlen("preprocessed/"));

        if (_mkdir(outFilePath) < 0)
        {
            if (errno != EEXIST)
            {
                fprintf(stderr, "\nFailed to create directory: %s", outFilePath);
                assert(1 == 0);
                goto CLEANUP;
            }
        }

        strncat(outFilePath, includeFile->path + sourceFileDirLength, includeFileNameLength);
        fprintf(stderr, "\noutput path = %s", outFilePath);
    }

    // open the file for writing
    FILE* outFile = fopen(outFilePath, "wb");
    assert(outFile);
    */

    //write sourceFile bytes up to the first include line
    if (lines) fwrite(includeFile->buffer, lines[0] - includeFile->buffer, 1, outFile);
    else      {fwrite(includeFile->buffer, includeFile->size, 1, outFile); /*fwrite("\0", 1, 1, outFile);*/ };

    ParseSourceIncludeFiles(includeFile, outFile, lines, lineLengths, nIncludes, includeFileDirLength);

    //write sourceFile bytes after last #include line to end of file
    if (lines)
    {
        char* endOfLastLine = lines[nIncludes - 1] + lineLengths[nIncludes - 1];
        fwrite(endOfLastLine, (includeFile->buffer + includeFile->size) - endOfLastLine, 1, outFile);
    }

    /* close the output file*/
    //fclose(outFile);
    //}

    //fprintf(stderr, "%s", sourceFile.buffer);
    fprintf(stderr, "\n\n");

CLEANUP:
    if (lines)       free(lines);
    if (lineLengths) free(lineLengths);

    return;
}



//parse bottom level source file includes
static void ParseSourceIncludeFiles(CRFile* sourceFile, FILE * outFile, char ** lines, size_t* lineLengths, int nIncludes, size_t sourceFileDirLength)
{
    //iterate #include lines and load each file to a string to replace the line
    int n; for (n = 0; n < nIncludes; n++)
    {
        size_t lineLength = lineLengths[n];
        //fprintf(stderr, "\n\n%.*s", lineLength, lines[n]);

        char* includeFileName = lines[n] + strlen("#include ");
        includeFileName = strchr(includeFileName, '\"'); includeFileName += 1;
        char* includeFileNameEnd = strchr(includeFileName, '\"');

        //prepare path to include file relative to sourceShaderPath
        char includeShaderPath[1024] = "\0";
        strncat(includeShaderPath, sourceFile->path, sourceFileDirLength);
        strncat(includeShaderPath, includeFileName, includeFileNameEnd - includeFileName);
        includeShaderPath[sourceFileDirLength + (includeFileNameEnd - includeFileName)] = '\0';
        //fprintf(stderr, "\n\nInclude Path (%lld) %.*s", sourceFileDirLength, (int)sourceFileDirLength, includeShaderPath);
        fprintf(stderr, "\n\nInclude Path %s", includeShaderPath);


        //load the entire include file to string
        CRFile includeFile;
        includeFile.fd   = cr_file_open(includeShaderPath);
        includeFile.size = cr_file_size(includeFile.fd);
        includeFile.path = includeShaderPath;
#ifndef _WIN32
        includeFile.buffer = cr_file_map_to_buffer(&(includeFile.buffer), includeFile.size, PROT_READ, MAP_SHARED | MAP_NORESERVE, includeFile.fd, 0);
        if (madvise(includeFile.buffer, (size_t)includeFile.size, MADV_SEQUENTIAL | MADV_WILLNEED) == -1) {
            printf("\nread madvise failed\n");
        }
#else
        includeFile.mFile = cr_file_map_to_buffer(&(includeFile.buffer), includeFile.size, PROT_READ, MAP_SHARED | MAP_NORESERVE, includeFile.fd, 0);
#endif

        ParseIncludeFile(&includeFile, outFile);

        CRFileClose(&(includeFile));
    }

}


static size_t ParseSourceFile(CRFile * sourceFile, const char* outDirPath)
{
    int     nIncludes = 0;
    char* firstInclude = NULL;

    //vars to store #include lines and line lengths
    char** lines = NULL;
    int* lineLengths = NULL;

    // find first line starting with #include
    char* line = sourceFile->buffer;

    //count additional lines starting with #include
    while (line && (line - sourceFile->buffer) < sourceFile->size - 1)// ((fgets(line, sizeof(line), file))
    {

        if (strncmp(line, "#include ", 9) == 0) //found a vertex line
        {
            nIncludes++;
        }

        line = strchr(line, '\n'); line += 1;
        if (line == '\r' && line + 1 == '\n') line += 2; //eat return carriages
    }

    //record the placement of each line starting with #include
    if (nIncludes >= 1)
    {
        lines = (char**)malloc(nIncludes * sizeof(char*));
        lineLengths = (size_t*)malloc(nIncludes * sizeof(size_t*));

        //iterate again to record pointers to lines starting with #include
        line = sourceFile->buffer;
        nIncludes = 0;
        while (line && (line - sourceFile->buffer) < sourceFile->size - 1)// ((fgets(line, sizeof(line), file))
        {
            if (strncmp(line, "#include ", 9) == 0) //found a vertex line
            {
                lines[nIncludes] = line;

                line = strchr(line, '\n');
                lineLengths[nIncludes] = line - lines[nIncludes];
                nIncludes++;
            }
            else
            {
                line = strchr(line, '\n');
            }
            line += 1;

            if (line == '\r' && line + 1 == '\n') line += 2; //eat return carriages
        }
    }
    //else lines[0] = sourceFile.buffer + sourceFile.size;  //prepare for copy below

    //fprintf(stderr, "\nnIncludes found = %d", nIncludes);

    //if (nIncludes > 0)
    //{
     //find the exact size of the strings we will need
     //so we can allocate memory on the stack
    size_t sourceFileNameLength;
    size_t sourceFileDirLength;
    size_t sourceFilePathLength = strlen(sourceFile->path);
    char outFilePath[1024] = "\0";// outDirPath;

    //find the last slash in the file, so we can remove the file component
    sourceFileDirLength = sourceFilePathLength - 1;
#ifndef _WIN32
    if (strchr(sourceFile->path, '/')) while (sourceFile->path[sourceFileDirLength] != '/')  sourceFileDirLength--;
    else assert(1==0);
#else
    if (strchr(sourceFile->path, '\\')) { while (sourceFile->path[sourceFileDirLength] != '\\') sourceFileDirLength--; }
    else if (strchr(sourceFile->path, '//')) { while (sourceFile->path[sourceFileDirLength] != '/')  sourceFileDirLength--; }
    else { fprintf(stderr, "\nUnable to detect path slash format"); strncat(outFilePath, "./", 2); sourceFileDirLength = -1; }
#endif
    sourceFileDirLength++; //advance past the slash, we want to keep it

    sourceFileNameLength = sourceFilePathLength - sourceFileDirLength;
    fprintf(stderr, "\nsourceFileDirLength  = %lld", sourceFileDirLength);
    fprintf(stderr, "\nsourceFilePathLength = %lld", sourceFilePathLength);


    //build path to output file on disk
    if (!outDirPath)
    {
        if (sourceFileDirLength > 0) strncat(outFilePath, sourceFile->path, sourceFileDirLength);
        strncat(outFilePath, "preprocessed/", strlen("preprocessed/"));

        if (_mkdir(outFilePath) < 0)
        {
            if (errno != EEXIST)
            {
                fprintf(stderr, "\nFailed to create directory: %s", outFilePath);
                assert(1 == 0);
                goto CLEANUP;
            }
        }

        strncat(outFilePath, sourceFile->path + sourceFileDirLength, sourceFileNameLength);
        fprintf(stderr, "\noutput path = %s", outFilePath);
    }

    /* open the file for writing*/
    FILE* outFile = fopen(outFilePath, "wb");
    assert(outFile);

    //write sourceFile bytes up to the first include line
    if (lines) fwrite(sourceFile->buffer, lines[0] - sourceFile->buffer, 1, outFile);
    else      {fwrite(sourceFile->buffer, sourceFile->size, 1, outFile); /*fwrite("\0", 1, 1, outFile);*/ };

    ParseSourceIncludeFiles(sourceFile, outFile, lines, lineLengths, nIncludes, sourceFileDirLength);

    //write sourceFile bytes after last #include line to end of file
    if (lines)
    {
        char* endOfLastLine = lines[nIncludes - 1] + lineLengths[nIncludes - 1];
        fwrite(endOfLastLine, (sourceFile->buffer + sourceFile->size) - endOfLastLine, 1, outFile);
    }

    /* close the output file*/
    fclose(outFile);
    //}

    //fprintf(stderr, "%s", sourceFile.buffer);
    fprintf(stderr, "\n\n");

CLEANUP:
    if (lines)       free(lines);
    if (lineLengths) free(lineLengths);

    return sourceFileDirLength;
}

int main(int argc, const char* argv[]) 
{
    size_t sourceFileDirLength = 0;
    const char* sourceShaderPath = NULL;
    const char* outDirPath = NULL;
    
    assert(argc > 1);
    int i; for(i=1; i<argc; i++ )
    {
        CRFile sourceFile;
        
        char  *pwd = "./";
        //arguments contain path to source shader to be preprocessed
        sourceShaderPath = argv[i]; //use base 10, don't retrieve ptr after the converted integer value
        //outputDirPath    = argv[2]; //use base 10, don't retrieve ptr after the converted integer value
        
        //read the file with mmap
        sourceFile.fd = cr_file_open(sourceShaderPath);
        sourceFile.size = cr_file_size(sourceFile.fd);
        sourceFile.path = sourceShaderPath;
        //2 MAP THE FILE TO BUFFER FOR READING
#ifndef _WIN32
        sourceFile.buffer = cr_file_map_to_buffer(&(sourceFile.buffer), sourceFile.size, PROT_READ, MAP_SHARED | MAP_NORESERVE, sourceFile.fd, 0);
        if (madvise(sourceFile.buffer, (size_t)sourceFile.size, MADV_SEQUENTIAL | MADV_WILLNEED) == -1) {
            printf("\nread madvise failed\n");
        }
#else
        sourceFile.mFile = cr_file_map_to_buffer(&(sourceFile.buffer), sourceFile.size, PROT_READ, MAP_SHARED | MAP_NORESERVE, sourceFile.fd, 0);
#endif
        
        sourceFileDirLength = ParseSourceFile(&sourceFile, outDirPath);
        
        //Cleanup
        CRFileClose(&sourceFile);
    }
    
    //Run the OS script that will copy preprocessed glsl files to their install location
#ifndef _WIN32
    //Open a command line process with file pointer for reading command line output

    char scriptFileDir[256] = "";
    char scriptFileCommand[256] = "sh ";
    if (sourceFileDirLength > 0) 
    {
        strncat(scriptFileDir, sourceShaderPath, sourceFileDirLength);
        strncat(scriptFileCommand, sourceShaderPath, sourceFileDirLength);
        chdir(scriptFileDir); //change pwd for the script
    }
    strncat(scriptFileCommand, "PreprocessGLSL.sh", strlen("PreprocessGLSL.sh"));
    
    //int status = 0;
    //pid_t wpid = 0;
    pid_t pid = fork();
    
    /* this block now runs on the child process after forking */
    if (pid == 0)
    {
        //start child process that will run script via forked process space
        char * args[] = {scriptFileCommand, NULL, NULL};
        execv(scriptFileCommand, args);
        exit(0); /* Closes child */
        
    }else if (pid > 0)
    {
        //start child process that will run script via parent process space
        FILE *fp = popen(scriptFileCommand, "r");
        if (fp == NULL) 
        {
            fprintf(stderr, "\nRun script failed!\n");
            assert(1==0);
        }
    }
    else
    {
        fprintf(stderr, "\nfork failed!\n");
        assert(1==0);
    }
    
    //while ((wpid = wait(&status)) > 0); // this way, the father waits for all the child processes

#endif
    return 0;
}
