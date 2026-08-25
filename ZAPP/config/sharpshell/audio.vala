#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 debug.vala sharputils.vala

namespace SharpUtils {
    public class VolData {
        public int source_vol_perc;
        public int sink_vol_perc;
        public bool source_is_muted;
        public bool sink_is_muted;
    }
    public class Vol : Farm<VolData?> {
        public new string name = "Vol";
        public enum Actions {SET_SINK_VOL,SET_SOURCE_VOL}
        public void action(Actions Action,uint actionarg){
            switch (Action) {
                case Actions.SET_SINK_VOL: 
                    string[] cmd = {
                        "wpctl",
                        "set-volume",
                        "@DEFAULT_AUDIO_SINK@",
                        @"$(actionarg)%"
                    };
                    SharpUtils.run(cmd);
                    break;
                case Actions.SET_SOURCE_VOL: 
                    string[] cmd = {
                        "wpctl",
                        "set-volume",
                        "@DEFAULT_AUDIO_SOURCE@",
                        @"$(actionarg)%"
                    };
                    SharpUtils.run(cmd);
                    break;
            }
        } 
        public override VolData? harvest(){
            if (!SharpUtils.is_program("wpctl")) return null;

            string[] source_cmd = {"wpctl","get-volume","@DEFAULT_SOURCE@"}; 
            string[] sink_cmd = {"wpctl","get-volume","@DEFAULT_SINK@"}; 

            var source_out = run(source_cmd);
            var sink_out =   run(sink_cmd);

            if (source_cmd == null || sink_cmd == null){
                return null;
            }

            var _VolData = new VolData(){
                source_is_muted = false,
                sink_is_muted   = false
            }; 
            
            var source_out_tokenized = SharpUtils.tokenize(source_out, 2);
            var sink_out_tokenized   = SharpUtils.tokenize(sink_out, 2);

            if (source_out_tokenized == null ||sink_out_tokenized == null)
                return null;

            _VolData.source_vol_perc = 
                (int) (double.parse(source_out_tokenized[1]) * 100);
            _VolData.sink_vol_perc = 
                (int) (double.parse(sink_out_tokenized[1]) * 100) ;

            if (source_out_tokenized.length >= 3 &&
                source_out_tokenized[2].strip() == "[MUTED]"){
                _VolData.source_is_muted = true;
            }

            if (sink_out_tokenized.length >= 3 &&
                sink_out_tokenized[2].strip() == "[MUTED]") {
                _VolData.sink_is_muted = true;
            }
            return _VolData;
        }
    }
}

