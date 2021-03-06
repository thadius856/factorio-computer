%namespace compiler
%partial
%union {
  internal int iVal;
  internal string sVal;
  internal bool bVal;

  internal ArithSpec arithVal;
  internal CompSpec compVal;
  internal TypeInfo tiVal;
  internal FieldInfo fiVal;
  internal SymbolList slVal;
  internal SExpr seVal;
  internal VExpr veVal;
  internal SRef srVal;
  internal VRef vrVal;
  internal Table tabVal;
  internal TableItem tabiVal;
  internal Statement statVal;
  internal Block blockVal;
  internal Branch brVal;
  internal ExprList elVal;
}

%token <iVal> INTEGER
%token <sVal> STRING SIGNAL
%token <sVal> UNDEF LIBNAME TYPENAME FIELD VFUNCNAME SFUNCNAME VAR INTVAR ARRAY INTARRAY
%token <iVal> REGISTER
%token <compVal> COMPARE
%token <bVal> COND

%token FUNCASSIGN ASSIGN APPEND
%token DO WHILE IF THEN ELSE END
%token REQUIRE TYPE FUNCTION RETURN EXTERN
%token INT


%type <arithVal> arith

%type <tiVal> fielddeflist
%type <fiVal> fielddef paramdef

%type <slVal> paramdeflist

%type <seVal> sexpr
%type <veVal> vexpr
%type <srVal> sref
%type <vrVal> vref
%type <tabVal> littable
%type <tabiVal> tableitem

%type <statVal> statement vassign sassign
%type <blockVal> block elseblock
%type <brVal> branch
%type <elVal> exprlist
//%type <fcVal> funccall

%start program

%%

//<_aD> are there snippets of my IRC comments in the code?
//<_aD> because there bloody well should be *adjusts monocle*

program: definition {};
program: program definition {};

definition: REQUIRE '(' STRING ')' { Require($3); };
definition: externdef;
definition: functiondef;
definition: datadef;
definition: typedef;

externdef: EXTERN UNDEF  '{' {BeginExtern($2);} externlist '}' {CompleteExtern();};
externlist: ;
externlist: externlist datadef;
externlist: externlist extfunction;

extfunction:          FUNCTION UNDEF '(' paramdeflist ')' { ExternFunction($2,"var",$4); };
extfunction: TYPENAME FUNCTION UNDEF '(' paramdeflist ')' { ExternFunction($3,   $1,$5); };
extfunction: INT      FUNCTION UNDEF '(' paramdeflist ')' { ExternFunction($3,"int",$5); };

functiondef:          FUNCTION UNDEF '(' paramdeflist ')' { BeginFunction($2,"var",$4); } block END { CompleteFunction($2,$7); };
functiondef: TYPENAME FUNCTION UNDEF '(' paramdeflist ')' { BeginFunction($3,   $1,$5); } block END { CompleteFunction($3,$8); };
functiondef: INT      FUNCTION UNDEF '(' paramdeflist ')' { BeginFunction($3,"int",$5); } block END { CompleteFunction($3,$8); };

paramdeflist: {$$ = new SymbolList();};
paramdeflist: paramdef {$$ = new SymbolList(); $$.AddParam($1);};
paramdeflist: paramdeflist ',' paramdef {$$=$1; $$.AddParam($3);};
paramdef: TYPENAME UNDEF {$$ = new FieldInfo{name=$2,basename=$1}; };
paramdef: INT      UNDEF {$$ = new FieldInfo{name=$2,basename="int"}; };

datadef: TYPENAME '@' INTEGER  UNDEF { CreateSym(new Symbol{name=$4,type=SymbolType.Data,frame=PointerIndex.ProgData,datatype=$1,fixedAddr=$3}); };
datadef: TYPENAME '@' REGISTER UNDEF { CreateSym(new Symbol{name=$4,type=SymbolType.Register,datatype=$1,fixedAddr=$3}); };
datadef: TYPENAME              UNDEF { CreateSym(new Symbol{
                                        name=$2,
                                        type=SymbolType.Data,
                                        frame=InFunction!=null?PointerIndex.CallStack:PointerIndex.ProgData,
                                        datatype=$1
                                        }); };
datadef: INT                   UNDEF { CreateInt($2); };

datadef: TYPENAME '[' INTEGER ']' '@' INTEGER  UNDEF { CreateSym(new Symbol{name=$7,type=SymbolType.Data,frame=PointerIndex.ProgData,size=$3,datatype=$1,fixedAddr=$6}); };
datadef: TYPENAME '[' INTEGER ']'              UNDEF { CreateSym(new Symbol{name=$5,type=SymbolType.Data,frame=InFunction!=null?PointerIndex.LocalData:PointerIndex.ProgData,size=$3,datatype=$1}); };

typedef: TYPE UNDEF '{' fielddeflist '}'     { RegisterType($2,$4); };
typedef: TYPE UNDEF '{' fielddeflist ',' '}' { RegisterType($2,$4); }; // allow trailing comma

fielddeflist: STRING {$$ = new TypeInfo(); $$.hasString=true; };
fielddeflist: fielddef {$$ = new TypeInfo(); $$.Add($1); };
fielddeflist: fielddeflist ',' fielddef { $$=$1; $$.Add($3); };
fielddef: '@' FIELD UNDEF { $$ = new FieldInfo{name=$3,basename=$2}; };
fielddef:           UNDEF { $$ = new FieldInfo{name=$1}; };

//block: {$$=new Block();};
block: statement { $$=new Block(); $$.Add($1); };
block: block statement { $$=$1; $$.Add($2); };

branch: sexpr COMPARE sexpr {$$=new SBranch{ S1=$1, Op=$2, S2=$3};};
branch: sexpr {$$=new SBranch{ S1=$1, Op= CompSpec.NotEqual, S2=IntSExpr.Zero };};

branch: vexpr COMPARE vexpr {$$=new VBranch{ V1=$1, Op=$2, V2=$3};};

//vbranch: vexpr COMPARE vexpr {$$=new VBranch{ S1=$1, Op=$2, S2=$3};};
//vbranch: vexpr {$$=new VBranch{ V1=$1, Op= CompSpec.NotEqual };};

statement: IF branch THEN block elseblock END { $$ = new If{branch=$2,ifblock=$4,elseblock=$5}; };
elseblock: ELSE block { $$ = $2; };
elseblock: {$$=new Block();};

statement: WHILE branch DO block END { $$ = new While{branch=$2,body=$4}; };
statement: WHILE branch DO       END { $$ = new While{branch=$2,body=new Block()}; };

vexpr: VFUNCNAME '(' exprlist ')' { $$ = new FunctionCall{name=$1,args=$3}; };
sexpr: SFUNCNAME '(' exprlist ')' { $$ = new FunctionCall{name=$1,args=$3}; };
statement: VFUNCNAME '(' exprlist ')' { $$ = new FunctionCall{name=$1,args=$3}; };
statement: SFUNCNAME '(' exprlist ')' { $$ = new FunctionCall{name=$1,args=$3}; };

statement: vassign {$$=$1;};
statement: sassign {$$=$1;};

statement: datadef;

exprlist: { $$=new ExprList(); };
exprlist: sexpr { $$=new ExprList(); $$.ints.Add($1); };
exprlist: vexpr { $$=new ExprList(); $$.vars.Add($1); };
exprlist: exprlist ',' sexpr { $$=$1; $$.ints.Add($3); };
exprlist: exprlist ',' vexpr { $$=$1; $$.vars.Add($3); };


statement: RETURN { $$ = new Return(); };
statement: RETURN sexpr { $$ = new Return($2); };
statement: RETURN vexpr { $$ = new Return($2); };

arith: '+' {$$ = ArithSpec.Add;};
arith: '-' {$$ = ArithSpec.Subtract;};
arith: '*' {$$ = ArithSpec.Multiply;};
arith: '/' {$$ = ArithSpec.Divide;};

sexpr: '(' sexpr ')' { $$=$2; };
sexpr: sexpr arith sexpr {$$=new ArithSExpr($1,$2,$3);};
sexpr: INTEGER {$$=new IntSExpr($1);};
sexpr: sref {$$=$1;};
sexpr: '&' VAR { $$ = new AddrSExpr($2); };
sexpr: '&' SFUNCNAME { $$ = new AddrSExpr($2); };
sexpr: '&' VFUNCNAME { $$ = new AddrSExpr($2); };
//sexpr: '&' ARRAY { $$ = new AddrSExpr{symbol = $2}; };
//sexpr: '&' ARRAY '[' sexpr ']' { $$ = new ArithSExpr{S1 = new AddrSExpr{symbol = $2}, Op=ArithSpec.Add, S2 = $4}; };

vexpr: '(' vexpr ')' { $$=$2; };
vexpr: vexpr arith vexpr {$$=new ArithVExpr($1,$2,$3);};
vexpr: vexpr arith sexpr {$$=new ArithVSExpr($1,$2,$3);};
vexpr: '{' littable '}'{$$=$2;};
vexpr: STRING {$$= (StringVExpr)$1;};
vexpr: vref{$$=$1;};

sref: vref '.' {
	ExpectFieldType=$1.datatype;
	} FIELD {
	$$ = FieldSRef.VarField($1,$4);
	};
sref: INTVAR {$$ = new IntVarSRef($1);};
//sref: VAR '[' sexpr ']' ;

vref: VAR {$$=new VarVRef($1);};
vref: ARRAY '[' sexpr ']' {$$=new ArrayVRef($1,$3);};
vref: '@' sexpr {$$ = new MemVRef($2);};

vassign: vref ASSIGN vexpr {$$=new VAssign{target=$1,source=$3};};
//vassign: vref APPEND vexpr {$$=new VAssign{target=$1,append=true,source=$3};};

sassign: sref ASSIGN sexpr {$$=new SAssign{target=$1,source=$3};};
//sassign: sref APPEND sexpr {$$=new SAssign{target=$1,append=true,source=$3};};

littable: {$$= new Table();};
littable: STRING {$$= new Table($1);};
littable: tableitem {$$= new Table();$$.Add($1);};
littable: littable ',' tableitem {$$=$1;$$.Add($3);};

tableitem: FIELD ASSIGN sexpr {$$=new TableItem($1,$3); };

tableitem: FIELD {$$=new TableItem($1,IntSExpr.One); };

// */
