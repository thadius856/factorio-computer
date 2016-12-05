
[Complete Machine (Large Image)](http://static.justarandomgeek.com/factorio/WelcomeToTheMachine.png)

### NixieTerm
![NixieTerm](screenshots/NixieTerm2.png)

NixieTerm is a multi-line Alpha Nixie display. It can be accessed as an array of bit-packed strings in memory starting at 500, or the lowermost row can be accessed as a `rNixie`, and shifted upward.

Any signals written in register mode will be added to the sum for the lowermost row. Clearing the register will shift all rows upward and clear the lower row.

Two numeric displays are provided beside each row, showing `signal-grey`(top) and `signal-white`(bottom) of the corresponding cell.

NixieTerm supports all the characters supported by the Alpha Nixie:
* A-Z0-9 as their correspnding signals
* . as `train-stop`
* \- as `fast-splitter`

Color signals may be bit-packed along with characters.

### Main Bus Signals

Major signals are carried along a 12-pole Main Bus, and labeled with floor concrete. In general pairs will be kept together for single-color poles, but when a pole must carry mixed pairs, the left side is colored for the green wire, and the right side for red wire.

The bus is constructed from the [Bus H](blueprints/Bus H.txt) and [Bus V](blueprints/Bus V.txt) blueprints. The fire hazard concrete should be bottom-right.


| Pole Color | Green Wire | Red Wire |
|------------|------------|----------|
| Red        |                               | rKeyboard            |
| Orange     | Op Pulse                      | rStatus              |
| Yellow     | Op                            | To PC                |
| Green      | R1                            | Scalars              |
| Cyan       | R2                            | Vector Result        |
| Blue       | Scalar Result (`signal-grey`) | rIndex               |
| Purple     | Memory Read Request           | Memory Read Response |
| Magenta    |                               | Memory Write         |
| White      | NixieTerm                     | NixieTerm            |
| Hazard     | IO Wire                       | IO Wire              |
| FireHazard | IO Wire Register              | IO Wire Register     |

* Scalars
  * signal-grey: R1.s1
  * signal-white: R2.s2
  * signal-I: rIndex.index
* To PC
  * signal-blue: next
  * signal-green: rjmp to signal-grey
  * signal-red: jump to signal-grey
  * signal-pink: execute this frame as an instruction
  * signal-yellow: Hold. Prevents execution of instructions while set.
  * signal-cyan: Interrupt. Next update (except exec) will save return site in rStatus and jump to interrupt vector.
* rStatus
  * signal-blue: PC
  * signal-green: Interrupt Return site
  * signal-cyan: Interrupt Request
  * signal-I: Interrupt Enable

### ScalarGen and Scalar Pick & Return

The Scalar Pick & Return mechanism allows operating on individual signals from registers. There are two Pick channels, s1 and s2, and one Return channel sd, selected by the corresponding signals in the current opcode, and operating on the corresponding register selection. Because the signals available will vary depending on what mods are installed, this module is generated by a script, ScalarGen. ScalarGen is executed by pasting it into Foreman's import window as if it were a blueprint string, and will add a blueprint named ScalarGen to your list. It will also produce a file `scalarmap.lua` in your script-output directory listing the numeric mappings for the assembly it has generated, which must be used when compiling programs for your computer. The local bus generated by ScalarGen is, from left to right, Blue,Yellow,Cyan,Green.


### Wireless

A half-duplex adapter for wireless masts is set up on `rFlanRX`/`r15` and `rFlanTX`/`r16`. `rFlanRX` reads the current values on the wireless (including current transmitted signal). `rFlanTX` is a memory cell which is connected to transmit to the wireless. Masts may be connected simply by wiring them to the pole above this port.

### Registers

![Registers](screenshots/Registers.png)

Registers store an entire circuit network frame, except `signal-black`. `signal-black` is used internally for various scalar and flag values throughout the machine, and cannot be stored in registers/memory, or expressed correctly in most mechanisms.


| ID    | Name        | Purpose |
|-------|-------------|---------|
| 0     | `rNull`     | No Register selected. Returns 0 on every signal.|
| 1-8   | `r1`-`r8`   | General Purpose data registers. |
| 9     | `rIndex`    | Indexing regiser. Supports auto-indexing memory operations. |
| 10    | `rRed`      | IO Wire Red data since list transmitted |
| 11    | `rGreen`    | IO Wire Green data since last transmitted |
| 12    | `rStat`     | CPU Status register |
| 13    | `rOp`       | Current Op data |
| 14    | `rNixie`    | NixieTerm |
| 15,16 | `rFlanRX`,`rFlanTX`| Wireless masts
| 17    | `rKeyboard` | Keyboard interface. Reads a single buffered key. Clear buffer with `signal-grey`. |
| 18+   |  `rn`-...  | IO Expansion ports<br>Aditional devices may be connected to these registers |

### Memory

![RAM](screenshots/RAM 300 Cells.png)

The memory is a large array of identical storage cells. To write a cell, send the address on `signal-black` combined with the data on the global Memory Write wire. To read a cell, send the address on `signal-black` on the Memory Read Request wire, and receive a response the following tick on Memory Read Reply containing data+address.


### Instruction Fetch

![Instruction Fetch](screenshots/Instruction Fetch W Interrupt.png)

This block recieves the PC Update frames produced by other blocks and acts on them. It performs the following actions:
 * Update PC
 * Fetch the instruction specified, and post it to the global Op wire
 * Wait for signals to stabilize
    1. <none>
    2. Scalar `signal-I` from rIndex, if selected
    3. R1 and R2 selected for operation
    4. <none>
    5. R1.S1 and R2.S2 selected for operation
 * Send a pulse to the global Op Pulse wire to trigger an instruction block

In the case of an Exec command, instead of fetching a frame from memory, the command itself will be used.

When interrupts are enabled (using a jmp instruction with `signal-cyan` set), this block also handles jumping to the interrupt vector when an interrupt is triggered, signalled by raising `signal-cyan` on the To PC wire. When an interrupt is caught, the next value of PC is calculated, stored in rStatus.intreturn, and then execution jumps to rIndex.intvect to handle the interrupt.

### Operations

The following signals are used to select registers and signals:

| Signal  |Purpose|
|--------|-------|
|signal-0|Op|
|signal-A| Accumulate |
|signal-I| Index/Stack Select |
|signal-R|R1|
|signal-S|S1|
|signal-T|R2|
|signal-U|S2|
|signal-V|Rd|
|signal-W|Sd|
|signal-grey|Imm1|
|signal-white|Imm2|

If Rd is set, the selected register will be cleared as Op Pulse is triggered unless Accumulate is also set (>0), even if the current operation does not actually assign to it. The whole register will be cleared, even in scalar operations.

For operations which support memory indexing, the base pointers are selected as follows:

|  I  |Signal         | Usage      |
|-----|---------------|------------|
|  1  |`signal-red`   | Call Stack |
|  2  |`signal-green` | Current Program Constant/Code Frame |
|  3  |`signal-blue`  | Current Progarm Data Frame |
|  4  |`signal-yellow`| local usage |

Individual instructions may also define additional signals. Any unused signals should be left unset.

#### 0: Halt
Any undefined opcode will halt the machine, but Op=0 is specifically reserved for doing so.

#### 1-60: Basic ALU
![Basic ALU](screenshots/01-60_ALU.png)
The ALU performs every possible operation in parallel, and returns the requested operation's result to Scalar Result or Vector Result.

1.  R1.Every = R2.S2 ::> R1 => Rd
2.  R1.Every < R2.S2 ::> R1 => Rd
3.  R1.Every > R2.S2 ::> R1 => Rd
4.  R1.Every = R2.S2 ::> R1 :1=> Rd
5.  R1.Every < R2.S2 ::> R1 :1=> Rd
6.  R1.Every > R2.S2 ::> R1 :1=> Rd
7.  R1.Any = R2.S2 ::> R1 => Rd
8.  R1.Any < R2.S2 ::> R1 => Rd
9.  R1.Any > R2.S2 ::> R1 => Rd
10. R1.Any = R2.S2 ::> R1 :1=> Rd
11. R1.Any < R2.S2 ::> R1 :1=> Rd
12. R1.Any > R2.S2 ::> R1 :1=> Rd
13. R1.S1 = R2.S2 ::> R1 => Rd
14. R1.S1 < R2.S2 ::> R1 => Rd
15. R1.S1 > R2.S2 ::> R1 => Rd
16. R1.S1 = R2.S2 ::> R1 :1=> Rd
17. R1.S1 < R2.S2 ::> R1 :1=> Rd
18. R1.S1 > R2.S2 ::> R1 :1=> Rd
19. R1.Each = R2.S2 => Rd
20. R1.Each < R2.S2 => Rd
21. R1.Each > R2.S2 => Rd
22. R1.Each = R2.S2 :1=> Rd
23. R1.Each < R2.S2 :1=> Rd
24. R1.Each > R2.S2 :1=> Rd
25. R1.Every = R2.S2 ::> R1.Sd=>Rd.Sd
26. R1.Every < R2.S2 ::> R1.Sd=>Rd.Sd
27. R1.Every > R2.S2 ::> R1.Sd=>Rd.Sd
28. R1.Every = R2.S2 ::> 1=>Rd.Sd
29. R1.Every < R2.S2 ::> 1=>Rd.Sd
30. R1.Every > R2.S2 ::> 1=>Rd.Sd
31. R1.Any = R2.S2 ::> R1.Sd=>Rd.Sd
32. R1.Any < R2.S2 ::> R1.Sd=>Rd.Sd
33. R1.Any > R2.S2 ::> R1.Sd=>Rd.Sd
34. R1.Any = R2.S2 ::> 1=>Rd.Sd
35. R1.Any < R2.S2 ::> 1=>Rd.Sd
36. R1.Any > R2.S2 ::> 1=>Rd.Sd
37. R1.S1 = R2.S2 ::> R1.Sd=>Rd.Sd
38. R1.S1 < R2.S2 ::> R1.Sd=>Rd.Sd
39. R1.S1 > R2.S2 ::> R1.Sd=>Rd.Sd
40. R1.S1 = R2.S2 ::> 1=>Rd.Sd
41. R1.S1 < R2.S2 ::> 1=>Rd.Sd
42. R1.S1 > R2.S2 ::> 1=>Rd.Sd
43. R1.Each = R2.S2 ::> R1.Sd=>Rd.Sd
44. R1.Each < R2.S2 ::> R1.Sd=>Rd.Sd
45. R1.Each > R2.S2 ::> R1.Sd=>Rd.Sd
46. R1.Each = R2.S2 ::> 1=>Rd.Sd
47. R1.Each < R2.S2 ::> 1=>Rd.Sd
48. R1.Each > R2.S2 ::> 1=>Rd.Sd
49. R1.Each - R2.S2 => Rd
50. R1.Each + R2.S2 => Rd
51. R1.Each / R2.S2 => Rd
52. R1.Each * R2.S2 => Rd
53. R1.Each - R2.S2 => Rd.Sd
54. R1.Each + R2.S2 => Rd.Sd
55. R1.Each / R2.S2 => Rd.Sd
56. R1.Each * R2.S2 => Rd.Sd
57. R1.S1 - R2.S2 => Rd.Sd
58. R1.S1 + R2.S2 => Rd.Sd
59. R1.S1 / R2.S2 => Rd.Sd
60. R1.S1 * R2.S2 => Rd.Sd

#### 61-62 Vector ALU

This block is generated by MaskGen. The local bus generated by MaskGen is, from left to right, Orange,Cyan,Green.

The Pairwise ALU block is generated by a script to allow working with all signals in the current game. This block performs pairwise Multiply/Divide operations on the operands and returns the result to Vector Result. This block is optional and if not installed Ops 61 and 62 will halt the machine.

* 61: R1.each * R2.each => Rd
* 62: R1.each / R2.each  => Rd

#### 63: Scalar Array (exec)
![Scalar Array](screenshots/63-64_scalar_array.png)
* 63: Pick
  * R1.[R2.s2] -> Rd.sd
    * exec{0=58,R=R,S=[R2.s2],V=V,W=W,A=A}
* 64: Write
  * R1.s1 -> Rd.[R2.s2]
    * exec{0=58,R=R,S=S,V=V,W=[R2.s2],A=A}

#### 65: Scalar shift up (not yet implemented)
R1 >> R2.s2 -> Rd

#### 66: Scalar shift down (not yet implemented)
R1 << R2.s2 -> Rd

#### 70: Jump
![Jump](screenshots/70_jump.png)
Jump to R1.s1 if `signal-green`=0 or PC+R1.s1 if `signal-green`=1. Return PC+1 to Rd.Sd. If `signal-cyan` is set, enable(1)/disable(-1) interrupts after this jump.

#### 71: Branch
![Branch](screenshots/71_branch.png)
Returns PC+1 to Rd.sd. Compares R1.s1 to R2.s2, and makes the following jumps:

* `=` PC+rOp.1
* `<` PC+rOp.2
* `>` PC+rOp.3

#### 72: Exec
![Exec](screenshots/72_exec.png)
Execute the contents of R1 as an instruction, at the current PC value.

#### 80: Wire
Write a packet to a two-wire network, and clear the receive registers for a response. To leave either wire untouched, select `rNull` for it. `rRed` and `rGreen` are cleared on the same frame the selected signals are transmitted. Write `rNull` to both wires to clear the receive buffer without transmitting anything.
* R1=>Red Wire
* R2=>Green Wire
* 0=>rRed,rGreen

#### 81-82: Memory
![Memory](screenshots/81-82_memory.png)
* 81: Write
  * Write the contents of R2 to the memory location or memory-mapped device selected by R1.s1. If `signal-I` is set, the memory access is offset from the selected pointer. If Rd is set, the value previously in that memory address will be returned.
    * [R1.s1+I] -> Rd
    * R2 -> [R1.s1+I]

* 82: Read
  * Read the memory location or memory-mapped device selected by R1.s1 into Rd. If `signal-I` is set, the memery access is offset from the selected pointer.
    * [R1.s1+I] -> Rd

#### 83-84: Stacks
![Stacks](screenshots/83-84_stacks.png)
* 83: Push
  * Store a frame to one of the stacks in rIndex, as selected by `signal-I`.
    * R2 -> [rIndex.stack-1]
    * rIndex.stack--
* 84: Pop
  * Retrieve a frame to one of the stacks in rIndex, as selected by `signal-I`.
    * [rIndex.stack] -> Rd
    * rIndex.stack++

#### 85: Append (not yet implemented)
Store a frame to an array in one of the index pointers.

* R2 -> [rIndex.stack++]


#### 100: Player Info (Optional)
![Player Info](screenshots/100_playerinfo.png)
This instruction uses my Player Combinator mod to read player information.

If R1.S1 == 0, a `playercounts` frame is returned containing the number players total, and online.

If R1.S1 >0, then it returns a `playerinfo` frame, with the players name, and their online/admin status.
