# Try CryptOpt
We recommend using the Docker based setup. If you want to actually use CryptOpt for production, the results may can typically be improved by running bare metal. See below and / Dockerfile for instructions.


## With Docker


1. Install Docker<br>
The installation steps for docker depend on your OS.
More information [here](https://docs.docker.com/get-docker).
(Note: If your host OS is Linux and Docker is installed via Snap.io there is [known issue with docker cp](https://github.com/docker/for-linux/issues/564).
Either install via default docker guidelines, or copy to `/tmp` and find copied files in `/tmp/snap.docker/tmp`)

1. Download and extract the tarball or clone this repository, then change into the directory containing this file.

1. Build Container<br>
Build the container with `sudo docker . -t cryptopt`. (`.` is the *build context*. It's the path containing the `Dockerfile`)
This will take a while. (Maybe around 1-2 hours, depending on Internet bandwidth and machine) (Note: It is expected that the some output is red. This is warnings of the build process piped to stderr).
The build was successful if it ends with `Sucessfully tagged cryptopt:latest`
The build command will create an container image tagged `cryptopt`, where all the dependencies are installed and the projects are built, ready to go.

### Play around 1

1. Run the container image with `docker run --name ae -ti cryptopt bash ` -> you are now in the built project, your terminal should change to something like `root@abcdef1234:~/cryptopt/src#`
1. Run a single-run experiment `make optimize`
1. Run a bet-and-run experiment `make bar`


### Understand Output

While optimizing, CryptOpt will output the current status of the optimization.
Each line has this format:
```
curve25519-square|0-10| 14|bs  181|#inst: 140|cyclΔ     70|G  58 cycl σ  0|B  59 cycl σ  0|L  55|l/g 0.9519| P|P[ -14/   0/  14/ -11]|D[MU/ 31/ 59]| 90.0( 1%)  60/s
```
Lets break this down:

Field                 |Example    | Comment
--|--|--
Primitive             | curve25519-square		| Format is `<BRIDGE>-<CURVE>-<METHOD>` (BRIDGE omitted if used with Fiat)
Comment               | 0-10                    | Arbitrary comment. Usually used in Population Mode. Then, it means Bet `0` from `10`, (`10` begin the `run`)
Stack size            | 14	                 	| How many spills to memory there are. E.g. `6` for all spills of the six callee-saved registers
Batch Size            | bs  181		            | `BS` in the paper, How big is the batch. i.e. how many iterations of Primitive are counted
Instr. Count          | #inst: 140		        | How many instructions are used to implement the primitive
Raw Cycle Delta       | cyclΔ     70		    | Measure both batches `nob=31` times, take difference of medians. Based on this a mutation is kept or not.
Cycles +stddev (good) | G  58 cycl σ  0		    | Number of cycles for the `good` candidate, scaled by `bs` i.e. per on *one* iteration. Also states the stdDev of the `nob` measurements
Cycles +stddev (bad)  | B  59 cycl σ  0		    | Same, but for the `bad` candidate
Cycles Library        | L  55		            | Cycles that the CC-Compiled version takes
Ratio                 | l/g 0.9519              | Ratio of cycles lib / cycles good. i.e. 55 / 58 -> 0.9519 (uses the non-scaled counts) This is green if the ratio is `>1` which means that CryptOpt Code is faster than CC's.
Mutation              |  P		                | Which mutation has been applied. **P**ermuation or **D**ecision. (Permutation means mutation in operation order; Decision means which template to use, or how to load operands.)
P-Mutation-Detail     | P[ -14/   0/  14/ -11]  | Details on last P-Mutation. [steps to go back / steps to go forward / absolute index of operation to move / applied relative movement ]
D-Mutation-Detail     | D[MU/ 31/ 59]		    | Details on last D-Mutation. [new chosen template / absolute index of operation to change decision / number of operations with changeable decisions ]
Progress, speed       |  90.0( 1%)  60/s        | Number of the current Mutation, then in Percent, then how many mutations per second can be evaluated. This is green if the mutation is kept.

More on the *D-Mutation*-Details:

Template Short | Description
--|--
AR | A different argument is loaded from memory
KK | The flags `CF`/ `OF` flags are cleared differently
FL | A different flag `CF`/ `OF` is used as an accumulator
B& | For a binary-and a different instruction-template is used
MU | For a multiplication-with-immediate a different instruction-template is used
IM | A different immediate value is loaded


### Understand Output Files

While Optimizing, CryptOpt will generate files in the `cryptopt/src/results/<CURVE>/<METHOD>` folder.

Note that bar is only a wrapper around the single-optimization.
CryptOpt writes out intermediate ASM-files whenever *it shows a new line during optimization* which, by default, is every 10% of the optimization progress of each bet and each run.
Those intermediate ASM-files will have `evalNNNofMMM` in their name, showing at which mutation they got created.
Other than that, CryptOpt also generates the internal state (in `json` files) of the optimization for each bet-outcome, the log files (same as what is written to the terminal).
If the `bar` version is used, the directory also contains a `dat` file with `l/g` value every time it is printed to the terminal. From that `dat` file, the generated `gp` file will generate the `pdf` file, which shows the optimization in progress.

If you want to copy the files from the container onto your host (e.g. to view the `pdf` file) copy it *as long as the container is running* (i.e. with a different terminal) with `sudo docker cp ae:/root/cryptopt/src/results /tmp`.

### Play around 2

We can give CryptOpt a wide range of parameters:

Parameter       | default     | possible / typical values | description
----------------|---------    |-------------------|----------
BRIDGE          | fiat        | fiat, bitcoin-core, manual| which *connection* i.e. input should be used.
EVALS           | 10000       | 100, 1k, 100k, 1M | `t`; How many mutations to evaluate
CURVE           | curve25519  | curve25519, p224, p256, p384, p434, p448\_solinas, p521, poly1305, secp256k1 | which field - this determines the prime, the implementation strategy and number of limbs
METHOD          | square      | mul, square       | Method (i.e. function) to optimize. Multiply or Square
CYCLEGOAL       | 10000       | 1, 100, 100000    | How many cycles to measure, and adjust batch size `bs` accordingly
POPULATIONSIZE  | 10          | 10, 30, 100       | How many 'bets' for the bet-and-run heuristic
POPULATIONSHARE | 0.005       | 0.005, 0.001      | The share from parameter `EVALS`, which are spent for all bets, in per cent (i.e. 0.005 means 0.5% of EVALS will be used for POPULATIONSIZE bets each. Make sure that the math works out. You will be warned if not.)
CPUMASK         | ff          | 1 -- ff           | if set, process is pinned to that core. See `man taskset` for more details.

As next example, use `CC=clang make bar CURVE=p256 METHOD=mul EVALS=10k` to generate an optimized version for NIST P-256 multiply and compare the function with `clang`.

To see *Case Study 2* in action, use `make bar BRIDGE=bitcoin-core CURVE=secp256k1 METHOD=mul POPULATIONSIZE=5`
This will try 5 different 'bets' for the primitive `mul` of 'libsecp256k1'.
Find the result files (`*.asm`,`*.pdf`) for this run in `./cryptopt/src/results/bitcoin-core-secp256k1/mul`


## Bare Metal
CryptOpt itself will only write files in /tmp and in its own subdirectories. It will require internet access to download the (node) runtime and dependencies

1. Install dependencies (will install globally) (c.f. Dockerfile `apt install` command(s))
1. Install Assemblyline (will install globally) (c.f. github.com/0xADE1A1DE/Assemblyline.git)
1. Clone the base-repo as above.
1. Enable performance counters `echo "1" | sudo tee /proc/sys/kernel/perf_event_paranoid`
1. Build CryptOpt, it also contains pre-built binaries for fiat-crypto. If you want to build them fresh, too, run `make -C ./fiat-crypto standalone-ocaml` and find the binaries in `fiat-crypto/src/ExtractionOCaml/{unsaturated_solinas,word_by_word_montgomery}`. For more information consider the [Fiat Readme](./fiat-crypto/Readme).
1. `make -C ./cryptopt/src install`
1. Play Around as above


