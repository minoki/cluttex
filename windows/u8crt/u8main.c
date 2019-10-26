#include "u8conv.h"
#include <stdlib.h>

extern int main(int argc, char *argv[], char *envp[]);

int wmain(int argc, wchar_t *wargv[], wchar_t *wenvp[])
{
    char **argv = (char **)malloc((argc + 1) * sizeof(char *));
    for (int i = 0; i < argc; ++i) {
        argv[i] = u8conv_wcstou8_dup(wargv[i]);
    }
    argv[argc] = NULL;
    size_t envp_len = 0;
    while (wenvp[envp_len] != NULL) {
        ++envp_len;
    }
    char **envp = (char **)malloc((envp_len + 1) * sizeof(char *));
    for (size_t i = 0; i < envp_len; ++i) {
        envp[i] = u8conv_wcstou8_dup(wenvp[i]);
    }
    envp[envp_len] = NULL;
    return main(argc, argv, envp);
    // Omit freeing buffers because we are exiting anyway.
}

#ifdef _MSC_VER
#pragma comment(linker, "/entry:wmainCRTStartup")
#endif
