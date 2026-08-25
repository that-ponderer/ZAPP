#!/usr/bin/env -S vala --vapidir=./vapi/ --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 --pkg posix --pkg graphene-gobject-1.0 --pkg gee-0.8 --pkg livechart-2 debug.vala

namespace SharpUtils {
    //  Notes: 
    //      virtual (method) : Requires a default implementation, subclassess 
    //          may or may not `override` it.
    //      abstract (method) :  Just the definition, no implementation, 
    //          subclassess must `override` it.
    //      abstract (class) : A class containing an abstract method must be 
    //          abstract itself.
    
    public abstract class Farm<Food> : Object {
        public string name = "null";
        private Food _Food = null;
        public signal void feed(Food _Food);
        public abstract Food harvest();
        public void plant(){
            var food = harvest();
            if (food == null) 
                return;
            _Food = food;
            Idle.add(()=>{
                feed(food);
                return false;
            });
        }
    } 
    public class FarmAsync<Food> {
        public signal void feed(Food _Food);
    }
 	public int intcmp(int a, int b){
		return (int) (a > b) - (int) (a < b);
	}
    public string? run(string[] cmd){
        try {
            var sp = new Subprocess.newv(
                cmd,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
            );
            // communicate automatically waits, but get_successful() does not
            string out; 
            string err; 
            sp.communicate_utf8 (null, null,out out,out err);
            if (!sp.get_successful()) {
                var cmd_str = "";
                foreach (var tok in cmd) cmd_str += @"$(tok) ";
                SharpDebug.fail(@"cmd:[ $(cmd_str)] err: $(err)");
                return null;
            }
            return out;
        } 
        catch (Error e) {
            return null;
        }
    }
    public async string? run_async(string[] cmd, bool print_out = false){
        try {
            var sp = new Subprocess.newv(
                cmd,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
            );
            string out; 
            string err; 
            yield sp.communicate_utf8_async (null, null,out out,out err);
            if (!sp.get_successful()) {
                var msg = "";
                foreach (var tok in cmd) msg += @"$(tok) ";
                if (print_out){
                    SharpDebug.fail(@"\ncmd:[ $(msg)]\nerr: $(err)\nout: $(out)");
                } else {
                    SharpDebug.fail(@"\ncmd:[ $(msg)]\nerr: $(err)");
                }
                return null;
            }
            return out;
        } 
        catch (Error e) {
            return null;
        }
    }
    public string? scroll_text (
        string text,
        uint width,
        uint interval = 1000000, // (us)
        string spacer = "  ",
        string prefix = "",
        string postfix = ""
        ) {
        if (text.char_count() <= width) return text;

        string buffer = spacer + text;
        if ((prefix.char_count() + postfix.char_count()) >= width) return null; 

        int64 rt = GLib.get_monotonic_time ();
        int offset = (int)((rt / interval) % buffer.char_count());

        while (buffer.char_count() < (width + offset)) {
            buffer += spacer + text;
        }
        return "%s%s%s".printf (
            prefix,
            buffer.slice (
                buffer.index_of_nth_char (offset),
                buffer.index_of_nth_char (
                    offset + 
                    (width - (prefix.char_count() + postfix.char_count())))
                ),
            postfix
        );
    }
    public string simple_animate(string[] chars, uint interval = 1000000){
        return chars[((get_monotonic_time() / interval) % chars.length)];
    }
    public bool simple_cmp_str_arr(string[] A, string[] B){
        if (A.length != B.length){
            return false;
        }
        // order does not matter
        for (var i = 0 ; i < A.length; i++) {
            var found = false;
            for (var j = 0 ; j < B.length; j++) {
                if (A[i] == B[j]) found = true;
            }
            if (!found) return false;
        }
        return true;
    }
    public void empty_box(Gtk.Box _Box){
        while (_Box.get_first_child() != null){
            _Box.remove(_Box.get_first_child());
        }
    }
    public bool is_program(string prog){
        if (Environment.find_program_in_path(@"$(prog)") == null){
            SharpDebug.fail(@"Failed to find $(prog) in $$PATH");
            return false;
        }
        else return true;
    }
    public string[]? tokenize(string line, uint min_length){
        string[] tok = {};
        // If line is fully blank
        if (line.strip() == "") return null;

        foreach (var i in line.split(" ")) {
            if (i.strip() != "") tok += i.strip();
        }
        if (tok.length < min_length){
            //SharpDebug.fail(@"Unexpected length of output: $(line)");
            return null;
        }
        return tok;
    }
}
