#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 shaputils.vala

namespace SharpUtils {
    public class BatData {
        public HashTable<string, HashTable<string, string>> data;
    }
    public class Bat : Farm<BatData?> {
        public new string name = "Bat"; 
        public override BatData? harvest(){
            try {
                var BAT_DIR_NAME = "/sys/class/power_supply";

                Dir dir; dir = Dir.open(BAT_DIR_NAME);
                if (dir == null) return null;
                
                var _BATData = new BatData(){
                    data = new HashTable<string, HashTable<string, string>>(
                        str_hash,
                        str_equal
                    )
                };

                string s_dir_name = "";
                while ((s_dir_name = dir.read_name()) != null) {
                    var s_dir = Path.build_filename(BAT_DIR_NAME,s_dir_name); 
                    if(!FileUtils.test(s_dir, FileTest.IS_DIR))
                        continue;

                    if (s_dir_name.contains("BAT")) {
                        var capacity_file = FileStream.open(
                            Path.build_filename(s_dir,"capacity"),
                            "r"
                        ); 
                        var status_file = FileStream.open(
                            Path.build_filename(s_dir,"status"),
                            "r"
                        ); 
                        if (capacity_file == null || status_file == null)
                            continue;

                        var s_data = new HashTable<string, string>(
                            str_hash,
                            str_equal
                        );
                        s_data.insert("capacity", capacity_file.read_line());
                        s_data.insert("status", status_file.read_line());
                        _BATData.data.insert(s_dir_name, s_data);
                    }
                }
                return _BATData; 
            } 
            catch (FileError e) {
                return null;
            }
        }
    }
}
