#!/usr/bin/env -S vala --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class RMPCData {
        public string title;
        public string albumart_path;
        public GenericArray<string> artist;
        public bool repeat;
        public bool random;
        public string single;
        public string consume;
        public string state;
        public uint duration;
        public uint elapsed;
    }
    public class RMPC : Farm<RMPCData?> {
        private string CONFIG;
        private string ALBUMART_FILE;

        public enum Actions {
            TOGGLEPAUSE,
            NEXT,
            PREV,
            TOGGLEREPEAT,
            TOGGLERANDOM,
            TOGGLESINGLE,
            TOGGLECONSUME,
            SEEK
        }
        public void action(Actions Action,uint actionarg = 0){
            switch (Action) {
                case Actions.TOGGLEPAUSE: 
                    string[] cmd = {"rmpc","togglepause"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.NEXT: 
                    string[] cmd = {"rmpc","next"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.PREV: 
                    string[] cmd = {"rmpc","prev"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.TOGGLEREPEAT: 
                    string[] cmd = {"rmpc","togglerepeat"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.TOGGLERANDOM: 
                    string[] cmd = {"rmpc","togglerandom"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.TOGGLESINGLE: 
                    string[] cmd = {"rmpc","togglesingle"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.TOGGLECONSUME: 
                    string[] cmd = {"rmpc","toggleconsume"};
                    SharpUtils.run(cmd);
                    plant();
                    break;
                case Actions.SEEK: 
                    string[] cmd = {"rmpc","seek",@"$(actionarg)"};
                    SharpUtils.run(cmd);
                    break;
            }
        } 

        public RMPC(string _CONFIG, string _ALBUMART_FILE){
            CONFIG        = _CONFIG;
            ALBUMART_FILE = _ALBUMART_FILE;
        }
        public override RMPCData? harvest() {
            if(!SharpUtils.is_program("rmpc")) return null;

            var song_info = run({"rmpc","-c",CONFIG,"song"});
            var status_info = run({"rmpc","-c",CONFIG,"status"});
            run({"rmpc","-c",CONFIG,"albumart","-o",ALBUMART_FILE});

            if (song_info == null || status_info == null) return null;
            var _RMPCData = new RMPCData(){
                artist = new GenericArray<string>(),
                albumart_path = ALBUMART_FILE
            };
            var parser_song = new Json.Parser();
            var parser_status = new Json.Parser();

            try {
                if (!parser_song.load_from_data(song_info) || 
                    !parser_status.load_from_data(status_info)){
                    return null;
                }
                var root_song = parser_song.get_root();
                var root_status = parser_status.get_root();
                var obj_song = root_song.get_object();
                var obj_song_metadata = obj_song.get_object_member("metadata");
                var obj_status = root_status.get_object();

                // Title
                _RMPCData.title = obj_song_metadata.get_string_member("title");  
                // Artist
                var obj_artist = obj_song_metadata.get_member("artist");
                if (obj_artist.get_node_type() == Json.NodeType.ARRAY){
                    var arr_artist = obj_artist.get_array();
                    arr_artist.foreach_element((array,index,node)=>{
                        _RMPCData.artist.add(node.get_string()); 
                    });
                } 
                else {
                    _RMPCData.artist.add(obj_artist.get_string()); 
                }
                // States
                _RMPCData.repeat = obj_status.get_boolean_member("repeat");
                _RMPCData.random = obj_status.get_boolean_member("random");
                _RMPCData.single = obj_status.get_string_member("single");
                _RMPCData.consume = obj_status.get_string_member("consume");
                _RMPCData.state = obj_status.get_string_member("state");
                // Progress 
                var obj_elapsed = obj_status.get_object_member("elapsed");
                var obj_duration = obj_status.get_object_member("duration");
                _RMPCData.elapsed = (uint)  obj_elapsed.get_int_member("secs");
                _RMPCData.duration = (uint) obj_duration.get_int_member("secs");
            } catch (Error e) {
                return null;
            }
            return _RMPCData;
        }
    }
}


