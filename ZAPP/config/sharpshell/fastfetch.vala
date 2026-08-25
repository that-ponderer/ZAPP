#!/usr/bin/env -S vala --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class FastfetchData {
        public string hostname = "null";
        public string username = "null";
        public string os = "null";
        public string kernel = "null";
        public int packages = 0;
        public string wm = "null";
        public string cpu_name = "null";
    }
    public class Fastfetch : Farm<FastfetchData?> {
        public new string name = "Fastfetch";

        public override FastfetchData? harvest(){
            if(!SharpUtils.is_program("fastfetch")) return null;
            var data = run({"fastfetch","-j"});
            if (data == null) return null;

            var parser = new Json.Parser();

            Json.Node root_node;
            Json.Array root_node_array;
            
            try {
                if (!parser.load_from_data(data)) return null;
                root_node = parser.get_root();
                
                if (root_node.get_node_type() == Json.NodeType.ARRAY) {
                    var _FastfetchData = new FastfetchData();
                    root_node_array = root_node.get_array();

                    root_node_array.foreach_element((array,index,node)=>{
                        if (node.get_node_type() == Json.NodeType.OBJECT){
                            var node_obj = node.get_object();
                            var type = node_obj.get_string_member("type");
                            switch (type) {
                                case "Title":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.hostname =
                                        result.get_string_member("hostName");
                                    _FastfetchData.username =
                                        result.get_string_member("userName");
                                    break;
                                case "OS":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.os =
                                        result.get_string_member("prettyName");
                                    break;
                                case "Kernel":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.kernel =
                                        result.get_string_member("release");
                                    break;
                                case "Packages":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.packages =
                                        (int) result.get_int_member("all");
                                    break;
                                case "WM":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.wm =
                                        result.get_string_member("prettyName");
                                    break;
                                case "CPU":
                                    var result = 
                                        node_obj.get_object_member("result");
                                    _FastfetchData.cpu_name =
                                        result.get_string_member("cpu");
                                    break;
                            }
                        }
                    });
                    return _FastfetchData;
                }
                else {
                    return null;
                }
            } catch (Error e) {
                return null;
            }
        }
    }
}

