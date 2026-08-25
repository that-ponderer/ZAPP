#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0  sharputils.vala

namespace SharpUtils {
    public class TempData {
        public HashTable<string, HashTable<string, GenericArray<string>>> data;
    }
    public class Temp : Farm<TempData?> {
        // Temp
        // └── data
        //     ├── cpu
        //     │   ├── labels → ["avg", "0", "1", "2", "3"]
        //     │   └── inputs → ["51000", "50000", "52000", "51000", "51000"]
        //     │
        //     ├── nvme
        //     │   ├── labels → ["Composite", "Sensor 1"]
        //     │   └── inputs → ["42000", "45000"]
        public override TempData? harvest() {
            var TEMP_DIR = "/sys/class/hwmon";

            Dir dir ; try {
                if ((dir = Dir.open(TEMP_DIR)) == null ) return null;
            } catch (FileError e) {
                return null;
            }
            // =======
            // Sorting 
            // =======
            var file_tree = new HashTable<string,HashTable<
                                        string,
                                        GenericArray<string>
                                        >
                                    >(str_hash,str_equal);

            string s_dirname; while ((s_dirname = dir.read_name()) != null){

                Dir s_dir; try {
                    if ((s_dir = Dir.open("%s/%s".printf(TEMP_DIR,s_dirname)))
                        == null ) continue; 
                } catch (FileError e) {
                    continue;
                }


                Regex input_regex ; Regex label_regex ; try {
                    input_regex = new Regex("^temp[0-9]+_input$");
                    label_regex   = new Regex("^temp[0-9]+_label$");
                } catch (RegexError e) { return null ;}
                
                var s_file_tree = new HashTable<string, GenericArray<string>>
                    (str_hash,str_equal);
                var label_files = new GenericArray<string>();
                var input_files = new GenericArray<string>();

                string ss_dirname;
                while ((ss_dirname = s_dir.read_name()) != null){

                    if (input_regex.match(ss_dirname)) {
                        input_files.add("%s".printf(ss_dirname));
                    } 
                    else if (label_regex.match(ss_dirname)) {
                        label_files.add("%s".printf(ss_dirname));
                    } 
                }
                if (input_files.length > 0) {
                    label_files.sort(strcmp);
                    input_files.sort(strcmp);
                    s_file_tree.insert("labels", label_files);
                    s_file_tree.insert("inputs", input_files);
                    file_tree.insert(s_dirname, s_file_tree);
                }
            }
            var _temp_data = new TempData(){
                // Only the keys need to be hashed for fast lookup.
                data = 
                    new HashTable<string, HashTable<string, GenericArray<string>>>
                    (str_hash,str_equal)
            };
            
            // =======
            // Reading
            // =======
            file_tree.foreach((hwmonfile,table)=>{
                var fs1 = FileStream.open("%s/%s/name".printf(
                    TEMP_DIR,
                    hwmonfile
                    ), "r");
                if (fs1 == null) return;
                var name = fs1.read_line();

                // cpu specific stuff (1)
                Regex cpu_name_regex ; try {
                    cpu_name_regex = new Regex(
                        "(cpu_thermal|coretemp|fam15h_power|k10temp)"
                        ); 
                } catch (RegexError e) {return;} 
                if (cpu_name_regex.match(name)) name = "cpu";
                
                int alt_label = 0;
                int core_label = 0;
                var s_data = new HashTable<string, GenericArray<string>>
                    (str_hash,str_equal);
                var ss_data_labels = new GenericArray<string>();
                var ss_data_inputs = new GenericArray<string>();

                table.lookup("inputs").foreach((inputfile)=>{
                    var fs2 = FileStream.open("%s/%s/%s".printf(
                        TEMP_DIR,
                        hwmonfile,
                        inputfile
                    ), "r");
                    if (fs2 == null) return;
                    var input = fs2.read_line();

                    string label;
                    var labelfile = 
                        "%s_%s".printf(inputfile.split("_")[0],"label");
                    var fs3 = FileStream.open("%s/%s/%s".printf(
                        TEMP_DIR,
                        hwmonfile,
                        labelfile
                    ), "r");
                    if (fs3 == null) {
                        label = "%d".printf(alt_label); 
                        alt_label++;
                    } 
                    else {
                        label = fs3.read_line();
                    }

                    // cpu specific stuff (2)
                    // * only keep the cores, not sure how portable this is
                    if (name == "cpu") {
                        if (! label.has_prefix("Core")){
                            return;
                        } else {
                            label = "%d".printf(core_label);
                            core_label++;
                        }
                    } 
                    ss_data_inputs.add(input);
                    ss_data_labels.add(label);
                });

                // cpu specific stuff (3)
                if (name == "cpu"){
                    long total_temp = 0;
                    int cores = 0;
                    ss_data_inputs.foreach((i)=>{
                        cores++;
                        total_temp += long.parse(i);
                    });
                    long avg_temp = total_temp / cores;
                    ss_data_labels.insert(0, "avg");
                    ss_data_inputs.insert(0, "%ld".printf(avg_temp));
                }

                s_data.insert("labels", ss_data_labels);
                s_data.insert("inputs", ss_data_inputs);
                _temp_data.data.insert(name, s_data);
            });
            return _temp_data;
        }
    }
}
