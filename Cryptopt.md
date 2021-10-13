## Overall directory structure
The main starting point is the `cryptopt/src/` directory.

It itself contains a `Makefile` which is the entry point for targets `install`, `optimize`, `bar` and (`clean` targets)
The CryptOpt root directory is the `cryptopt/src/automate`.

It contains a `Makefile` which ensures that the project is rebuild when tried to start if there was a change in the source files.


## Tool chain

CryptOpt is written in `typescript`, a typed superset of JavaScript.
It gets transpiled into to the `dist` folder, where the entry points are `dist/generate_asm.js` and `dist/populatio_dicentur.js` to start a single optimization or the population (i.e. bet-and-run) based approach.
The optimization then runs in the Chrome V8 engine through NodeJS.

## Files

The general entry point is `generate_asm.ts` which uses `argParse.ts` to parse all the arguments and sets up boilerplate. 

The file `populatio_dicentur.ts` is the entry point for the population-based approach.
It just sequentially spawns `generate_asm`'s, collects the results and analyses them.
Then restarts the most promising bet.
It also collects the data points, into the `results/<CURVE>/<METHOD>/*.dat` files, and creates + executes the corresponding `.gp` file to create the `*pdf` showing the optimization over time.

## Dependencies

CryptOpt is dependent on `measuresuite`. In a nutshell, CryptOpt gives `measuresuite` two assembly strings and `measuresuite` will then evaluate them in our adapted R3-Validation fashion.
It itself is written in C, but provides typescript bindings.
It also depends on [Assemblyline](https://github.com/0xAde1a1de/Assemblyline) (*An ultra-lightweight C library and binary for generating machine code of x86_64 assembly language and executing on the fly*) to generate and execute machine code.

## How does it work then?

Lets dive into how the optimization works.

`generate_asm` creates an instance of `optimizer` from `optimizer.class.ts`, the constructor of which initializes the Measuresuite (with parameters to set up memory, set up AssemblyLine instances etc...).
This also initializes the Model (e.g. `optimizer.helper.class.ts` contains the set ups for Fiat, Bitcoin, or a manual (just feed in JSON's)).
Note, that this e.g. includes the generation of the JSON of the provided primitive (in `optimizer.helper.class.ts:34` we get the JSON.) and in line `42` we generate the golden truth (that this happens in line `42` was not deliberate :D), which consists of calling the Fiat binaries (in `cryptopt/src/automate/fiat-bridge/`) in *generate C code* mode, which then gets compiles with CC and CFLAGS (read from the environment, defaults set in `envHelper.ts`).
Initializing the model also analyses the operations, rewrites some hierarchies in the JSON, and sets up internal data structures.

If we read a state (as in the *run* in bar setup), we import that new state at the end of the constructor.

`generate_asm` also and calls `optimize` in `optimizer.class.ts:100`.

There the generic improvement can be followed.

1. Assemble the current code (`Assembler.assemble` call in line `optimizer.class.ts:198`); will assemble the JS-operations into assembly.
1. Because `numEvals` is zero in at first, we increment (line 220) and jump back to 194, where we do the mutation. Paul (our stateful random oracle for everything) chooses if we want to mutate P or D, we then do the mutation in line 79 or 87. We also prepare the function to revert the mutation in case we want to discard it.
1. After the mutation  we then measure both function with batchSize and numBatches (bs, nob) in line 230.
1. We sanity check if all is correct.
1. In lines 305--309 we check if the mutated version is better.
1. We write out the assembly file every now and then by calling the `write_current_asm` method. This method will then call the Fiat-equivalence checker (line 175), and exit the optimization process with exit code `6`, if the validation failed. Note: The build command, being built in the FiatBridge, is similar to the code generation command, but this time mainly features the `--hints-file` switch with the just written asm file.
1. In the rest of the file, we gather some statistics and write the status line.


### Assembly generation

The `Assembly.assemble` assembles the JS-Data into an asm-string.
It does so by sequentially going through the operations (`assembler.class.ts:36`) and  getting the instruction(s) for this particular operation.
The rest of that file is pretty much boilerplate and error handling.

The instructions are generated from `instructionGenerator.ts`, a big switch statements proxying to the templates.

The context is kept in the singleton instance of `RegisterAllocator.class.ts`. Each of the templates are called with the operation `c`.
Those templates then analyze the operation, *requests* the RegisterAllocator for the registers holding the needed values and for spare registers to save the value into.
Within such requests, there are flags on what the instruction needs e.g. *will clear CF-flag, spill it if needed* or *can read immediate values*.
The RegisterAllocator then takes care of those circumstances and applies the *glue* into its `preInstuction`-list, which gets glued in front of the instructions, that the template itself generates.

The templates can be found in `instructionGeneration` and respective helper sub folders.
Addition and subtraction is a bit of a special snow flake because there are just so many different contexts and operand combinations, that we created special templates for each situation (`{addition,subtration}helpers`). 
File `fr__rm_rm_rmf.ts` offers templates where the output is carry-flag out + register out, provided there are three operands, op1 and op2 in either register or memory, and op3 can additionally be in a flag.

## Mutations and Bias

The mutations are handled in `model.rs`, which relies on `Paul.class.ts` as the oracle.
The permutation mutations (P-Mutation) is
1. Pick an index in the `_nodes` list
1. Resolve the node (i.e. operation) behind it
1. Calculate the interval or relative movements
1. Ask `Paul` to pick a number with *REVERSE_BELL*-shaped bias, from that interval
1. Splice the index into the new position.

The decisions (D-Mutation) are attached to the operations themselves.
They are assigned randomly during startup (while calling `fiat-helpers.ts:preprocessFunction`, in particular in line 50, `addDecisionProperty`).
In the mutation, we check this decision-property and choose an alternative. Often, there is only one alternative. In the case there is multiple, we choose unbiased randomly.

