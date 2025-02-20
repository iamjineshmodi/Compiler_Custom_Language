%{
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int inVarDecl = 0;
int type = 0;
char* varName = NULL;
int inLoop = 0; // Track nesting level of control structures

struct symbol {
    char *name;
    char *type;
    int isDefined;
    struct symbol *next;
};

struct symbol *symbolTable = NULL;

const char* keywords[] = {
    "int", "char", "if", "else", "while", "for", "main", 
    "begin", "end", "print", "scan", "program", 
    "VarDecl", "inc", "dec", NULL 
};

bool CheckKeyword(const char* str);
struct symbol* lookupSymbol(char *name);
void insertSymbol(char *name, char *type);
int checkPrintAndScan(char* str);
int validateForLoop(const char* str);

int yywrap(void) {
    return 1;
}

bool CheckKeyword(const char* str) {
    for (int i = 0; keywords[i] != NULL; i++) {
        if (strcmp(keywords[i], str) == 0) {
            return true;
        }
    }
    return false;
}
%}

DIGIT       [0-9]
LETTER      [a-z]
ID          {LETTER}({LETTER}|{DIGIT}|_)*
CHAR        \'(\\?.)\'
STRING      \"([^\"]*)\"
OP          [\+ \- \* \/ %  <  > =]
WS          [ \t\n]+
COMMENT     \/\*([^*]|\*+[^*/])*\*+\/|\/\/.*
DECIMAL     \([1-9][0-9]*,[ ]*10\)
BINARY      \([0-1]+,[ ]*2\)
OCTAL       \([0-7]+,[ ]*8\)
VALID_TYPES (int|char)
RELOP       (>=|<=|<>|=|<|>)
INTEGER     {DECIMAL}|{BINARY}|{OCTAL}
EXPR        ({ID}|{INTEGER})([ ]*[\+\-\*\/%][ ]*({ID}|{INTEGER}))*

%%

{COMMENT}                         { }
{WS}                              { }
"begin"[ \t]+"program:"           { printf("TOKEN: BEGIN_PROGRAM\n"); }
"end"[ \t]+"program"              { printf("TOKEN: END_PROGRAM\n"); }
"begin"[ \t]+"VarDecl:"           { inVarDecl=1; printf("TOKEN: BEGIN_VARDECL\n"); }
"end"[ \t]+"VarDecl"              { inVarDecl=0; printf("TOKEN: END_VARDECL\n"); }

"if"[ ]*"("                       { 
    printf("TOKEN: IF_START\n");
    inLoop++;
}

"then"[ ]*"begin"                 { printf("TOKEN: THEN_BEGIN\n"); }

"else"[ ]*"begin"                 { 
    if (inLoop > 0) {
        printf("TOKEN: ELSE_BEGIN\n");
    } else {
        printf("ERROR: Unmatched else statement\n");
    }
}

"end"[ ]*";"                      {
    if (inLoop > 0) {
        inLoop--;
        printf("TOKEN: BLOCK_END\n");
    } else {
        printf("ERROR: Unmatched end statement\n");
    }
}

"for"[ ]*{ID}[ ]*":="            {inLoop++; printf("TOKEN: FOR_START: %s\n", yytext); }
"to"[ ]*{EXPR}                   { printf("TOKEN: TO: %s\n",yytext); }
"inc"[ ]*{INTEGER}               { printf("TOKEN: INCREMENT: %s\n", yytext); }
"dec"[ ]*{INTEGER}               { printf("TOKEN: DECREMENT: %s\n", yytext); }
"do"[ ]*"begin"                  { printf("TOKEN: DO_BEGIN\n"); }

"while"[ ]*"("                    { 
    printf("TOKEN: WHILE_START\n");
    inLoop++;
}

{RELOP}                           { printf("TOKEN: RELATIONAL_OPERATOR: %s\n", yytext); }
"("                               { if(inVarDecl) type = 0; printf("TOKEN: LEFT_PARENTHESIS\n"); }
","                               { if(inVarDecl) type = 1; printf("TOKEN: COMMA\n"); }
")"                               { if(inVarDecl) type = 0; printf("TOKEN: RIGHT_PARENTHESIS\n"); }
":="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
"+="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
"-="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
"*="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
"/="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
"%="                              { printf("TOKEN: ASSIGNMENT OPERATOR\n"); }
{ID}[ ]*(":="|"+="|"-="|"*="|"/="|"%=")[ ]*{EXPR}";" { 
    printf("TOKEN: ASSIGNMENT STATEMENT: %s\n",yytext);
}
{STRING}                          { printf("TOKEN: STRING: %s\n", yytext); }
{CHAR}                            { printf("TOKEN: CHAR: %s\n", yytext); }
{OP}                              { printf("TOKEN: OPERATOR: %s\n", yytext); }
{INTEGER}                         { printf("TOKEN: INTEGER: %s\n", yytext); }
{EXPR}                            { printf("TOKEN: EXPRESSION: %s\n", yytext); }
{ID}                              { 
                                    int underscoreCount = 0;
                                    for(int i = 0; yytext[i]; i++) {
                                        if(yytext[i] == '_') underscoreCount++;
                                    }
                                    
                                    if(underscoreCount > 1) {
                                        printf("ERROR: Invalid identifier '%s' - more than one underscore\n", yytext);
                                    } else if(CheckKeyword(yytext)) {
                                        if(type){
                                            printf("TOKEN: KEYWORD %s\n",yytext);
                                        }else{
                                            printf("ERROR: Keyword '%s' used as identifier\n", yytext);
                                        }
                                    } else {
                                        if(inVarDecl) {
                                            struct symbol *s = lookupSymbol(yytext);
                                            if(s && s->isDefined) {
                                                printf("ERROR: Variable '%s' already defined\n", yytext);
                                            } else {
                                                insertSymbol(yytext, NULL);
                                                printf("TOKEN: IDENTIFIER '%s'\n", yytext);
                                            }
                                        } else {
                                            struct symbol *s = lookupSymbol(yytext);
                                            if(!s) {
                                                printf("ERROR: Undefined variable '%s'\n", yytext);
                                            } else {
                                                printf("TOKEN: IDENTIFIER '%s'\n", yytext);
                                            }
                                        }
                                    }
                                }
[(){},;"@]                         { printf("TOKEN: SEPARATOR: %s\n", yytext); }
.                                  { printf("LEXICAL ERROR: Unexpected Character: %s\n", yytext); }

"print"[ ]*"("\".*\".*");"         {
    if(!checkPrintAndScan(yytext)) {
        printf("ERROR: Invalid print statement format\n");
    }else{
        printf("TOKEN: PRINT_STATEMENT: %s\n",yytext);
    } 
}

"scan"[ ]*"("\".*\".*");"          {
    if(!checkPrintAndScan(yytext)) {
        printf("ERROR: Invalid scan statement format\n");
    }else{
        printf("TOKEN: SCAN_STATEMENT: %s\n",yytext);
    } 
}

%%

int main() {
    FILE* infile = fopen("input.txt", "r");
    if (!infile) {
        printf("Error: Could not open input.txt\n");
        return 1;
    }
    yyin = infile;
    yylex();
    fclose(infile);
    return 0;
}

/* Rest of the helper functions remain the same */

int countArguments(char *str) {
    int count = 0;
    int inArg = 0;
    int inBrackets = 0;
    char *p = strchr(str, '"');  
    if(!p) return 0;
    p = strchr(p + 1, '"');  
    if(!p) return 0;
    p++;
    int zeroargs = 0;

    while(*p) {
    
        if(*p == '('){
            inBrackets=1;
            if(!inArg){
                inArg=1;
            }
        }else if(*p==')'){
            inBrackets=0;
            if(inBrackets==0&&inArg){
                //count++;
                inArg=0;
            }
        }else if(*p == ',') {
            zeroargs = 1;
            if(inArg && inBrackets==0) {
                count++;
                inArg = 0;
            }
        } else if(!isspace(*p) && *p != ')') {
            inArg = 1;
        }
        p++;
    }

    count += zeroargs;

   // if(inArg && inBrackets==0) count++;
    
    return count;
}

int checkPrintAndScan(char* str){
    char* f = strchr(str,'"');
    char* l = strrchr(str,'"');
    if(!f || !l || f==l)return 0;
    int atcount=0;
    for(int i=0;f[i];i++){
        if(f[i]=='@')atcount++;
    }
    int argCount = countArguments(str);
    printf("argc %d\n", argCount);
    printf("atc %d\n", atcount);
    
    if(atcount>0 && argCount==0)return 0;
    return atcount == argCount;
}

struct symbol* lookupSymbol(char *name) {
    struct symbol *s;
    for(s = symbolTable; s; s = s->next) {
        if(strcmp(s->name, name) == 0) return s;
    }
    return NULL;
}

void insertSymbol(char *name, char *type) {
    struct symbol *s = (struct symbol*)malloc(sizeof(struct symbol));
    s->name = strdup(name);
    s->type = type ? strdup(type) : NULL;
    s->isDefined = 1;
    s->next = symbolTable;
    symbolTable = s;
}