#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 debug.vala sharputils.vala 

namespace SharpUtils {
    public class CPUData {
        public string info_name;    
        public uint info_cores; 
        public double usage_avg;    
        public Array<double> usage_cores; 
        public long freq_max_avg;
        public long freq_min_avg;
        public long freq_avg_avg;
        public Array<long> freq_max_cores;
        public Array<long> freq_min_cores;
        public Array<long> freq_avg_cores;
    }
    public class CPU : Farm<CPUData?> {
        public new string name = "CPU";
        private ulong Interval;
        private Regex CPUFreqRegex;

        public CPU(ulong _Interval = 1000000){
            Interval = _Interval; 
            try {CPUFreqRegex = new Regex ("^cpu[0-9]+");} 
            catch (RegexError e) {SharpDebug.fail(e.message);}
        } 

        private class CPUInfo {
            public string info_name;    
            public uint   info_cores; 

            public static CPUInfo? fetch() {
                var _cpu_info = new CPUInfo();
                var INFO_FILE="/proc/cpuinfo";

                FileStream info;
                if ((info = FileStream.open (INFO_FILE,"r")) == null) return null;
                
                string line;
                while ((line = info.read_line ()) != null && line != "") {
                    var key = line.split (":")[0].strip();
                    var value = line.split (":")[1].strip();
                    switch (key) {
                        case "model name" :
                            _cpu_info.info_name = value;
                            break;
                        case "siblings" :
                            _cpu_info.info_cores = uint.parse (value);
                            break;
                    } 
                }
                return _cpu_info;
            }
        }
        private class CPUFreq {
            public long freq_max_avg;
            public long freq_min_avg;
            public long freq_avg_avg;
            public Array<long> freq_max_cores;
            public Array<long> freq_min_cores;
            public Array<long> freq_avg_cores;

            public static CPUFreq? fetch(Regex _CPUFreqRegex){
                try {
                    var FREQ_DIR="/sys/devices/system/cpu";

                    var _cpu_freq = new CPUFreq(){
                        freq_max_cores = new Array<long> (),
                        freq_min_cores = new Array<long> (),
                        freq_avg_cores = new Array<long> ()
                    };

                    Dir dir; if ((dir = Dir.open(FREQ_DIR)) == null) return null;
                    if (_CPUFreqRegex == null) return null;
                    
                    // Hald all the matching dir
                    var cpu_dir_arr = new GenericArray<string>();

                    // Find the dirs
                    string entry; while ((entry = dir.read_name()) != null) {
                        var entry_path = Path.build_filename(FREQ_DIR, entry);
                        var ok = FileUtils.test(entry_path, GLib.FileTest.IS_DIR)
                                 && _CPUFreqRegex.match(entry);
                        if (ok) cpu_dir_arr.add(entry_path);
                    }

                    // Sort the dirs
                    cpu_dir_arr.sort(strcmp);

                    cpu_dir_arr.foreach((entry_path)=>{
                        var freq_min_fs = FileStream.open (
                            Path.build_filename(
                                entry_path,
                                "cpufreq",
                                "cpuinfo_min_freq"
                            ),"r"
                        );
                        var freq_avg_fs = FileStream.open (
                            Path.build_filename(
                                entry_path,
                                "cpufreq",
                                "cpuinfo_avg_freq"
                            ),"r"
                        );
                        var freq_max_fs = FileStream.open (
                            Path.build_filename(
                                entry_path,
                                "cpufreq",
                                "cpuinfo_max_freq"
                            ),"r"
                        );
                        if (freq_min_fs != null &&
                            freq_avg_fs != null && 
                            freq_max_fs != null) {

                            var freq_min_core =    
                                long.parse(freq_min_fs.read_line ());
                            var freq_avg_core = 
                                long.parse(freq_avg_fs.read_line ());
                            var freq_max_core = 
                                long.parse(freq_max_fs.read_line ());

                            _cpu_freq.freq_max_cores.append_val(freq_max_core);
                            _cpu_freq.freq_avg_cores.append_val(freq_avg_core);
                            _cpu_freq.freq_min_cores.append_val(freq_min_core);
                        }
                    });

                    long total_freq_max = 0;
                    long total_freq_min = 0;
                    long total_freq_avg = 0;
                    foreach (var core in _cpu_freq.freq_max_cores){
                        total_freq_max += core;
                    }
                    foreach (var core in _cpu_freq.freq_avg_cores){
                        total_freq_avg += core;
                    }
                    foreach (var core in _cpu_freq.freq_min_cores){
                        total_freq_min += core;
                    }

                    _cpu_freq.freq_max_avg = 
                        total_freq_max / _cpu_freq.freq_max_cores.length;
                    _cpu_freq.freq_avg_avg = 
                        total_freq_avg / _cpu_freq.freq_avg_cores.length;
                    _cpu_freq.freq_min_avg = 
                        total_freq_min / _cpu_freq.freq_min_cores.length;

                    return _cpu_freq;
                } 
                catch (FileError e) {SharpDebug.fail(e.message);return null;}
            }
        }
        private class CPUUsage {
            public double        usage_avg;    
            public Array<double> usage_cores; 

            private class CPUStat {
                public Array<long> stat_avg;
                public Array<Array<long>> stat_cores;

                public static CPUStat? fetch(){
                    var USAGE_FILE="/proc/stat";

                    FileStream stat;
                    if ((stat = FileStream.open(USAGE_FILE, "r")) == null ) {
                        return null;
                    }

                    var _cpu_stat = new CPUStat(){
                        stat_avg = new Array<long>(),
                        stat_cores = new Array<Array<long>>()
                    };

                    string line;

                    // read loop
                    while ((line = stat.read_line()) != null) {

                        string[] words = line.split(" ");

                        if (words[0].has_prefix("cpu")) {
                            // avg
                            if (words[0] == "cpu") {
                                for (var i = 1; i < words.length; i++) {
                                    // skip empty values
                                    if (words[i] == "") continue;
                                    
                                    long value = long.parse(words[i]);
                                    _cpu_stat.stat_avg.append_val(value);
                                }
                            }
                            else {
                                var core_stat = new Array<long>();
                                for (var i = 1; i < words.length; i++) {
                                    if (words[i] == "") continue;

                                    long value = long.parse(words[i]);
                                    core_stat.append_val(value);

                                }
                                _cpu_stat.stat_cores.append_val (core_stat);
                            }
                        }
                    }
                    return _cpu_stat;
                }
            }
            public static CPUUsage? fetch(ulong Interval){
                var cpu_stat_start = CPUStat.fetch();
                Thread.usleep (Interval);
                var cpu_stat_end = CPUStat.fetch();
                
                if ((cpu_stat_start == null)
                    || (cpu_stat_end == null)) return null;

                // Time spent in user mode
                var delta_user_avg = (
                    cpu_stat_end.stat_avg.index (0) -
                    cpu_stat_start.stat_avg.index (0)
                    );
                // Time spent for running low priority niced processes  
                var delta_nice_avg = (
                    cpu_stat_end.stat_avg.index (1) -
                    cpu_stat_start.stat_avg.index (1)  
                    );
                // Time spent in system mode
                var delta_system_avg = (
                    cpu_stat_end.stat_avg.index (2) -
                    cpu_stat_start.stat_avg.index (2)  
                    );
                // Time spent in doing nothing
                var delta_idle_avg = (
                    cpu_stat_end.stat_avg.index (3) -
                    cpu_stat_start.stat_avg.index (3)  
                    );
                // Time spent waiting for I/O
                var delta_iowait_avg = (
                    cpu_stat_end.stat_avg.index (4) -
                    cpu_stat_start.stat_avg.index (4)  
                    );
                // Time spent serving hardware interupts
                var delta_irq_avg = (
                    cpu_stat_end.stat_avg.index (5) -
                    cpu_stat_start.stat_avg.index (5)  
                    );
                // Time spent serving software interupts
                var delta_softirq_avg = (
                    cpu_stat_end.stat_avg.index (6) -
                    cpu_stat_start.stat_avg.index (6)  
                    );
                // Time stolen by hypervisors
                var delta_steal_avg = (
                    cpu_stat_end.stat_avg.index (7) -
                    cpu_stat_start.stat_avg.index (7)  
                    );
                
                var active_jiffies_avg = (
                    delta_user_avg + 
                    delta_nice_avg + 
                    delta_system_avg +
                    delta_irq_avg +
                    delta_softirq_avg +
                    delta_steal_avg
                    );
                var idle_jiffies_avg = delta_idle_avg + delta_iowait_avg;

                var _cpu_usage = new CPUUsage() {
                    usage_avg = (double) active_jiffies_avg / 
                        (active_jiffies_avg + idle_jiffies_avg) * 100,
                    usage_cores = new Array<double>()
                };

                // Cores
                for (var i = 0; i < cpu_stat_start.stat_cores.length; i++) {

                    var delta_user_core = (
                        cpu_stat_end.stat_cores.index (i).index (0) -
                        cpu_stat_start.stat_cores.index (i).index (0)
                        );
                    var delta_nice_core = (
                        cpu_stat_end.stat_cores.index (i).index (1) -
                        cpu_stat_start.stat_cores.index (i).index (1)
                        );
                    var delta_system_core = (
                        cpu_stat_end.stat_cores.index (i).index (2) -
                        cpu_stat_start.stat_cores.index (i).index (2)
                        );
                    var delta_idle_core = (
                        cpu_stat_end.stat_cores.index (i).index (3) -
                        cpu_stat_start.stat_cores.index (i).index (3)
                        );
                    var delta_iowait_core = (
                        cpu_stat_end.stat_cores.index (i).index (4) -
                        cpu_stat_start.stat_cores.index (i).index (4)
                        );
                    var delta_irq_core = (
                        cpu_stat_end.stat_cores.index (i).index (5) -
                        cpu_stat_start.stat_cores.index (i).index (5)
                        );
                    var delta_softirq_core = (
                        cpu_stat_end.stat_cores.index (i).index (6) -
                        cpu_stat_start.stat_cores.index (i).index (6)
                        );
                    var delta_steal_core = (
                        cpu_stat_end.stat_cores.index (i).index (7) -
                        cpu_stat_start.stat_cores.index (i).index (7)
                        );
                
                    var active_jiffies_core = (
                        delta_user_core + 
                        delta_nice_core + 
                        delta_system_core +
                        delta_irq_core +
                        delta_softirq_core +
                        delta_steal_core
                        );
                    var idle_jiffies_core = delta_idle_core + delta_iowait_core;
                    var usage_core = (double) active_jiffies_core / 
                        (active_jiffies_core + idle_jiffies_core) * 100;
                    _cpu_usage.usage_cores.append_val (usage_core);
                }
                return _cpu_usage;
            }
        }
        
        public override CPUData? harvest(){
            var _cpu_data = new CPUData(){
                usage_cores = new Array<double>(), 
                freq_max_cores = new Array<long>(),
                freq_min_cores = new Array<long>(),
                freq_avg_cores = new Array<long>()
            }; 

            var _cpu_info = CPUInfo.fetch();
            var _cpu_usage = CPUUsage.fetch(Interval);
            var _cpu_freq = CPUFreq.fetch(CPUFreqRegex);

            if (_cpu_info == null ||
                _cpu_usage == null ||
                _cpu_freq == null ) return null;

            _cpu_data.info_name = _cpu_info.info_name;
            _cpu_data.info_cores = _cpu_info.info_cores;
            _cpu_data.usage_avg = _cpu_usage.usage_avg;
            _cpu_data.usage_cores = _cpu_usage.usage_cores;
            _cpu_data.freq_max_avg = _cpu_freq.freq_max_avg;
            _cpu_data.freq_min_avg = _cpu_freq.freq_min_avg;
            _cpu_data.freq_avg_avg = _cpu_freq.freq_avg_avg;
            _cpu_data.freq_max_cores = _cpu_freq.freq_max_cores;
            _cpu_data.freq_min_cores = _cpu_freq.freq_min_cores;
            _cpu_data.freq_avg_cores = _cpu_freq.freq_avg_cores;
            return _cpu_data;
        }
    }
}
