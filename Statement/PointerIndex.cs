using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using NLua;

namespace compiler
{

    public enum PointerIndex
    {
        None=0,
        CallStack=1,
        ProgConst=2,
        ProgData=3,
        LocalData=4,
    }

}