#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 debug.vala sharputils.vala

namespace SharpUtils {
    public class TempData {
        public HashTable<string, HashTable<string, GenericArray<string>>> data;
    }
    public class Temp : Farm<TempData?> {
        public new string name = "Temp";
        private string TEMP_DIR = "/sys/class/hwmon";
        private Regex input_file_regex;
        private Regex label_file_regex;
        private Regex cpu_hwmon_regex;

        public Temp(){
            try {
                input_file_regex = new Regex("^temp[0-9]+_input$");
                label_file_regex = new Regex("^temp[0-9]+_label$");
                cpu_hwmon_regex = new Regex(
                    "(cpu_thermal|coretemp|fam15h_power|k10temp)"
                ); 
            } catch (RegexError e) {SharpDebug.fail (e.message);}
        }
        public override TempData? harvest (){
            try {
                // Open top dir
                var dir = Dir.open (TEMP_DIR);
                if (dir == null) return null;
                
                // Need to make to object with all the relevent files first, as 
                // the order recived from Dir.read_name() is not alphabetical.
                var file_tree = 
                    new HashTable<string, HashTable<string, GenericArray<string>>>(
                        str_hash,
                        str_equal
                    );

                // Every sub dir: hwmon[0-9]+
                string s_path_name; 
                while ((s_path_name = dir.read_name()) != null){
                    var s_path = Path.build_filename (TEMP_DIR, s_path_name);
                    if (!FileUtils.test (s_path, FileTest.IS_DIR)) continue;

                    // Open sub dir
                    var s_dir = Dir.open (s_path);
                    if (s_dir == null) return null;
                    
                    var label_files_arr = new GenericArray<string>();
                    var input_files_arr = new GenericArray<string>();
                    var s_file_tree = 
                        new HashTable<string, GenericArray<string>>(
                            str_hash,
                            str_equal
                        );

                    // Iterate through files
                    string ss_path_name;
                    while ((ss_path_name = s_dir.read_name()) != null){
                        // Check if file is regular
                        var ss_path = Path.build_filename (s_path, ss_path_name);
                        if (!FileUtils.test (ss_path, FileTest.IS_REGULAR))
                            continue;
                        // Check if it matchs any of the two patterns
                        if (input_file_regex.match(ss_path_name)) {
                            input_files_arr.add (ss_path);
                        }
                        else if (label_file_regex.match(ss_path_name)) {
                            label_files_arr.add (ss_path);
                        }
                    }
                    // If any input is found
                    if (input_files_arr.length > 0){
                        // Sort
                        input_files_arr.sort (strcmp);
                        label_files_arr.sort (strcmp);
                        // Populate file tree
                        s_file_tree.insert ("inputs", input_files_arr);
                        s_file_tree.insert ("labels", label_files_arr);
                        file_tree.insert (s_path, s_file_tree);
                    }
                }

                var _temp_data = new TempData (){
                    data = new HashTable<
                        string, HashTable<string, GenericArray<string>>>(
                        str_hash,
                        str_equal
                    )
                }; 

                var ok = true;
                // alt 
                var label_alt = 0;
                var name_alt  = 0;
                file_tree.foreach ((hwmondir,label_input_ht)=>{
                    if (!ok) return;

                    var s_data = new HashTable<string, GenericArray<string>>
                        (str_hash,str_equal);
                    var ss_data_labels = new GenericArray<string>();
                    var ss_data_inputs = new GenericArray<string>();

                    // get the name
                    var name_path = Path.build_filename (hwmondir, "name");
                    string name = null;
                    if (FileUtils.test (name_path, FileTest.IS_REGULAR)){
                        var fs = FileStream.open (name_path, "r");
                        if (fs != null) name = fs.read_line ();
                    }
                    if (name == null) name = @"$(name_alt++)";
                    // cpu specific stuff
                    if (cpu_hwmon_regex.match(name)) name = "cpu";

                    var input_files_arr = label_input_ht.lookup("inputs");
                    for (var i = 0; i < input_files_arr.length; i++){
                        var input_file = input_files_arr[i];
                        var fs_input = FileStream.open (input_file, "r");
                        if (fs_input == null) {ok = false; return;}
                        var input = fs_input.read_line ();
                        ss_data_inputs.add (input);

                        // only input files can exist without any label
                        var label = "";
                        var label_file = input_file.substring (
                            0,input_file.length - "_input".length
                        ) + "_label"; 
                        if (FileUtils.test (label_file, FileTest.IS_REGULAR)){
                            var fs_label = FileStream.open (label_file, "r");
                            if (fs_label == null) {ok = false; return;}
                            label = fs_label.read_line ();
                            if (label.has_prefix ("Core")) {
                                label = @"$(label_alt++)";
                            } else if (label == "Package id 0"){
                                label = "avg";
                            }
                        } else {
                            label = @"$(label_alt++)";
                        }
                        ss_data_labels.add (label);
                    }
                    label_alt = 0;

                    s_data.insert("labels", ss_data_labels);
                    s_data.insert("inputs", ss_data_inputs);
                    _temp_data.data.insert(name, s_data);
                });
                if (!ok) return null;

                return _temp_data;
            } 
            catch (FileError e) {
                SharpDebug.fail (e.message);
                return null;
            }
        }
    }
}
