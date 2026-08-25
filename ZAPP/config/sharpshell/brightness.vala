#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class BrightnessData {
        public int perc;
    }
    public class Brightness : Farm<BrightnessData?> {
        public new string name = "Brightness";

        public enum Actions {SET_BRIGHTNESS}
        public void action(Actions Action,uint actionarg){
            switch (Action) {
                case Actions.SET_BRIGHTNESS: 
                    string[] cmd = {"brightnessctl","s",@"$(actionarg)%"};
                    SharpUtils.run(cmd);
                    break;
            }
        } 

        public override BrightnessData? harvest(){
            if (!SharpUtils.is_program("brightnessctl")) return null;

            string[] brightness_get_cmd = {"brightnessctl","g"};
            string[] brightness_get_max_cmd = {"brightnessctl","m"};

            var brightness_out = run(brightness_get_cmd);
            var brightness_out_max = run(brightness_get_max_cmd);

            if (brightness_out == null || brightness_out_max == null) 
                return null;

            var _BrightnessData = new BrightnessData();
            // Needs linking of the Math C library with -X -lm
            _BrightnessData.perc =
                (int) Math.ceil(
                    double.parse(brightness_out) /
                    double.parse(brightness_out_max) *
                    100
                );
            return _BrightnessData;
        }
    }
}
