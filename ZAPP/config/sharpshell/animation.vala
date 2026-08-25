#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala debug.vala

namespace SharpUtils {
    public class AnimationData {
        public string frame;
    } 
    public class Animation : Farm<AnimationData?> {
        public new string name = "Animation";
        private string ANIMATION_DIR;
        private uint FRAME_RATE;

        public Animation(string _ANIMATION_DIR,uint _FRAME_RATE){
            ANIMATION_DIR = _ANIMATION_DIR;
            FRAME_RATE    = _FRAME_RATE;
        }

        public override AnimationData? harvest(){
            try {
                var dir = Dir.open(ANIMATION_DIR);
                if (dir == null) {
                    SharpDebug.fail(@"Failed to open Dir: $(ANIMATION_DIR)");
                    return null;
                }

                var frames = new GenericArray<string>();
                string frame;
                while ((frame = dir.read_name()) != null){
                    var frame_path = Path.build_filename(ANIMATION_DIR, frame);
                    if (FileUtils.test(frame_path, GLib.FileTest.IS_REGULAR)){
                        frames.add(frame_path);
                    }
                }
                frames.sort(strcmp);

                var real_time = get_monotonic_time();
                var total_frames = real_time * FRAME_RATE / 1000000;
                var current_frame_idx = total_frames % frames.length;
                var current_frame = frames.get((uint) current_frame_idx);

                string content; 
                if(!FileUtils.get_contents(current_frame,out content)){
                    SharpDebug.fail(@"Failed to read frame: $(current_frame)");
                    return null;
                }
                var _AnimationData = new AnimationData(){
                    frame = content.strip()
                };
                return _AnimationData;
            } catch (FileError e) {
                return null;
            }
        }
    } 
}
