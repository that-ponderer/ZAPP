#!/usr/bin/env -S vala --pkg gtk4 --pkg posix --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 sharputils.vala debug.vala

namespace SharpUtils {
    public class CavaData {
        public GenericArray<int> data;
    }
    public class Cava : FarmAsync<CavaData?> {
        private Subprocess _Subprocess;
        private File       TempFile;
        private bool       closing = false;
        private uint       restart_timeout = 5000; // (ms)
        private uint       framerate = 60; 
        private uint       bars      = 16; 
        public new string  name = "Cava";

        // SIGSTP: A catchable and ignorable signal generated on Ctrl + z
        // SIGSTOP: A un-catchable and un-ignorable version of SIGSTP
        // Both pause code execution of the process
        public void pause() {
            if (_Subprocess != null)
                _Subprocess.send_signal(Posix.Signal.STOP);
        }
        public void resume() {
            if (_Subprocess != null)
                _Subprocess.send_signal(Posix.Signal.CONT);
        }
        public void close(){
            closing = true;
            if (_Subprocess != null)
                _Subprocess.send_signal(Posix.Signal.TERM);
        }
        private async void read(DataInputStream stream){
            while (true) {
                try {
                    var line = yield stream.read_line_async();
                    // EOF is pushed if the process exits, read_line_async
                    // returns null on EOF.
                    if (line == null) break;
                    var data = new GenericArray<int>();
                    var ok = true;

                    foreach (var i in line.split(";")) {
                        if (i.strip() != "") {
                            int tok; 
                            if(!int.try_parse(i, out tok)) {
                                SharpDebug.fail("Failed to parse cava output");
                                ok = false;
                                break;
                            }
                            data.add(tok) ;
                        }
                    }
                    if (!ok) continue;
                    feed(new CavaData(){data = data});

                } catch (Error e) {SharpDebug.fail(e.message);break;}
            }
            // Getting past the loop essencially means 
            // the program quit.
            try {
                // On UNIX the child becomes a zombie after 
                // exiting, until parent calls wait on it.
                yield _Subprocess.wait_async();
                TempFile.delete();

            } catch (Error e) {
                SharpDebug.fail(e.message);
            }

            // If close(), resume() or pause() tries to access
            // _Subprocess after the process exits.
            _Subprocess = null;
            TempFile = null;

            // restart if exits without being manually closed.
            if (!closing){
                SharpDebug.fail(
                    "Cava exited unexpectedly: Attepting restart."
                );
                Timeout.add_once(restart_timeout, ()=>{
                    if (closing)
                        return;
                    RunCava(framerate,bars);
                    SharpDebug.log ("Restarted Cava.");
                });
            }
        }
        private void RunCava(uint _FRAME_RATE, uint _BARS){
            try {
                var CAVA_CONFIG = @"
                [general]
                framerate = $(_FRAME_RATE)
                bars = $(_BARS)
                [input]
                method = pipewire
                source = auto
                [output]
                method = raw
                raw_target = /dev/stdout
                data_format = ascii
                ascii_max_range = 100
                bar_delimiter = 59
                ";

                // create a temp file
                FileIOStream iostream;
                TempFile = File.new_tmp(null, out iostream);
                if (TempFile == null) return;

                // get the output_stream (binary stream)
                var outstream = iostream.output_stream;
                if(outstream.write(CAVA_CONFIG.data) == -1) {
                    SharpDebug.fail("Failed to write to stream");
                }
                // Closing the stream will implicitly cause a flush
                if(!outstream.close()) {
                    SharpDebug.fail("Failed to close stream");
                }

                // start cava
                _Subprocess = new Subprocess.newv(
                    {"cava","-p",TempFile.get_path()},
                    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
                );

                // InputStream is strictly binary, DataInputStream 
                // lets you read line by line.
                InputStream input_stream = _Subprocess.get_stdout_pipe ();
                DataInputStream data_input_stream = 
                    new DataInputStream(input_stream); 
                read.begin(data_input_stream);

            } catch (Error e) {SharpDebug.fail(e.message);return;}
        }
        public Cava(uint _framerate = 60, uint _bars = 16) {
            framerate = _framerate;
            bars      = _bars;
            if (SharpUtils.is_program("cava")) RunCava(framerate,bars);
        }
    } 
}
