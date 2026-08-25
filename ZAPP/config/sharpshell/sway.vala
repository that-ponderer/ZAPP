#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 --pkg json-glib-1.0 sharputils.vala

namespace SharpUtils {
    public class SwayData{
        public GenericArray<int> ws_array;
        public int? ws_focused;
        public GenericArray<int> ws_urgent;
        public string? binding_state;
        public string? focused_ws_title;
    }
    public class Sway : Farm<SwayData?> {
        public enum Actions {SET_WORKSPACE}
        public void action(Actions Action,int actionarg){
            switch (Action) {
                // Switch workspace
                case Actions.SET_WORKSPACE: 
                    string[] cmd = {"swaymsg","workspace",@"$(actionarg)"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
            }
        } 
        private static string? fetch_focused_title (Json.Object tree){
            if (tree.get_boolean_member ("focused")) {
                return tree.get_string_member("name");
            }

            var nodes = tree.get_array_member("nodes");
            var floating_nodes = tree.get_array_member("floating_nodes");

            if (nodes.get_length() == 0) return null; else {
                for (var i = 0; i < nodes.get_length(); i++){
                    var title = fetch_focused_title(
                        nodes.get_element (i).get_object ()
                    );
                    if (title != null) return title.replace ("\n", "");
                }
            }

            if (floating_nodes.get_length() == 0) return null; else {
                for (var i = 0; i < floating_nodes.get_length(); i++){
                    var title = fetch_focused_title(
                        floating_nodes.get_element (i).get_object ()
                    );
                    if (title != null) return title.replace ("\n", "");
                }
            }

            return null;
        }
        public override SwayData? harvest(){
            if (!SharpUtils.is_program("swaymsg")) return null;

            string[] sway_ws_cmd = {"swaymsg","--raw","-t","get_workspaces"}; 
            string[] sway_bs_cmd = {"swaymsg","--raw","-t","get_binding_state"}; 
            string[] sway_tree_cmd = {"swaymsg","--raw","-t","get_tree"}; 

            var sway_ws_out = run(sway_ws_cmd);
            var sway_bs_out = run(sway_bs_cmd);
            var sway_tree_out = run(sway_tree_cmd);

            if (sway_bs_out == null ||
                sway_ws_out == null ||
                sway_tree_out == null) return null;
            
            // create parser
            var ws_parser = new Json.Parser();
            var bs_parser = new Json.Parser();
            var tree_parser = new Json.Parser();

            Json.Node ws_root_node;
            Json.Node bs_root_node;
            Json.Node tree_root_node;

            // load data
            try {
                if (!ws_parser.load_from_data(sway_ws_out)) return null;
                if (!bs_parser.load_from_data(sway_bs_out)) return null;
                if (!tree_parser.load_from_data(sway_tree_out)) return null;

                // extract root
                ws_root_node = ws_parser.get_root();
                bs_root_node = bs_parser.get_root();
                tree_root_node = tree_parser.get_root();
            } catch (Error e){
                return null;
            } 

            var _SwayData = new SwayData(){
                ws_array = new GenericArray<int>(),
                ws_focused = null,
                ws_urgent = new GenericArray<int>(),
                binding_state = null,
                focused_ws_title = null
            };
            
            Json.Array ws_root_array;
            Json.Object bs_root_obj;
            Json.Object tree_root_obj;

            if (ws_root_node.get_node_type() == Json.NodeType.ARRAY &&
                bs_root_node.get_node_type() == Json.NodeType.OBJECT &&
                tree_root_node.get_node_type() == Json.NodeType.OBJECT) {

                ws_root_array = ws_root_node.get_array(); 
                bs_root_obj = bs_root_node.get_object();
                tree_root_obj = tree_root_node.get_object();
            } else return null;
            
            var ok = true;
            ws_root_array.foreach_element((array,index,element)=>{
                if (!ok) return;

                if (element.get_node_type () != Json.NodeType.OBJECT){
                    ok = false;
                    return;
                } 
                var ws_obj = element.get_object();
                
                var ws_num = (int) ws_obj.get_int_member("num");
                _SwayData.ws_array.add(ws_num);

                // take the first focused one, should be only one
                if (_SwayData.ws_focused == null &&
                    ws_obj.get_boolean_member("focused") == true){
                        _SwayData.ws_focused = ws_num;
                    }

                if (ws_obj.get_boolean_member("urgent") == true){
                    _SwayData.ws_urgent.add(ws_num);
                }
            });

            _SwayData.ws_array.sort(intcmp);

            _SwayData.binding_state = bs_root_obj.get_string_member("name");

            var fresh_focused_title = fetch_focused_title(tree_root_obj);

            _SwayData.focused_ws_title = fresh_focused_title;

            return _SwayData;
        }
    }
}
