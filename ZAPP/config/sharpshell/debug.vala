namespace SharpDebug {
    const string RESET = "\033[0m";
    const string C1    = "\033[31m"; 
    const string C2    = "\033[34m"; 
    const string C3    = "\033[33m"; 
    const string C5    = "\033[35m";

    public void log (string message) {
        stdout.printf ("%s[log]%s %s\n", C2, RESET, message);
    }
    public void fail (string message) {
        stderr.printf ("%s[error]%s %s\n", C5, RESET, message);
    }
    public void fatal (string message) {
        stderr.printf ("%s[fatal]%s %s\n", C1, RESET, message);
    }
    public void debug (string line, bool is_debug = true) {
        if (is_debug){
            stderr.printf ("%s[debug]%s %s\n", C3, RESET, line);
        }
    }
}
