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
  internal Table tabVal;
  internal TableItem tabiVal;
}

%token <iVal> INTEGER
%token <sVal> STRING SIGNAL
%token <sVal> UNDEF TYPENAME FIELD FUNCNAME VAR INTVAR ARRAY INTARRAY
%token <iVal> REGISTER
%token <compVal> COMPARE
%token <bVal> COND

%token ASSIGN APPEND
%token DO WHILE IF ELSE END
%token TYPE FUNCTION RETURN
%token INT

%type <arithVal> arith

%type <tiVal> fielddeflist
%type <fiVal> fielddef paramdef

%type <slVal> paramdeflist

%type <seVal> sexpr
%type <veVal> vexpr
%type <srVal> sref
%type <tabVal> littable
%type <tabiVal> tableitem

%start program
%%
program: definition {};
program: program definition {};

definition: functiondef;
definition: datadef;
definition: typedef;

functiondef: FUNCTION UNDEF '(' paramdeflist ')' {BeginFunction($2,$4);} block END {};

paramdeflist: {$$ = new SymbolList();};
paramdeflist: paramdef {$$ = new SymbolList(); $$.AddParam($1);};
paramdeflist: paramdeflist ',' paramdef {$$=$1; $$.AddParam($3);};
paramdef: TYPENAME UNDEF {$$ = new FieldInfo{name=$2,basename=$1}; }; //typename undef
paramdef: INT      UNDEF {$$ = new FieldInfo{name=$2,basename="int"}; }; //typename undef

datadef: TYPENAME '@' INTEGER  UNDEF { CreateSym(new Symbol{name=$4,type=SymbolType.Data,datatype=$1,fixedAddr=$3}); };
datadef: TYPENAME '@' REGISTER UNDEF { CreateSym(new Symbol{name=$4,type=SymbolType.Register,datatype=$1,fixedAddr=$3}); };
datadef: TYPENAME              UNDEF { CreateSym(new Symbol{name=$2,type=SymbolType.Data,datatype=$1}); };
datadef: INT                   UNDEF { CreateInt($2); };

datadef: TYPENAME '@' INTEGER  UNDEF '[' INTEGER ']' { CreateSym(new Symbol{name=$4,type=SymbolType.Array,size=$6,datatype=$1,fixedAddr=$3}); };
datadef: TYPENAME              UNDEF '[' INTEGER ']' { CreateSym(new Symbol{name=$2,type=SymbolType.Array,size=$4,datatype=$1}); };

typedef: TYPE UNDEF '{' fielddeflist '}'     { RegisterType($2,$4); };
typedef: TYPE UNDEF '{' fielddeflist ',' '}' { RegisterType($2,$4); }; // allow trailing comma

fielddeflist: fielddef {$$ = new TypeInfo(); $$.Add($1); };
fielddeflist: fielddeflist ',' fielddef { $$=$1; $$.Add($3); };
fielddef: '@' FIELD UNDEF { $$ = new FieldInfo{name=$3,basename=$2}; };
fielddef:           UNDEF { $$ = new FieldInfo{name=$1}; };

block: ;
block: statement;
block: block statement;

statement: vassign;
statement: sassign;
statement: vexpr;
statement: sexpr;
statement: datadef {};

ifcomp: sexpr COMPARE sexpr   ;
ifcomp: sexpr                 ;

statement: IF ifcomp block elseblock END {};
elseblock: ELSE block { $$ = $2; };
elseblock: {};

statement: WHILE ifcomp DO block END {};

statement: FUNCNAME '(' arglist ')'; //TODO: return list

arglist: ;
arglist: arg;
arglist: arglist ',' arg;

arg: sexpr;
arg: vexpr;



statement: RETURN arglist {};

arith: '+' {$$ = ArithSpec.Add;};
arith: '-' {$$ = ArithSpec.Subtract;};
arith: '*' {$$ = ArithSpec.Multiply;};
arith: '/' {$$ = ArithSpec.Divide;};

sexpr: sexpr arith sexpr {$$=new ArithSExpr{S1=$1,Op=$2,S2=$3};};
sexpr: INTEGER {};
sexpr: sref {};
//sexpr: sum(vexpr)
//sexpr: '&' VAR {};
//sexpr: '&' ARRAY {};
//sexpr: '&' ARRAY '[' sexpr ']' {};


vexpr: vexpr arith vexpr {$$=new ArithVExpr{V1=$1,Op=$2,V2=$3};};
vexpr: vexpr arith sexpr {$$=new ArithVSExpr{V1=$1,Op=$2,S2=$3};};
vexpr: vexpr '&' vexpr {$$=new CatVExpr{V1=$1,V2=$3};};
vexpr: '{' littable '}'{$$=$2;};
//vexpr: '*' sexpr {};
vexpr: STRING {$$= new StringVExpr{text=$1};};
vexpr: vref;

sref: VAR '.' {ExpectFieldType=GetSymbolDataType($1);} FIELD {$$ = new FieldSRef{varname=$1,fieldname=$4};};
sref: INTVAR {$$ = new IntVarSRef{name=$1};};
//sref: VAR '[' sexpr ']' ;

vref: VAR;
vref: ARRAY '[' sexpr ']';

vassign: vref ASSIGN vexpr ;
vassign: vref APPEND vexpr ;


sassign: sref ASSIGN sexpr ;
sassign: sref APPEND sexpr ;



littable: {$$= new Table();};
littable: tableitem {$$= new Table();$$.Add($1);};
littable: littable ',' tableitem {$$=$1;$$.Add($3);};

tableitem: FIELD ASSIGN sexpr {$$=new TableItem{fieldname=$1,value=$3}; };

// */
