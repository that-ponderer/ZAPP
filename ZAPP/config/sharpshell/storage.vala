#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class StorageData {
        // In KB
        public HashTable<string, HashTable<string, string>> data;
    }
    public class Storage : Farm<StorageData?> {
        public override StorageData? harvest(){
            if (!SharpUtils.is_program("df")) return null;

            string[] storage_cmd = {"df"};
            var storage_out = run(storage_cmd);
            if (storage_out == null) return null;
            
            var _StorageData = new StorageData(){
                data = new HashTable<string, HashTable<string, string>>(
                    str_hash,str_equal
                )
            };
            foreach (var line in storage_out.split("\n")){
                string[] tok = {};
                foreach (var i in line.split(" ")) {
                    if (i != "") tok += i ;
                }
                if (tok.length < 6) continue;
                
                if (tok[0].contains("/dev/")){
                    var s_data = new HashTable<string, string>(str_hash,str_equal);
                    s_data.insert("storage_total", tok[1]);
                    s_data.insert("storage_usage", tok[2]);
                    s_data.insert("mounted_on", tok[5]);
                    _StorageData.data.insert(tok[0], s_data);
                }
            }
            return _StorageData;
        }
    }
    public class DiskIOData {
        public GenericArray<HashTable<string, string>> disks;
    }
    public class DiskIO : Farm<DiskIOData?> {
        // DiskIO
        //     └── disks
        //         ├── {
        //         │     "name"         : "sda",
        //         │     "read_iops"    : "15",
        //         │     "write_iops"   : "8",
        //         │     "read_kibps"   : "1024",
        //         │     "write_kibps"  : "512",
        //         │     "total_kibps"  : "1536"
        //         │   }
        //         │
        //         └── {
        //               "name"         : "nvme0n1",
        //               "read_iops"    : "184",
        //               "write_iops"   : "92",
        //               "read_kibps"   : "16384",
        //               "write_kibps"  : "8192",
        //               "total_kibps"  : "24576"
        //             }
        private ulong Interval;
        public DiskIO(ulong _Interval) {
            Interval = _Interval; 
        }
        public override DiskIOData? harvest(){
            var FILE_PATH = "/proc/diskstats";
            var file = FileStream.open(FILE_PATH, "r");
            
            var _DiskIOData = new DiskIOData(){
                disks = new GenericArray<HashTable<string, string>>()
            };
            var disks_start = new GenericArray<HashTable<string, string>>();
            var disks_end = new GenericArray<HashTable<string, string>>();

            if (file == null) return null;
            string line = "" ; 
            while ((line = file.read_line()) != null) {
                string[] tok = {};
                foreach (var i in line.split(" ")) {
                    if (i != "") tok += i ;
                }
                if (tok.length < 10) continue;

                var disk = new HashTable<string, string>(str_hash,str_equal);
                disk.insert("name",tok[2]);
                disk.insert("reads",tok[3]);
                disk.insert("writes",tok[7]);
                disk.insert("sectors_read",tok[5]);
                disk.insert("sectors_write",tok[9]);
                disks_start.add(disk);
            }
            Thread.usleep(Interval); file.rewind();
            while ((line = file.read_line()) != null) {
                string[] tok = {};
                foreach (var i in line.split(" ")) {
                    if (i != "") tok += i ;
                }
                if (tok.length < 10) continue;

                var disk = new HashTable<string, string>(str_hash,str_equal);
                disk.insert("name",tok[2]);
                disk.insert("reads",tok[3]);
                disk.insert("writes",tok[7]);
                disk.insert("sectors_read",tok[5]);
                disk.insert("sectors_write",tok[9]);
                disks_end.add(disk);
            }
            if (disks_start.length != disks_end.length)  return null; 
            for (var i = 0; i < disks_start.length; i++){
                var ht_start = disks_start.get(i);
                var ht_end = disks_end.get(i);
                var ht = new HashTable<string, string>(str_hash,str_equal);
                ht.insert("name", ht_start.lookup("name"));
                ht.insert("read_iops",
                    "%ld".printf(
                        (
                            long.parse(ht_end.lookup("reads")) -
                            long.parse(ht_start.lookup("reads"))
                        ) / ((long) Interval / 1000000) 
                    )
                );
                ht.insert("write_iops",
                    "%ld".printf(
                        (
                            long.parse(ht_end.lookup("writes")) -
                            long.parse(ht_start.lookup("writes"))
                        ) / ((long) Interval / 1000000) 
                    )
                );
                ht.insert("read_kibps",
                    // linux tracks sectors of 512 byts, hence the '/ 2'
                    "%ld".printf(
                        (
                            long.parse(ht_end.lookup("sectors_read")) -
                            long.parse(ht_start.lookup("sectors_read"))
                        ) / ((long) Interval / 1000000 * 2) 
                    )
                );
                ht.insert("write_kibps",
                    "%ld".printf(
                        (
                            long.parse(ht_end.lookup("sectors_write")) -
                            long.parse(ht_start.lookup("sectors_write"))
                        ) / ((long) Interval / 1000000 * 2) 
                    )
                );
                ht.insert("total_kibps",
                    "%ld".printf(
                        ((
                            long.parse(ht_end.lookup("sectors_read")) -
                            long.parse(ht_start.lookup("sectors_read"))
                        ) / ((long) Interval / 1000000 * 2)) +
                        ((
                            long.parse(ht_end.lookup("sectors_write")) -
                            long.parse(ht_start.lookup("sectors_write"))
                        ) / ((long) Interval / 1000000 * 2)) 
                    )
                );
                _DiskIOData.disks.add(ht);
            }
            return _DiskIOData;
        }
    }
}
