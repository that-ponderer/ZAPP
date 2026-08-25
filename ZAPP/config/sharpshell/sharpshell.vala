#!/usr/bin/env -S vala --vapidir=./vapi/ --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 --pkg posix --pkg graphene-gobject-1.0 --pkg gee-0.8 --pkg livechart-2 animation.vala audio.vala bat.vala brightness.vala bt.vala cava.vala cpu.vala date.vala debug.vala fastfetch.vala main.vala mem.vala net.vala rmpc.vala sharpshell.vala sharputils.vala sidebar.vala storage.vala sway.vala temp.vala topbar.vala

namespace SharpShell {
    public class SharpShell: Gtk.Application {
        // Consts 
        // ======
        private string   SOURCE_PATH;
        private bool     IS_DEBUG;
        private string   STYLE_FILE;
        private ulong    PLANTING_INTERVAL; // (us)
        private string[] COLORS;
        private string   BRAIN_DIR;
        private string   FONT_FACE;
        private uint     BRAIN_FPS;
        private string   RMPC_CONFIG_FILE;
        private string   RMPC_ALBUMART_FILE;

        // Workers
        // =======
        private Thread<void>[] workers;
        private bool run_workers = true;

        // Farms 
        // =====
        private SharpUtils.Sway       Sway;
        private SharpUtils.Date       Date;
        private SharpUtils.CPU        CPU;
        private SharpUtils.Temp       Temp;
        private SharpUtils.Mem        Mem;
        private SharpUtils.Storage    Storage;
        private SharpUtils.Net        Net;
        private SharpUtils.Bat        Bat;
        private SharpUtils.Brightness Brightness;
        private SharpUtils.Vol        Vol;
        private SharpUtils.Animation  Brain;
        private SharpUtils.Fastfetch  Fastfetch;
        private SharpUtils.DiskIO     DiskIO;
        private SharpUtils.RMPC       RMPC;
        private SharpUtils.Cava       Cava;
        private SharpUtils.BT         BT;

        // SideBar 
        private SideBar.States SideBarState      = SideBar.States.SLIM;
        private Mutex          SideBarStateMutex = Mutex();
        private Cond           SideBarStateCond  = Cond();

        private void init (){
            // Set the currect locale
            GLib.Intl.setlocale(GLib.LocaleCategory.ALL, "");
            // Use memory efficient cpu renderer
            Environment.set_variable ("GSK_RENDERER", "cairo", true); 
            // Handle Ctrl+C
            Unix.signal_add (Posix.Signal.INT, ()=>{
                quit ();
                return false;
            });
        }
        private void init_farms(){
            // Sync
            // ----
            // Instant Producing Farms
            Sway       = new SharpUtils.Sway();
            Date       = new SharpUtils.Date();
            Temp       = new SharpUtils.Temp();
            Mem        = new SharpUtils.Mem();
            Storage    = new SharpUtils.Storage();
            Bat        = new SharpUtils.Bat();
            Brightness = new SharpUtils.Brightness();
            Vol        = new SharpUtils.Vol();
            Brain      = new SharpUtils.Animation(
                @"$(SOURCE_PATH)/$(BRAIN_DIR)",
                BRAIN_FPS
            );
            Fastfetch  = new SharpUtils.Fastfetch();
            RMPC       = new SharpUtils.RMPC(
                @"$(SOURCE_PATH)/$(RMPC_CONFIG_FILE)",
                @"$(SOURCE_PATH)/$(RMPC_ALBUMART_FILE)"
            );
            BT         = new SharpUtils.BT();
            // Sleeping Farms
            CPU        = new SharpUtils.CPU(PLANTING_INTERVAL);
            Net        = new SharpUtils.Net(PLANTING_INTERVAL);
            DiskIO     = new SharpUtils.DiskIO(PLANTING_INTERVAL);
            // Async
            // -----
            Cava       = new SharpUtils.Cava();
        }
        private Thread<void> make_sidebar_expanded_farm_worker(
            owned SharpUtils.Farm[] _Farm_Arr,
            ulong             _PLANTING_INTERVAL = PLANTING_INTERVAL
            ){
            return new Thread<void>(null,()=>{
                while (true){
                    SideBarStateMutex.lock();
                    while ((SideBarState != SideBar.States.EXPANDED) &&
                        (run_workers))
                        SideBarStateCond.wait(SideBarStateMutex);
                    if (!run_workers) {
                        SideBarStateMutex.unlock();
                        break;
                    }
                    SideBarStateMutex.unlock();
                    var timer_start = get_monotonic_time ();
                    foreach (var f in _Farm_Arr)
                        f.plant();
                    var timer_end = get_monotonic_time ();
                    var timer_delta = timer_end - timer_start;
                    var interval = _PLANTING_INTERVAL;
                    if (timer_delta < interval){
                        interval -= (int) timer_delta;
                        Thread.usleep (interval);
                    }
                }
            });
        }
        // Note: the array _Farm_Arr will be finalized, when the function
        // quits after making the thread, own it.
        private delegate bool BoolDelegate();
        private Thread<void> make_farm_worker(
            owned SharpUtils.Farm[] _Farm_Arr,
            ulong                   _PLANTING_INTERVAL = PLANTING_INTERVAL
            ){
            return new Thread<void>(null,()=>{
                while (true){
                    SideBarStateMutex.lock();
                    if (!run_workers) {
                        SideBarStateMutex.unlock();
                        break;
                    }
                    SideBarStateMutex.unlock();
                    var timer_start = get_monotonic_time ();

                    foreach (var f in _Farm_Arr){
                        f.plant();
                    }
                    var timer_end = get_monotonic_time ();
                    var timer_delta = timer_end - timer_start;
                    var interval = _PLANTING_INTERVAL;
                    if (timer_delta < interval){
                        interval -= (int) timer_delta;
                        Thread.usleep (interval);
                    }
                }
            });
        }
        // Conditional Workers
        private void init_sidebar_expanded_workers(){
            workers += make_sidebar_expanded_farm_worker(
                {Brain},
                (PLANTING_INTERVAL / BRAIN_FPS)
            );
            // Instant Workers
            workers += make_sidebar_expanded_farm_worker({Fastfetch,RMPC,BT});
            // Sleeping Workers
            workers += make_sidebar_expanded_farm_worker({DiskIO},0);
        }
        // Full-Time Workers
        private void init_workers(){
            // Instant Workers
            workers += make_farm_worker({
                    Sway,
                    Date,
                    Temp,
                    Mem,
                    Storage,
                    Bat,
                    Brightness,
                    Vol
                }
            );
            // Sleeping Workers
            workers += make_farm_worker({CPU},0);
            workers += make_farm_worker({Net},0);
        }
        private void deinit_workers(){
            // Async Farms 
            Cava.close();
            // Sync Farms
            SideBarStateMutex.lock();
            run_workers = false;
            SideBarStateCond.broadcast();
            SideBarStateMutex.unlock();
            foreach (var w in workers){
                w.join ();
            }
        }
        public void plant_now<Food>(SharpUtils.Farm<Food> _Farm){
            _Farm.plant(); 
        }
        public override void shutdown (){
            // Call the default shutdown protocol
            base.shutdown ();
            SharpDebug.log ("Shutting Down!");
            deinit_workers ();
        }
        private void init_style (){
            var provider = new Gtk.CssProvider();
            provider.load_from_path(@"$(SOURCE_PATH)/$(STYLE_FILE)");
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }
        public SharpShell(
            string   _SOURCE_PATH,
            bool     _IS_DEBUG,
            string   _STYLE_FILE,
            string[] _COLORS,
            string   _BRAIN_DIR,
            string   _FONT_FACE,
            string   _RMPC_CONFIG_FILE,
            string   _RMPC_ALBUMART_FILE,
            uint     _BRAIN_FPS = 60,
            ulong    _PLANTING_INTERVAL = 1000000
        ){
            SOURCE_PATH        = _SOURCE_PATH;
            IS_DEBUG           = _IS_DEBUG;
            STYLE_FILE         = _STYLE_FILE;
            COLORS             = _COLORS;
            BRAIN_DIR          = _BRAIN_DIR;
            FONT_FACE          = _FONT_FACE;
            BRAIN_FPS          = _BRAIN_FPS;
            PLANTING_INTERVAL  = _PLANTING_INTERVAL;
            RMPC_CONFIG_FILE   = _RMPC_CONFIG_FILE;
            RMPC_ALBUMART_FILE = _RMPC_ALBUMART_FILE;
        }
        public override void activate(){
            init ();
            init_style ();
            init_farms();
            init_workers ();
            init_sidebar_expanded_workers();
            var _TopBar = new TopBar (
                this,
                Sway,
                Date,
                CPU,
                Temp,
                Mem,
                Storage,
                Net,
                Bat
            );
            _TopBar.present ();

            var _SideBar = new SideBar(
                this,
                IS_DEBUG,
                Brightness,
                Vol,
                Brain,
                Fastfetch,
                CPU,
                Mem,
                DiskIO,
                RMPC,
                Cava,
                BT,
                COLORS,
                FONT_FACE
            );
            _SideBar.present();
            _TopBar.present_border();

            _SideBar.state_change.connect((_SideBarState)=>{
                // Signal the Cond
                SideBarStateMutex.lock();
                SideBarState = _SideBarState;
                SideBarStateCond.broadcast();
                SideBarStateMutex.unlock();
                _TopBar.update_border();
            });
        }
    }
}
