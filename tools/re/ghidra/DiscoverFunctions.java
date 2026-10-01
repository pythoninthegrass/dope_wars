// Creates functions at Delphi prologues (push ebp; mov ebp,esp) that auto-analysis missed or disassembled out of phase.
// Usage: -postScript DiscoverFunctions.java

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.mem.MemoryBlock;
import java.util.ArrayList;
import java.util.List;

public class DiscoverFunctions extends GhidraScript {
    private static final int PUSH_EBP = 0x55;
    private static final int RET = 0xC3;
    private static final int RET_IMM = 0xC2;
    private static final int[] PADDING = {0x00, 0x90, 0xCC};

    @Override
    protected void run() throws Exception {
        MemoryBlock code = currentProgram.getMemory().getBlock("CODE");
        List<Address> candidates = new ArrayList<>();
        for (Address a = code.getStart(); a.compareTo(code.getEnd().subtract(2)) < 0; a = a.add(1)) {
            if (isPrologue(a) && followsFunctionEnd(a) && getFunctionAt(a) == null) {
                candidates.add(a);
            }
        }
        int created = 0;
        int failed = 0;
        for (int i = 0; i < candidates.size(); i++) {
            Address start = candidates.get(i);
            Address next = i + 1 < candidates.size() ? candidates.get(i + 1) : code.getEnd();
            if (getFunctionAt(start) != null) {
                continue;
            }
            Function following = getFunctionAfter(start);
            if (following != null && following.getEntryPoint().compareTo(next) < 0) {
                next = following.getEntryPoint();
            }
            clearListing(start, next.subtract(1));
            disassemble(start);
            if (createFunction(start, null) != null) {
                created++;
            } else {
                failed++;
                printerr("ERROR: no function at " + start);
            }
        }
        int viaCalls = createFunctionsAtCallTargets(code);
        println("DiscoverFunctions: created " + created + " functions at prologues, " + viaCalls
                + " at call targets, " + failed + " failures");
    }

    // Repeats until no CALL targets a non-function, since each new function can reveal further calls.
    private int createFunctionsAtCallTargets(MemoryBlock code) throws Exception {
        int total = 0;
        boolean progress = true;
        while (progress) {
            progress = false;
            List<Address> targets = new ArrayList<>();
            InstructionIterator instructions = currentProgram.getListing().getInstructions(code.getStart(), true);
            for (Instruction ins : instructions) {
                if (!ins.getFlowType().isCall() || ins.getFlows().length != 1) {
                    continue;
                }
                Address t = ins.getFlows()[0];
                if (code.contains(t) && getFunctionAt(t) == null && !targets.contains(t)) {
                    targets.add(t);
                }
            }
            for (Address t : targets) {
                if (getFunctionAt(t) != null) {
                    continue;
                }
                Function following = getFunctionAfter(t);
                if (getInstructionAt(t) == null) {
                    clearListing(t, following != null ? following.getEntryPoint().subtract(1) : code.getEnd());
                    disassemble(t);
                }
                if (createFunction(t, null) != null) {
                    total++;
                    progress = true;
                }
            }
        }
        return total;
    }

    private boolean isPrologue(Address a) throws Exception {
        return (getByte(a) & 0xff) == PUSH_EBP && (getByte(a.add(1)) & 0xff) == 0x8B && (getByte(a.add(2)) & 0xff) == 0xEC;
    }

    private boolean followsFunctionEnd(Address a) throws Exception {
        int prev = getByte(a.subtract(1)) & 0xff;
        if (prev == RET) {
            return true;
        }
        for (int pad : PADDING) {
            if (prev == pad) {
                return true;
            }
        }
        return (getByte(a.subtract(3)) & 0xff) == RET_IMM;
    }
}
