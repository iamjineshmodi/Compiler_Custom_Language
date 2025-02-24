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

void printHeader() {
    printf("%-40s %-20s\n", "LEXEME", "TOKEN TYPE");
    printf("%-40s %-20s\n", "------", "----------");
}

void printToken(const char* lexeme, const char* type) {
    printf("%-40s %-20s\n", lexeme, type);
}

int headerPrinted = 0;

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
    printToken("begin","Keyword");
    printToken("program","Keyword");
    printToken(":","Separator");
}
"end"[ \t]+"program"              { 
    printToken("end","Keyword");
    printToken("program","Keyword");
}

"begin"[ \t]+"VarDecl:"           { 
    inVarDecl=1; 
    printToken("begin","Keyword");
    printToken("VarDecl","Keyword");
    printToken(":","Separator");
}

"end"[ \t]+"VarDecl"              { 
    inVarDecl=0; 
    printToken("end","Keyword");
    printToken("VarDecl","Keyword");
}


{RELOP}                           {printToken(yytext,"Relational Operator"); }
"("                               { if(inVarDecl) type = 0; printToken(yytext,"Separator"); }
","                               { if(inVarDecl) type = 1; printToken(yytext,"Separator"); }
")"                               { if(inVarDecl) type = 0; printToken(yytext,"Separator"); }
":="                              { printToken(yytext,"Assignment Operator"); }
"+="                              { printToken(yytext,"Assignment Operator"); }
"-="                              { printToken(yytext,"Assignment Operator"); }
"*="                              { printToken(yytext,"Assignment Operator"); }
"/="                              { printToken(yytext,"Assignment Operator"); }
"%="                              { printToken(yytext,"Assignment Operator"); }

{STRING}                          { printToken(yytext,"String"); }
{CHAR}                            { printToken(yytext,"Char"); }
{OP}                              { printToken(yytext,"Arithmetic Operator"); }
{INTEGER}                         { printToken(yytext,"Integer constant"); }
"("[ ]*{DIGIT}+","[ ]*{DIGIT}+")"  { 
    printToken(yytext,"Error: invalid integer constant"); 
}
{EXPR}                            { printToken(yytext,"Expression"); }
{ID}                              { 
                                    // printf("ID: %s\n", yytext);
                                    int underscoreCount = 0;
                                    for(int i = 0; yytext[i]; i++) {
                                        if(yytext[i] == '_') underscoreCount++;
                                    }
                                    
                                    if(underscoreCount > 1) {
                                        printToken(yytext,"Error: invalid identifier");
                                    } else if(!inVarDecl&&CheckKeyword(yytext)) {
                                        printToken(yytext,"Keyword");
                                    }else if(inVarDecl && type==0 && CheckKeyword(yytext)){
                                        printToken(yytext,"Error: Keyword is used as an identifier");
                                    }else if(inVarDecl && type==1 && CheckKeyword(yytext)){
                                        printToken(yytext,"Keyword");
                                    } else {
                                        if(inVarDecl) {
                                            struct symbol *s = lookupSymbol(yytext);
                                            // printf("%s\n",yytext);
                                            if(s && s->isDefined) {
                                                printToken(yytext,"Error: identifier already defined");
                                            } else {
                                                insertSymbol(yytext, NULL);
                                                printToken(yytext,"Identifier");
                                            }
                                        } else {
                                            struct symbol *s = lookupSymbol(yytext);
                                            printToken(yytext,"Identifier");
                                        }
                                    }
                                }
[(){},;"@]                         { printToken(yytext,"Separator"); }
.                                  { printToken(yytext,"Lexical Error: Unexpected Character"); }

"print"[ ]*"("\".*\".*");"         {
    if(!checkPrint(yytext)) {
        printToken(yytext,"Error: Invalid Output Statement");
    }else{
        printToken(yytext,"Valid Output Statement");
    } 
}

"scan"[ ]*"("\".*\".*");"          {
    if(!checkScan(yytext)) {
        printToken(yytext,"Error: Invalid Input statement");
    }else{
        printToken(yytext,"Valid Input Statement");
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
    printHeader();
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
        // printf("Error: Invalid number of arguments in print/scan statement\n");
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