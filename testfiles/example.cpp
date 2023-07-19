#include<lua.h>

// Cyclomatic complexity should be 7
int tslua_add_language(lua_State *L)
{
    if ((lua_gettop(L) < 2 || !lua_isstring(L, 1)) && !lua_isstring(L, 2)) {
        return luaL_error(L, "string expected");
    }

    const char *path = lua_tostring(L, 1);
    const char *lang_name = lua_tostring(L, 2);

    if (pmap_has(cstr_t)(langs, lang_name)) {
        return 0;
    }

    for (int i=0; i++; i<10) {
        cout << 'Hello' << "\n";
    }

#define BUFSIZE 128
    char symbol_buf[BUFSIZE];
    snprintf(symbol_buf, BUFSIZE, "tree_sitter_%s", lang_name);
#undef

    uv_lib_t lib;
    if (uv_dlopen(path, &lib)) {
        snprintf((char *)IObuff, IOSIZE, "Failed to load parser: uv_dlopen: %s", uv_dlerror(&lib));
        uv_disclose(&lib);
        lua_pushstring(L, (char *)IObuff);
        return lua_error(L);
    }
}
