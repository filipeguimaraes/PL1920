%{
#include <stdio.h>
#include <string.h>

#include "storedata.h"

char * type = NULL;

STOREDATA global_table    = NULL;
STOREDATA table_in_use    = NULL;
STOREDATA in_line_table   = NULL;

GPtrArray * inline_stack  = NULL;

int parsing_InLineTable   = 0;
int parsing_Table         = 0;

extern void asprintf();
extern int yylex();
extern int yylineno;
extern char *yytext;


char * take_of_under_score (char * s);
int yyerror();
int erroSem(char*);
%}

%union{
    char * string_value;
    gpointer pointer;
    STOREDATA store_data;
}


%token OPEN_LIST    // '['
%token CLOSE_LIST   // ']'


%token OPEN_IN_LINE_TABLE   // '{'
%token CLOSE_IN_LINE_TABLE  // '}'


%token OPEN_TABLE   // '['
%token CLOSE_TABLE  // ']'


%token OPEN_ARRAY_OF_TABLES     // '[['
%token CLOSE_ARRAY_OF_TABLES    // ']]'


%token KEY_EQ_VALUE     // '='
%token KEY_TOKEN        // '.'
%token SEPARATE_VALUES  // ','


%token APOSTROPHE_TRI_OPEN  // '''
%token APOSTROPHE_TRI_CLOSE // '''


%token QUOTE_TRI_OPEN   // """
%token QUOTE_TRI_CLOSE  // """


%token APOSTROPHE_OPEN  // '
%token APOSTROPHE_CLOSE // '


%token QUOTE_OPEN   // "
%token QUOTE_CLOSE  // "


%token END // <<EOF>>


%token <string_value>
    undifined_numeric
    apostrophe_char
    hex_numeric
    oct_numeric
    bin_numeric
    string_key
    quote_char
    boolean
    integer
    yyfloat
    date


%type <pointer>
    InLineTable
    InLinable
    Listable
    Value
    List
    Pair

%type <store_data>
    DottedKey
    Key

%type <string_value>
    ApostropheString
    QuoteString
    KeyString 
    Numeric
    String

%%

S :
    { 
        global_table = store_data_new_table("global"); 
        table_in_use = global_table; 
        inline_stack = g_ptr_array_new();
    } 
      Sequence END 
    {
        if (type && !strcmp("-xml",type))print_2_XML(global_table);
        else print_2_JSON(global_table);
        return 0; 
    }
;


Sequence
    : Sequence Sequenciable
    | Sequenciable
;


Sequenciable
    : Pair
    | Table
    | ArrayOfTables
;


Table
    : { 
        table_in_use = global_table;
        parsing_Table = 1;
    }
    OPEN_TABLE Key CLOSE_TABLE 
    {
        table_in_use = $3;
        if (store_data_get_type($3) == 'v') {
            store_data_set_data($3,g_hash_table_new(g_str_hash,g_str_equal));
            store_data_set_type($3,'h');
        }

        parsing_Table = 0;
    }
;


ArrayOfTables
    : { 
        table_in_use = global_table;
        parsing_Table = 1;
    } 
    OPEN_ARRAY_OF_TABLES Key CLOSE_ARRAY_OF_TABLES
    {
        if (store_data_get_type($3) != 'a') {
            store_data_set_data($3,g_ptr_array_new());
            store_data_set_type($3,'a');
        }
        
        STOREDATA s = store_data_new_table("");
        store_data_add_value($3,s);

        table_in_use = s;
        parsing_Table = 0;
    }
;


InLineTable
    : OPEN_IN_LINE_TABLE InLinable CLOSE_IN_LINE_TABLE { 
        $$ = $2;
        parsing_InLineTable--;
        if (parsing_InLineTable > 0) in_line_table = g_ptr_array_index(inline_stack,parsing_InLineTable-1);
    }
;


InLinable
    : {
        in_line_table = store_data_new_table("");
        g_ptr_array_insert(inline_stack, parsing_InLineTable, in_line_table); 
        parsing_InLineTable++;
    } 
    Pair 
    { 
        $$ = g_ptr_array_index(inline_stack,parsing_InLineTable-1); 
    }
    | InLinable SEPARATE_VALUES Pair { $$ = $1; }
;


List
    : OPEN_LIST Listable CLOSE_LIST { $$ = $2; }
;


Listable
    : Value { 
        STOREDATA s = store_data_new_array(""); 
        store_data_add_value(s,$1);
        $$ = s;
    }
    | Listable SEPARATE_VALUES Value { store_data_add_value($1,$3); $$ = $1; }
    | Listable SEPARATE_VALUES       { $$ = $1; }
;


Pair
    : Key KEY_EQ_VALUE Value {
        if (store_data_get_type($1) == 'v') {
            store_data_set_key($3,store_data_get_key($1));
            store_data_add_value($1,$3);
        }

        $$ = $1;
    }
;


Key
    : DottedKey KeyString { $$ = store_data_next_key_value($1,$2); if (!$$) return erroSem("Key NULL");}
;


DottedKey
    : DottedKey KeyString KEY_TOKEN { $$ = store_data_next_key($1,$2); }
    | { 
        if (parsing_InLineTable > 0 && !parsing_Table) $$ = in_line_table;
        else $$ = table_in_use;
    }
;


KeyString
    : string_key                                        { asprintf(&$$,"%s",$1); }
    | APOSTROPHE_OPEN ApostropheString APOSTROPHE_CLOSE { asprintf(&$$,"%s",$2); }
    | QUOTE_OPEN QuoteString QUOTE_CLOSE                { asprintf(&$$,"%s",$2); }
;


Value
    : String        { $$ = store_data_new('s', "", $1); }
    | Numeric       { $$ = store_data_new('s', "", $1); }
    | boolean       { $$ = store_data_new('s', "", $1); }
    | date          { char * s; asprintf(&s,"\"%s\"",$1); $$ = store_data_new('s', "", s); }
    | List          { $$ = $1; }
    | InLineTable   { $$ = $1; }
;


String
    : APOSTROPHE_TRI_OPEN ApostropheString APOSTROPHE_TRI_CLOSE { asprintf(&$$,"\"%s\"",$2); }
    | QUOTE_TRI_OPEN QuoteString QUOTE_TRI_CLOSE                { asprintf(&$$,"\"%s\"",$2); }
    | APOSTROPHE_OPEN ApostropheString APOSTROPHE_CLOSE         { asprintf(&$$,"\"%s\"",$2); }
    | QUOTE_OPEN QuoteString QUOTE_CLOSE                        { asprintf(&$$,"\"%s\"",$2); }
;


ApostropheString
    : apostrophe_char                  { asprintf(&$$,"%s",$1); }
    | ApostropheString apostrophe_char { asprintf(&$$,"%s%s",$1,$2); }
;


QuoteString
    : quote_char             { asprintf(&$$,"%s",$1); }
    | QuoteString quote_char { asprintf(&$$,"%s%s",$1,$2); }
;


Numeric
    : yyfloat           { $$ = take_of_under_score( *$1 == '+' ? $1 + 1 : $1 ); }
    | integer           { $$ = take_of_under_score( *$1 == '+' ? $1 + 1 : $1 ); }
    | hex_numeric       { asprintf(&$$,"%ld",strtol(take_of_under_score($1+2),NULL,16)); }
    | oct_numeric       { asprintf(&$$,"%ld",strtol(take_of_under_score($1+2),NULL,8)); }
    | bin_numeric       { asprintf(&$$,"%ld",strtol(take_of_under_score($1+2),NULL,2)); }
    | undifined_numeric { asprintf(&$$,"\"%s\"",$1); }
;

%%

int main(int argc, char ** argv){
    if (argc > 1) type = argv[1];
    yyparse();
    return 0;
}

int erroSem(char *s){
    printf("Erro Semântico na linha: %d, %s...\n", yylineno, s);
    return 0;
}

int yyerror(){
    printf("Erro Sintático ou Léxico na linha: %d, com o texto: %s\n", yylineno, yytext);
    return 0;
}

char * take_of_under_score (char * s) {
    char * r = malloc(strlen(s));
    int i = 0, j = 0;
    
    while (s[i]) {
        if (s[i] != '_') r[j++] = s[i]; 
        i++;
    }
    r[j] = '\0';
    
    return r; 
}