#!/usr/bin/env -S vala --vapidir=./vapi/ --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 --pkg posix --pkg graphene-gobject-1.0 --pkg gee-0.8 --pkg livechart-2 debug.vala sharpshell.vala

struct config {
    public Json.Array COLORS_ARRAY;
    public string FONT_FACE;
    public string BRAIN_DIR;
    public string STYLE_FILE;
    public string RMPC_CONFIG;
    public string RMPC_ALBUMART;
}
config? parse_config (string CONFIG_PATH) {
    var _config = config();
    try {
        var parser = new Json.Parser();
        if (parser.load_from_file (CONFIG_PATH)){
            var root = parser.get_root (); 
            if (root == null) {
                return null;
            } 
            if (root.get_node_type () != Json.NodeType.OBJECT){
                return null;
            }
            var obj_root = root.get_object ();

            _config.COLORS_ARRAY = null;
            if (obj_root.has_member ("colors")){
                var _col_arr = obj_root.get_member ("colors");
                if (_col_arr.get_node_type () == Json.NodeType.ARRAY){
                    _config.COLORS_ARRAY = _col_arr.get_array ();
                }
            }
            if (_config.COLORS_ARRAY == null) return null;

            _config.FONT_FACE = obj_root.get_string_member_with_default (
                "font-face",
                "sans serif"
            );
            _config.BRAIN_DIR = obj_root.get_string_member_with_default (
                "brain-dir",
                "animation/brain"
            );
            _config.STYLE_FILE = obj_root.get_string_member_with_default (
                "style-file",
                "style.css"
            );
            _config.RMPC_CONFIG = obj_root.get_string_member_with_default (
                "rmpc-config-file",
                "support/config.ron"
            );
            _config.RMPC_ALBUMART = obj_root.get_string_member_with_default (
                "rmpc-albumart-file",
                "var/albumart"
            );
            return _config;
        }
        else {
            return null;
        };
    } catch (Error e) {
        return null;
    }
}
string[]? parse_colors (Json.Array colors_array){
    string[] COLORS = {};
    var ok = true;
    colors_array.foreach_element ((array,index,node)=>{
        if (!ok) return;

        if (node.get_node_type () != Json.NodeType.VALUE){
            ok = false;
            return;
        }

        var value_node = node.get_value ();
        if (value_node.type () != Type.STRING){
            ok = false;
            return;
        }

        var color_str = value_node.get_string ();
        if(!Regex.match_simple ("^#[0-9A-Fa-f]{6}$", color_str)){
            ok = false;
            return;
        }

        COLORS += color_str; 
    });
    if (!ok){
        return null;
    }
    if (COLORS.length < 16){
        return null;
    }
    return COLORS;
}
class ErrMsg {
    public static string args = "
Failed To Parse Arguments!
";
    public static string colors = "
Failed To Parse Colors!

FILE: %s/config.json
FORMAT:
    \"colors\":[
        \"#FFFFFF\" x 16
    ]
";
    public static string config = "
Failed To Parse Config!

FILE: %s/config.json
FORMAT:
{
    \"colors-file\": ...,
    \"font-face\": ...,
    \"brain-dir\": ...,
    \"style-file\": ...,
    \"rmpc-config-file\": ...,
    \"rmpc-albumart-file\": ...,
    \"colors\":[...]
}";
}
struct args_data {
    public bool IS_DEBUG;
    public string SOURCE_PATH;
    public string? CONFIG_PATH;
}
args_data? parse_args(string[] args){
    try {
        // /proc/self/exe is a special file provided by the Linux kernel through
        // the /proc virtual filesystem. It a symbolic link that always points
        // to the executable currently being run.
        string exe = FileUtils.read_link("/proc/self/exe");
        string exe_dir = Path.get_dirname(exe);

        var _args_data = args_data(){
            IS_DEBUG = false,
            SOURCE_PATH = exe_dir,
            CONFIG_PATH = null
        };
        OptionEntry[] entries = {
            {
                "debug",'d',
                OptionFlags.NONE,OptionArg.NONE,
                ref _args_data.IS_DEBUG, "Debug mode",null
            },
            {
                "working-dir",'p',
                OptionFlags.NONE,OptionArg.FILENAME,
                ref _args_data.SOURCE_PATH, "Source dir","DIRECTORY"
            },
            {
                "config-file",'c',
                OptionFlags.NONE,OptionArg.FILENAME,
                ref _args_data.CONFIG_PATH, "Config File","FILE"
            }
        };
        var opt_context = new OptionContext (null);
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (entries, null);
        opt_context.parse (ref args);
        
        if (_args_data.CONFIG_PATH == null)
            _args_data.CONFIG_PATH = @"$(_args_data.SOURCE_PATH)/config.json";

        return _args_data;
    } catch (OptionError e) {
        return null;
    } catch (FileError e) {
        return null;
    }
}
int main(string[] args){
    var parsed_args = parse_args (args);
    if (parsed_args == null) {
        SharpDebug.fatal (ErrMsg.args);
        return 1;
    }
    var parsed_config = parse_config (
        parsed_args.CONFIG_PATH
    ); 
    if (parsed_config == null){
        SharpDebug.fatal (ErrMsg.config.printf (parsed_args.SOURCE_PATH));
        return 1;
    }
    var parsed_colors = parse_colors (parsed_config.COLORS_ARRAY); 
    if (parsed_colors == null) {
        SharpDebug.fatal (ErrMsg.colors.printf (parsed_args.SOURCE_PATH));
        return 1;
    }
    var sharpshell = new SharpShell.SharpShell (
        parsed_args.SOURCE_PATH,
        parsed_args.IS_DEBUG,
        parsed_config.STYLE_FILE,
        parsed_colors,
        parsed_config.BRAIN_DIR,
        parsed_config.FONT_FACE,
        parsed_config.RMPC_CONFIG,
        parsed_config.RMPC_ALBUMART
    );
    return sharpshell.run (args);
}
