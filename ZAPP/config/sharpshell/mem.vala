#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class MemData {
        public long mem_total;
        public long mem_usage;
        public long swap_total;
        public long swap_usage;
    }
    public class Mem : Farm<MemData?> {
        public new string name = "Memory";
        private string MEM_FILE = "/proc/meminfo";

        public override MemData? harvest(){
            var mem_fs = FileStream.open(MEM_FILE, "r");
            if (mem_fs == null) return null;

            var _MemData = new MemData();

            string line;
            while ((line = mem_fs.read_line()) != null) {
                var tok = SharpUtils.tokenize(line, 2);
                if (tok == null) continue;

                switch (tok[0]) {
                    case "MemTotal:":
                        _MemData.mem_total = long.parse(tok[1]);
                        break;
                    case "MemAvailable:":
                        // MemTotal always comes before MemAvailable, so its fine.
                        _MemData.mem_usage = 
                            _MemData.mem_total - long.parse(tok[1]); 
                        break;
                    case "SwapTotal:":
                        _MemData.swap_total = long.parse(tok[1]);          
                        break;
                    case "SwapFree:":
                        // Same thing here
                        _MemData.swap_usage = 
                            _MemData.swap_total - long.parse(tok[1]); 
                        break;
                }
            }
            return _MemData;
        }
    }
}

