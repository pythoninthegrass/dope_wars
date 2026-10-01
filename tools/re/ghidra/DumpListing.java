// Prints the disassembly of the functions at the given hex virtual addresses.
// Usage: -postScript DumpListing.java <va>[,<va>...]

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;

public class DumpListing extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            printerr("ERROR: usage: DumpListing.java <va>[,<va>...]");
            return;
        }
        for (String va : args[0].split(",")) {
            Function fn = getFunctionAt(toAddr(Long.parseLong(va.trim(), 16)));
            if (fn == null) {
                printerr("ERROR: no function at " + va);
                continue;
            }
            println("LISTING ; function " + fn.getName() + " @ " + fn.getEntryPoint());
            for (Instruction ins : currentProgram.getListing().getInstructions(fn.getBody(), true)) {
                println("LISTING " + ins.getAddress() + "  " + ins);
            }
        }
    }
}
