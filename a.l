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
    "VarDecl", "inc", "dec", "to","do","then", NULL 
};

bool CheckKeyword(const char* str);
struct symbol* lookupSymbol(char *name);
void insertSymbol(char *name, char *type);
int checkPrint(char* str);
int checkScan(char* str);
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
OP          [\+ \- \* \/ %]
WS          [ \t\n]+
COMMENT     \/\*([^*]|\*+[^*/])*\*+\/|\/\/.*
DECIMAL     \(([0]|[1-9][0-9]*),[ ]*10\)
BINARY      \([0-1]+,[ ]*2\)
OCTAL       \([0-7]+,[ ]*8\)
VALID_TYPES (int|char)
RELOP       (>=|<=|<>|=|<|>)
INTEGER     {DECIMAL}|{BINARY}|{OCTAL}
EXPR     {INTEGER}

%%

{COMMENT}                         { }
{WS}                              { }
"begin"[ \t]+"program:"           { 
    printf("TOKEN: KEYWORD: begin\n");
    printf("TOKEN: KEYWORD: program\n");
    printf("TOKEN: SEPERATOR: :\n");
}
"end"[ \t]+"program"              { 
    printf("TOKEN: KEYWORD: END\n");
    printf("TOKEN: KEYWORD program\n");
}

"begin"[ \t]+"VarDecl:"           { 
    inVarDecl=1; 
    printf("TOKEN: KEYWORD: begin \n");
    printf("TOKEN: KEYWORD: VarDecl \n");
    printf("TOKEN: SEPERATOR: : \n");
}

"end"[ \t]+"VarDecl"              { 
    inVarDecl=0; 
    printf("TOKEN: KEYWORD: end \n");
    printf("TOKEN: KEYWORD: VarDecl \n");
}


{RELOP}                           { printf("TOKEN: RELATIONAL_OPERATOR: %s\n", yytext); }
"("                               { if(inVarDecl) type = 0; printf("TOKEN: SEPERATOR: %s\n", yytext); }
","                               { if(inVarDecl) type = 1; printf("TOKEN: SEPERATOR: %s\n", yytext); }
")"                               { if(inVarDecl) type = 0; printf("TOKEN: SEPERATOR: %s\n", yytext); }
":="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }
"+="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }
"-="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }
"*="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }
"/="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }
"%="                              { printf("TOKEN: ASSIGNMENT OPERATOR %s\n", yytext); }

{STRING}                          { printf("TOKEN: STRING: %s\n", yytext); }
{CHAR}                            { printf("TOKEN: CHAR: %s\n", yytext); }
{OP}                              { printf("TOKEN: ARITHMETIC OPERATOR: %s\n", yytext); }
{INTEGER}                         { printf("TOKEN: INTEGER constant: %s\n", yytext); }
"("[ ]*{DIGIT}+","[ ]*{DIGIT}+")"  { 
    printf("ERROR: invalid integer constant %s\n", yytext); 
}
{EXPR}                            { printf("TOKEN: EXPRESSION: %s\n", yytext); }
{ID}                              { 
                                    // printf("ID: %s\n", yytext);
                                    int underscoreCount = 0;
                                    for(int i = 0; yytext[i]; i++) {
                                        if(yytext[i] == '_') underscoreCount++;
                                    }
                                    
                                    if(underscoreCount > 1) {
                                        printf("ERROR: Invalid identifier %s - more than one underscore\n", yytext);
                                    } else if(!inVarDecl&&CheckKeyword(yytext)) {
                                        printf("TOKEN: KEYWORD %s\n",yytext);
                                    }else if(inVarDecl && type==0 && CheckKeyword(yytext)){
                                        printf("ERROR: KEYWORD %s is used as an identifier\n",yytext);
                                    }else if(inVarDecl && type==1 && CheckKeyword(yytext)){
                                        printf("TOKEN: KEYWORD %s\n",yytext);
                                    } else {
                                        if(inVarDecl) {
                                            struct symbol *s = lookupSymbol(yytext);
                                            // printf("%s\n",yytext);
                                            if(s && s->isDefined) {
                                                printf("ERROR: Identifier %s already defined\n", yytext);
                                            } else {
                                                insertSymbol(yytext, NULL);
                                                printf("TOKEN: IDENTIFIER %s\n", yytext);
                                            }
                                        } else {
                                            struct symbol *s = lookupSymbol(yytext);
                                            printf("TOKEN: IDENTIFIER %s\n", yytext);
                                        }
                                    }
                                }
[(){},;"@]                         { printf("TOKEN: SEPARATOR: %s\n", yytext); }
.                                  { printf("LEXICAL ERROR: Unexpected Character: %s\n", yytext); }

"print"[ ]*"("\".*\".*");"         {
    if(!checkPrint(yytext)) {
        printf("TOKEN: Inalid Output Statement %s\n",yytext);
    }else{
        printf("TOKEN: Valid Output Statement %s\n",yytext);
    } 
}

"scan"[ ]*"("\".*\".*");"          {
    if(!checkScan(yytext)) {
        printf("ERROR: Invalid Input statement \n");
    }else{
        printf("TOKEN: Valid Input Statement %s\n",yytext);
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
//**********************************
// check this again
//**********************************

int checkScan(char* str){
    char* f = strchr(str,'"');
    char* l = strrchr(str,'"');
    if(!f || !l || f==l)return 0;
    int atcount=0;
    int comma_count = 0;
    char *ptr = f;
    while (ptr!=l){
        // printf("%c\n",*ptr);
        if(*ptr=='@')atcount++;
        if(*ptr==',')comma_count++;
        ptr++;
    }

    // printf("ehehhe");
    int argCount = countArguments(str);
    // printf("argCount %d\n", argCount);
    // printf("comma_count %d\n", comma_count);
    if(comma_count + 1 !=  atcount) {
        // printf("ERROR: Invalid number of arguments in print/scan statement\n");
        return 0;
    }
    // printf("argc %d\n", argCount);
    // printf("atc %d\n", atcount);
    
    if(atcount>0 && argCount==0)return 0;
    return atcount == argCount;
}
int checkPrint(char* str){
    char* f = strchr(str,'"');
    char* l = strrchr(str,'"');
    if(!f || !l || f==l)return 0;
    int atcount=0;
    char *ptr = f;
    while (ptr!=l){
        // printf("%c\n",*ptr);
        if(*ptr=='@')atcount++;
        ptr++;
    }

    // printf("ehehhe");
    int argCount = countArguments(str);
    
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