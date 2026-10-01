// Decompiles every function in the open program to <outdir>/<va>_<name>.c and writes <outdir>/index.tsv.
// Usage: -postScript ExportDecompiled.java <outdir>

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class ExportDecompiled extends GhidraScript {
    private static final int TIMEOUT_SECONDS = 60;

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            printerr("ERROR: usage: ExportDecompiled.java <outdir>");
            return;
        }
        Path out = Paths.get(args[0]);
        Files.createDirectories(out);
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        List<String> index = new ArrayList<>();
        int failures = 0;
        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
        for (Function fn : functions) {
            String va = String.format("%08x", fn.getEntryPoint().getOffset());
            String name = fn.getName().replaceAll("[^A-Za-z0-9_.]", "_");
            String file = va + "_" + name + ".c";
            DecompileResults res = decomp.decompileFunction(fn, TIMEOUT_SECONDS, monitor);
            if (!res.decompileCompleted() || res.getDecompiledFunction() == null) {
                printerr("ERROR: decompile failed at 0x" + va + " " + fn.getName() + ": " + res.getErrorMessage());
                failures++;
                continue;
            }
            String body = "// 0x" + va + " " + fn.getName() + "\n" + res.getDecompiledFunction().getC();
            Files.writeString(out.resolve(file), body);
            index.add(va + "\t" + name + "\t" + file);
        }
        Files.write(out.resolve("index.tsv"), index);
        println("ExportDecompiled: wrote " + index.size() + " functions, " + failures + " failures");
    }
}
