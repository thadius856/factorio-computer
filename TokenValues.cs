﻿/*
 * Created by SharpDevelop.
 * User: Thomas
 * Date: 2016-07-30
 * Time: 14:38
 * 
 * To change this template use Tools | Options | Coding | Edit Standard Headers.
 */

using System;
using System.Collections.Generic;
using System.Text;
using NLua;


namespace compiler
{

	
	
	public enum CompSpec
	{
		Equal,
		Greater,
		Less
	}

	public enum InputMode{
		Any,
		Every,
		Each,
		Scalar
	}

	public enum ArithSpec
	{
		Add,
		Subtract,
		Multiply,
		Divide
	}
	
	
	public class TypeInfo:Dictionary<string,string>
	{
		public void Add(FieldInfo fi)
		{
			this.Add(fi.name,fi.basename);
		}
	}
	public struct FieldInfo{
		public string name;
		public string basename;
	}
	
	public class SymbolList:List<Symbol>
	{
		public void AddParam(FieldInfo pi)
		{
			this.Add(new Symbol{
			         	name=pi.name,
			         	type=SymbolType.Parameter,
			         	datatype=pi.basename			         	
			         });
		}
	}
	
	public class FunctionInfo{
		public string name;
		public SymbolList locals = new SymbolList();
		public TypeInfo localints = new TypeInfo();
	}
	
	public enum SymbolType{
		Unspecified=0,
		Function, 
		Data,
		Register,
		Program,
		Internal,
		Parameter,
		Array,
	}
	
	public struct Symbol
	{
		public string name;
		public SymbolType type;
		public string datatype;
		public int? fixedAddr;
		public int? size;
		
		#region Equals and GetHashCode implementation
		public override bool Equals(object obj)
		{
			return (obj is Symbol) && Equals((Symbol)obj);
		}

		public bool Equals(Symbol other)
		{
			return (this.name == other.name) 
				&& (this.type == SymbolType.Unspecified || other.type == SymbolType.Unspecified || this.type == other.type);
		}

		public override int GetHashCode()
		{
			return name.GetHashCode();
		}

		public static bool operator ==(Symbol lhs, Symbol rhs) {
			return lhs.Equals(rhs);
		}

		public static bool operator !=(Symbol lhs, Symbol rhs) {
			return !(lhs == rhs);
		}

		#endregion
		
		public static Symbol Block = new Symbol{name="__block",type=SymbolType.Internal};
		public static Symbol TrueBlock = new Symbol{name="__trueblock",type=SymbolType.Internal};
		public static Symbol FalseBlock = new Symbol{name="__falseblock",type=SymbolType.Internal};
		public static Symbol Loop = new Symbol{name="__loop",type=SymbolType.Internal};
		public static Symbol End = new Symbol{name="__end",type=SymbolType.Internal};
		public static Symbol Return = new Symbol{name="__return",type=SymbolType.Internal};
		
		public override string ToString()
		{
			return string.Format("{1}:{2} {0}", name, type.ToString()[0], datatype);
		}
		
		public Tokens ToToken()
		{
			switch (type) {
				case SymbolType.Data:
				case SymbolType.Parameter:
				case SymbolType.Register:
					return datatype=="int"?Tokens.INTVAR:Tokens.VAR;
				case SymbolType.Function:
					return Tokens.FUNCNAME;
				case SymbolType.Array:
					return datatype=="int"?Tokens.INTARRAY:Tokens.ARRAY;
				default:
					return Tokens.error;
			}
		}

	}
	
	public struct SymbolRef
	{
		
		public int? value;
		public Symbol identifier;
		public int identifierOffset;
		public bool relative;
		
		public int resolve(int atAddr, Dictionary<Symbol,int> symbols)
		{
			if(value.HasValue){
				return this.value.Value - (relative?atAddr:0);
			} else {
				return symbols[this.identifier] + this.identifierOffset - (relative?atAddr:0);
			}			
		}
		
		public static implicit operator SymbolRef(int i){ return new SymbolRef{value=i}; }
		public static implicit operator SymbolRef(string s){ return new SymbolRef{identifier=new Symbol{name=s}}; }
		public static implicit operator SymbolRef(Symbol sym){ return new SymbolRef{identifier=sym};}
		
		public static SymbolRef operator +(SymbolRef a1, SymbolRef a2)
		{
			if (a2.value.HasValue) return a1 + a1.value.Value;
			if (a1.value.HasValue) return a2 + a1.value.Value;
			//TODO: handle more cases?
			throw new ArgumentException(string.Format("Cannot add these AddrSpecs: {0},{1}",a1,a2));
		}
		
		public static SymbolRef operator +(SymbolRef a, int i)
		{
			if (a.value.HasValue)
			{
				a.value += i;
			} else {
				a.identifierOffset+=i;
			}
			return a;
		}
		
		public override string ToString()
		{
			if (value.HasValue) {
				return string.Format("{0}",value);
			} else if(identifierOffset==0) {
				return string.Format("{0}",identifier.name);				
			} else {
				return string.Format("{0}+{1}",identifier.name,identifierOffset);				
			}
		}
	}

	
	public interface VExpr
	{
		
	}
	
	public interface SExpr
	{
		
	}
	
	public class ArithSExpr: SExpr
	{
		public SExpr S1;
		public ArithSpec Op;
		public SExpr S2;		
	}
	
	public class IntSExpr: SExpr
	{
		public int value;
	}
	
	public class ArithVExpr: VExpr
	{
		public VExpr V1;
		public ArithSpec Op;
		public VExpr V2;		
	}
	
	public class CatVExpr: VExpr
	{
		public VExpr V1;
		public VExpr V2;		
	}
	
	public class ArithVSExpr: VExpr
	{
		public VExpr V1;
		public ArithSpec Op;
		public SExpr S2;		
	}
	
	public class StringVExpr: VExpr
	{
		public string text;
	}
	
	public interface SRef : SExpr // the assignable subset of scalar expressions
	{
		
	}
	
	public class IntVarSRef: SRef
	{
		public string name;
	}
	
	public class FieldSRef: SRef
	{
		public string varname;
		public string fieldname;
	}
	
	public class Table:Dictionary<string,SExpr>, VExpr
	{
		public string datatype;
		public void Add(TableItem ti)
		{
			this.Add(ti.fieldname,ti.value);
		}
		
	}
	
	public class TableItem
	{
		public string fieldname;
		public SExpr value;
	}
	
	
	public struct DataItem
	{
		public SignalSpec signal;
		public SymbolRef addr;
		
		public DataItem(char c,SymbolRef addr):this(new SignalSpec(c),addr){}
		public DataItem(SignalSpec signal, SymbolRef addr)
		{
			this.signal =  signal;
			this.addr = addr;
		}
		
		public override string ToString()
		{
			return string.Format("[DataItem Signal={0}, Addr={1}]", signal, addr);
		}

	}
	
	
}