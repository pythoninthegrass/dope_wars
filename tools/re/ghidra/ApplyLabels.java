// Applies a "VA hex,label" CSV (written by tools/re/extract_beermat.py) to the open program.
// Usage: -postScript ApplyLabels.java <labels.csv>

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

public class ApplyLabels extends GhidraScript {
    private static final String VMT_SUFFIX = "_VMT";

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            printerr("ERROR: usage: ApplyLabels.java <labels.csv>");
            return;
        }
        List<String> rows = Files.readAllLines(Paths.get(args[0]));
        int labels = 0;
        int functions = 0;
        int failures = 0;
        for (String row : rows) {
            if (row.isBlank()) {
                continue;
            }
            int comma = row.indexOf(',');
            if (comma < 0) {
                printerr("ERROR: malformed row: " + row);
                failures++;
                continue;
            }
            String name = row.substring(comma + 1).trim();
            try {
                Address addr = toAddr(Long.parseLong(row.substring(0, comma).trim(), 16));
                createLabel(addr, name, true);
                labels++;
                if (!name.endsWith(VMT_SUFFIX)) {
                    disassemble(addr);
                    if (getFunctionAt(addr) == null && createFunction(addr, name) != null) {
                        functions++;
                    }
                }
            } catch (Exception e) {
                printerr("ERROR: " + row + ": " + e.getMessage());
                failures++;
            }
        }
        println("ApplyLabels: applied " + labels + " labels, created " + functions
                + " functions, " + failures + " failures");
    }
}
