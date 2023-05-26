ffi = require("ffi")
bit = require("bit")

local t = {}
local cuik_dll = ffi.load(ffi.os == "Windows" and "cuik.dll" or "cuik.so")

ffi.cdef[[
typedef struct Cuik_CPP Cuik_CPP;
typedef struct Cuik_Parser Cuik_Parser;
typedef struct Cuik_Linker Cuik_Linker;
typedef struct Cuik_Target Cuik_Target;
typedef struct Cuik_DriverArgs Cuik_DriverArgs;
typedef struct Cuik_Diagnostics Cuik_Diagnostics;
typedef struct Cuik_IThreadpool Cuik_IThreadpool;

typedef struct TB_Module TB_Module;
typedef struct TB_Symbol TB_Symbol;
typedef struct TB_Function TB_Function;
typedef struct TB_JITContext TB_JITContext;

typedef struct Stmt Stmt;

typedef struct {
    uint16_t length;
    char data[260];
} Cuik_Path;

// These are your options for arguments in diagnostics
typedef enum {
    DIAG_NOTE,
    DIAG_WARN,
    DIAG_ERR,
} DiagType;

typedef void (*Cuik_DiagCallback)(Cuik_Diagnostics* diag, void* userdata, DiagType type);

typedef enum Cuik_Version {
    // C language
    CUIK_VERSION_C89,
    CUIK_VERSION_C99,
    CUIK_VERSION_C11,
    CUIK_VERSION_C23,

    // GL shading language
    CUIK_VERSION_GLSL,
} Cuik_Version;

typedef enum TB_OutputFlavor {
    TB_FLAVOR_OBJECT,     // .o  .obj
    TB_FLAVOR_ASSEMBLY,   // .s  .asm
    TB_FLAVOR_SHARED,     // .so .dll
    TB_FLAVOR_STATIC,     // .a  .lib
    TB_FLAVOR_EXECUTABLE, //     .exe
} TB_OutputFlavor;

typedef struct Cuik_Toolchain {
    // we expect this to be heap allocated because cuik_toolchain_free
    void* ctx;

    void(*add_libraries)(void* ctx, const Cuik_DriverArgs* args, Cuik_Linker* linker);
    void(*set_preprocessor)(void* ctx, const Cuik_DriverArgs* args, Cuik_CPP* cpp);

    bool(*invoke_link)(void* ctx, const Cuik_DriverArgs* args, Cuik_Linker* linker, const char* output, const char* filename);
} Cuik_Toolchain;

struct Cuik_DriverArgs {
    Cuik_Version version;
    TB_OutputFlavor flavor;

    Cuik_Target* target;
    Cuik_Toolchain toolchain;

    int threads, opt_level;
    const char* output_name;
    const char* entrypoint;

    void* diag_userdata;
    Cuik_DiagCallback diag_callback;

    Cuik_Path** sources;
    Cuik_Path** includes;
    Cuik_Path** libraries;
    char** defines;

    int subsystem;

    bool ir              : 1;
    bool emit_ir         : 1;
    bool ast             : 1;
    bool run             : 1;
    bool bake            : 1;
    bool nocrt           : 1;
    bool live            : 1;
    bool time            : 1;
    bool verbose         : 1;
    bool syntax_only     : 1;
    bool test_preproc    : 1;
    bool debug_info      : 1;
    bool preprocess      : 1;
    bool think           : 1;
    bool based           : 1;

    bool preserve_ast    : 1;
};

typedef struct String {
    size_t length;
    const unsigned char* data;
} String;

typedef struct SourceLoc {
    uint32_t raw;
} SourceLoc;

typedef struct SourceRange {
    SourceLoc start, end;
} SourceRange;

// This is what FileIDs refer to
typedef struct {
    const char* filename;
    bool is_system;

    int depth;
    SourceLoc include_site;
    // describes how far from the start of the file we are.
    // used by line_map on big files
    uint32_t file_pos_bias;

    // NOTE: this is the size of this file chunk, big files consist
    // of multiple chunks so you should use...
    //
    // TODO(NeGate): make function for doing this
    uint32_t content_length;
    const char* content;

    // a DynArray(uint32_t) sorted to make it possible to binary search
    //   [line] = file_pos
    uint32_t* line_map;
} Cuik_File;

typedef struct Token {
    // it's a TknType but GCC doesn't like incomplete enums
    int type     : 30;
    int expanded : 1;
    int hit_line : 1;

    SourceLoc location;
    String content;
} Token;

// This is what MacroIDs refer to
typedef struct MacroInvoke {
    String name;

    // 0 means it's got no parent
    uint32_t parent;

    SourceRange def_site;
    SourceLoc call_site;
} MacroInvoke;

typedef struct TokenArray {
    // DynArray(Token)
    struct Token* tokens;
    size_t current;
} TokenArray;

typedef struct TokenStream {
    const char* filepath;
    TokenArray list;

    Cuik_Diagnostics* diag;

    // if true, the preprocessor is allowed to delete after completion.
    // this shouldn't enabled when caching files
    bool is_owned;

    // DynArray(MacroInvoke)
    MacroInvoke* invokes;

    // DynArray(Cuik_File)
    Cuik_File* files;
} TokenStream;

// This is generated from
//    #pragma comment(lib, "somelib.lib")
typedef struct Cuik_ImportRequest {
    struct Cuik_ImportRequest* next;
    const char* lib_name;
} Cuik_ImportRequest;

typedef struct TranslationUnit TranslationUnit;
typedef struct CompilationUnit CompilationUnit;

typedef struct Cuik_ParseResult {
    int error_count;

    TranslationUnit* tu;         // if error_count == 0, then tu is a valid TU.
    Cuik_ImportRequest* imports; // linked list of imported libs.
} Cuik_ParseResult;

typedef enum TB_FeatureSet_X64 {
    TB_FEATURE_X64_SSE3   = (1u << 0u),
    TB_FEATURE_X64_SSE41  = (1u << 1u),
    TB_FEATURE_X64_SSE42  = (1u << 2u),

    TB_FEATURE_X64_POPCNT = (1u << 3u),
    TB_FEATURE_X64_LZCNT  = (1u << 4u),

    TB_FEATURE_X64_CLMUL  = (1u << 5u),
    TB_FEATURE_X64_F16C   = (1u << 6u),

    TB_FEATURE_X64_BMI1   = (1u << 7u),
    TB_FEATURE_X64_BMI2   = (1u << 8u),

    TB_FEATURE_X64_AVX    = (1u << 9u),
    TB_FEATURE_X64_AVX2   = (1u << 10u),
} TB_FeatureSet_X64;

typedef struct TB_FeatureSet {
    TB_FeatureSet_X64 x64;
} TB_FeatureSet;

typedef enum TB_ISelMode {
    // FastISel
    TB_ISEL_FAST,
    TB_ISEL_COMPLEX
} TB_ISelMode;

typedef char* Atom;
typedef struct Expr Expr;
typedef struct Cuik_Type Cuik_Type;

typedef struct Cuik_QualType {
    uintptr_t raw;
} Cuik_QualType;

typedef enum Cuik_TypeKind {
    KIND_VOID,
    KIND_BOOL,
    KIND_CHAR,
    KIND_SHORT,
    KIND_INT,
    KIND_ENUM,
    KIND_LONG,
    KIND_LLONG,
    KIND_FLOAT,
    KIND_DOUBLE,
    KIND_PTR,
    KIND_FUNC,
    KIND_ARRAY,
    KIND_VLA, // variable-length array
    KIND_STRUCT,
    KIND_UNION,
    KIND_VECTOR,

    // used when the type isn't resolved so we shouldn't clone it just yet
    KIND_CLONE,

    // these are inferred as typedefs but don't map to anything yet
    KIND_PLACEHOLDER,

    // weird typeof(expr) type that gets resolved in the semantics pass
    // this is done to enable typeof to work with out of order decls...
    // it's a mess but it's worth it
    KIND_TYPEOF
} Cuik_TypeKind;

// Used by unions and structs
typedef struct {
    Cuik_QualType type;
    Atom name;

    SourceRange loc;
    int align;
    int offset;

    // Bitfield
    int bit_offset;
    int bit_width;
    bool is_bitfield;
} Member;

typedef struct {
    bool is_static  : 1;
    bool is_typedef : 1;
    bool is_inline  : 1;
    bool is_extern  : 1;
    bool is_tls     : 1;

    // NOTE(NeGate): In all honesty, this should probably not be
    // here since it's used in cases that aren't relevant to attribs.
    // mainly STMT_DECL, it keeps track of if anyone's referenced it
    // so we can garbage collect the symbol later.
    bool is_root : 1;
    bool is_used : 1;
} Attribs;

typedef struct {
    Atom key;

    // lexer_pos is non-zero if the enum value has it's compilation delayed
    int lexer_pos;
    int value;
} EnumEntry;

typedef struct {
    Cuik_QualType type;
    Atom name;
} Param;

typedef enum {
    // used by cycle checking
    CUIK_TYPE_FLAG_COMPLETE = 1,
    CUIK_TYPE_FLAG_PROGRESS = 2,
} Cuik_TypeFlags;

struct Cuik_Type {
    Cuik_TypeKind kind;
    int size;  // sizeof
    int align; // _Alignof
    Cuik_TypeFlags flags;
    SourceRange loc;

    Atom also_known_as;
    void* user_data;

    union {
        char _;

        // Integers
        bool is_unsigned;

        // Arrays
        struct {
            Cuik_QualType of;
            int count;

            // if non-zero, then we must execute an expression
            // parser to resolve it
            int count_lexer_pos;
        } array;

        struct {
            Cuik_Type* of;
        } clone;

        // Pointers
        struct {
            Cuik_QualType ptr_to;
        };

        // Function
        struct {
            Atom name;
            Cuik_QualType return_type;

            size_t param_count;
            Param* param_list;

            bool has_varargs : 1;
        } func;

        // Structs/Unions
        struct Cuik_TypeRecord {
            Atom name;

            int kid_count, pad;
            Member* kids;

            // this is the one used in type comparisons
            Cuik_Type* nominal;
        } record;

        // Enumerators
        struct {
            Atom name;
            int count, pad;

            EnumEntry* entries;
        } enumerator;

        struct {
            Cuik_Type* base;
            int count, pad;
        } vector;

        // Typeof
        struct {
            Expr* src;
        } typeof_;

        struct {
            Atom name;

            // if non-NULL we've got a linked list to walk :)
            Cuik_Type* next;
        } placeholder;
    };
};

typedef struct ArenaSegment ArenaSegment;
typedef struct {
    struct ArenaSegment* base;
    struct ArenaSegment* top;
} Arena;

void cuik_init(bool use_crash_handler);

// driver
Cuik_Target* cuik_target_host(void);
Cuik_Toolchain cuik_toolchain_host(void);

// preprocessor
Cuik_CPP* cuik_driver_preprocess(const char* filepath, const Cuik_DriverArgs* args, bool should_finalize);
Cuik_CPP* cuik_driver_preprocess_cstr(const char* source, const Cuik_DriverArgs* args, bool should_finalize);
TokenStream* cuikpp_get_token_stream(Cuik_CPP* ctx);
void cuiklex_free_tokens(TokenStream* tokens);
void cuikdg_dump_to_stderr(TokenStream* tokens);
void cuikpp_dump_tokens(TokenStream* tokens);

// parser
Cuik_ParseResult cuikparse_run(Cuik_Version version, TokenStream* restrict s, Cuik_Target* target, Arena* arena, bool only_code_index);
int cuiksema_run(TranslationUnit* tu, Cuik_IThreadpool* thread_pool);

Stmt** cuik_get_top_level_stmts(TranslationUnit* tu);
size_t cuik_num_of_top_level_stmts(TranslationUnit* tu);
const char* cuik_stmt_decl_name(Stmt* stmt);
Cuik_QualType cuik_stmt_decl_type(Stmt* stmt);

// irgen
void cuikcg_allocate_ir2(TranslationUnit* tu, TB_Module* m);
TB_Symbol* cuikcg_top_level(TranslationUnit* tu, TB_Module* m, Stmt* restrict s);
void cuik_add_to_compilation_unit(CompilationUnit* cu, TranslationUnit* tu);
void cuik_compilation_unit_set_tb_module(CompilationUnit* restrict cu, TB_Module* mod);

CompilationUnit* cuik_create_compilation_unit(void);
void cuikcg_allocate_ir2(TranslationUnit* tu, TB_Module* m);

// tb
TB_Module* tb_module_create_for_host(const TB_FeatureSet* features, bool is_jit);
bool tb_module_compile_function(TB_Module* m, TB_Function* f, TB_ISelMode isel_mode);

// passing 0 to jit_heap_capacity will default to 4MiB
TB_JITContext* tb_module_begin_jit(TB_Module* m, size_t jit_heap_capacity);
void* tb_module_apply_function(TB_JITContext* jit, TB_Function* f);
TB_Function* tb_symbol_as_function(TB_Symbol* s);

// fixes page permissions, applies missing relocations
void tb_module_ready_jit(TB_JITContext* jit);
void tb_module_end_jit(TB_JITContext* jit);
]]

cuik_dll.cuik_init(false)

t.args = ffi.new("Cuik_DriverArgs", {
	version = cuik_dll.CUIK_VERSION_C23,
	target = cuik_dll.cuik_target_host(),
	toolchain = cuik_dll.cuik_toolchain_host(),
	flavor = cuik_dll.TB_FLAVOR_EXECUTABLE,
})

-- make TB module
local features = ffi.new("TB_FeatureSet", {})
tb_module = cuik_dll.tb_module_create_for_host(features, true)

local function canonical(t)
	return ffi.cast("Cuik_Type*", bit.band(t.raw, bit.bnot(15ULL)))
end

local primitive_names = {}
local function prim(a, b) primitive_names[tonumber(a)] = b end

prim(cuik_dll.KIND_VOID,  "void")
prim(cuik_dll.KIND_BOOL,  "bool")
prim(cuik_dll.KIND_CHAR,  "char")
prim(cuik_dll.KIND_SHORT, "short")
prim(cuik_dll.KIND_INT,   "int")
prim(cuik_dll.KIND_LONG,  "long")
prim(cuik_dll.KIND_LLONG, "long long")
prim(cuik_dll.KIND_FLOAT, "float")
prim(cuik_dll.KIND_DOUBLE,"double")

local function qual_str(q)
	local str = ""
	if bit.band(q.raw, 1ULL) ~= 0ULL then str = str.." const" end
	return str
end

local function type_string(qt, name)
	local t = canonical(qt)
	local p = primitive_names[tonumber(t.kind)]
	if p ~= nil then
		if bit.band(qt.raw, 15ULL) ~= 0ULL then
			return p..qual_str(qt)
		else
			return p
		end
	end

	if t.kind == cuik_dll.KIND_PTR then
		return type_string(t.ptr_to).."*"
	elseif t.kind == cuik_dll.KIND_FUNC then
		local str = type_string(t.func.return_type).." "..name.."("
		local param_count = tonumber(t.func.param_count)
		local params = t.func.param_list

		for i=0,param_count-1 do
			if i ~= 0 then
				str = str..", "
			end

			str = str..type_string(params[i].type)
		end
		return str..")"
	end

	return "fuck"
end

local function compile_internal(cpp)
	if not cpp then
		print("Yikes... preprocessing failed!")
		return nil
	end

	local cu = cuik_dll.cuik_create_compilation_unit()
	cuik_dll.cuik_compilation_unit_set_tb_module(cu, tb_module)

	-- parse into AST
	local tokens = cuik_dll.cuikpp_get_token_stream(cpp)
	-- cuik_dll.cuikpp_dump_tokens(tokens)

	local arena = ffi.new("Arena", {})
	local parse_result = cuik_dll.cuikparse_run(t.args.version, tokens, t.args.target, arena, false)
	if parse_result.error_count > 0 then
		cuik_dll.cuikdg_dump_to_stderr(tokens)
		print("Yikes... parsing failed!")
		return nil
	end

	local tu = parse_result.tu
	if cuik_dll.cuiksema_run(tu, nil) > 0 then
	    cuik_dll.cuikdg_dump_to_stderr(tokens)
		print("Yikes... type checking failed!")
		return nil
	end

    cuik_dll.cuik_add_to_compilation_unit(cu, tu)

	-- IR gen & compile
	cuik_dll.cuikcg_allocate_ir2(tu, tb_module)

	local stmt_count = tonumber(ffi.cast("uint32_t", cuik_dll.cuik_num_of_top_level_stmts(tu)))
	local stmts = cuik_dll.cuik_get_top_level_stmts(tu)

	local symbols = {}
	for i=0,stmt_count-1 do
		local sym = cuik_dll.cuikcg_top_level(tu, tb_module, stmts[i])

		if cuik_dll.tb_symbol_as_function(sym) ~= nil then
			cuik_dll.tb_module_compile_function(tb_module, ffi.cast("TB_Function*", sym), cuik_dll.TB_ISEL_FAST)
			symbols[i] = sym
		end
	end

	ffi.cdef[[
		// used when i can't figure out the type :P
		typedef void fuck;
	]]

	-- export JITted functions
	local result = {}
	local jit = cuik_dll.tb_module_begin_jit(mod, 0)
	for i=0,stmt_count-1 do
		local n = cuik_dll.cuik_stmt_decl_name(stmts[i])

		if symbols[i] ~= nil then
			local name = ffi.string(n)

			local t = cuik_dll.cuik_stmt_decl_type(stmts[i])
			local desc = "typedef "..type_string(t, "FN_"..name)..";\n"

			ffi.cdef(desc)

			local addr = cuik_dll.tb_module_apply_function(jit, ffi.cast("TB_Function*", symbols[i]))
			result[name] = ffi.cast("FN_"..name.."*", addr)
		end
	end

	cuik_dll.tb_module_ready_jit(jit)
	return result
end

function t.compile(source)
	return compile_internal(cuik_dll.cuik_driver_preprocess_cstr(source, t.args, true))
end

function t.compile_file(path)
	return compile_internal(cuik_dll.cuik_driver_preprocess(path, t.args, true))
end

return t
