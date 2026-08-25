#!/usr/bin/env -S vala --vapidir=./vapi/ --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 --pkg posix --pkg graphene-gobject-1.0 --pkg gee-0.8 --pkg livechart-2 animation.vala audio.vala bat.vala brightness.vala bt.vala cava.vala cpu.vala date.vala debug.vala fastfetch.vala main.vala mem.vala net.vala rmpc.vala sharpshell.vala sharputils.vala sidebar.vala storage.vala sway.vala temp.vala topbar.vala

namespace SharpShell {
    public class SideBar : Gtk.ApplicationWindow {
        // States
        // =======
        public enum States {SLIM,EXPANDED}
        public States State  = States.SLIM;
        public signal void state_change(States state);
        private StateBinding[] StateBindingArr = {};

        public void set_state(States new_state) {
            // Avoids duplicate state_change
            if (State == new_state)
                return;
            State = new_state;
            state_change(new_state);
        }
        public void toggle_state() {
            set_state(
                State == States.SLIM
                    ? States.EXPANDED
                    : States.SLIM
            );
        }
        private delegate void Action(); // A bare bone delegate
        private class StateBinding {
            //  Note: 
            //      For reference types (class, delegates, arrays, many GLib
            //      types), parameters are borrowed (unowned) by default (not
            //      ref counted). on_expanded() and  on_slim() will leave the
            //      scope if not set to owned, later when state_change is
            //      invoked, accessing them becomes invalid.
            //       
            //  active = true : on_expanded() has been called, but on_slim() not 
            //                 yet.

            private Action on_expanded;
            private Action on_slim;
            private bool active = false;
            private unowned SideBar SideBar;

            private void state_change_handler(States state){
                switch (state) {
                    case States.EXPANDED:
                        if (active)
                            return;
                        on_expanded();
                        active = true;
                        break;
                    case States.SLIM:
                        if (!active)
                            return;
                        on_slim();
                        active = false;
                        break;
                }
            }
            public void remove_binding() {
                this.SideBar.state_change.disconnect(state_change_handler);
            }
            public StateBinding(
                SideBar      sidebar,
                owned Action expanded,
                owned Action slim,
                bool         impatient 
                ) {
                this.SideBar = sidebar;
                // (owned) is used to transfer ownership
                on_expanded = (owned) expanded;
                on_slim =     (owned) slim;
                sidebar.state_change.connect(state_change_handler);
                // Sync initial state.
                if (impatient && sidebar.State == States.EXPANDED){
                    active = true;
                    on_expanded();
                }
                else if (impatient && sidebar.State == States.SLIM){
                    active = false;
                    on_slim();
                }
            }
        }
        private StateBinding bind_to_state(
        owned Action on_expanded,
        owned Action on_slim,
        bool         impatient = false
        ) {
            return new StateBinding(
                this,
                (owned) on_expanded,
                (owned) on_slim,
                impatient
            );
        }
        // Fixes 
        private GenericArray<LiveChart.Config> BrokenLivechartConfigs = 
            new GenericArray<LiveChart.Config>(); 
        private void handle_broken_configs(){
            Timeout.add(100, ()=>{
                if (State == States.SLIM) 
                    return false; 
                BrokenLivechartConfigs.foreach((config)=>{
                    config.time.current = get_real_time () / config.time.conv_us;
                });
                return true;
            });
        } 
        private class ActionBarWidget : Gtk.Box {
            public ActionBarWidget(
                SideBar               _Sidebar,
                SharpUtils.Brightness _Brightness,
                SharpUtils.Vol        _Vol
                ) {
                orientation = Gtk.Orientation.VERTICAL;
                spacing = 0;
                css_classes = {"action_bar_widget"};
                valign = Gtk.Align.END;
                // .___________.
                // | Expander  |
                // `````````````
                var expander_widget = new ExpanderWidget(_Sidebar);
                prepend(expander_widget);
                // ._____________.
                // | Brightness  |
                // ```````````````
                var brightness_widget = new BrightnessWidget(_Brightness);
                prepend(brightness_widget);
                // ._______________.
                // | Audio Source  |
                // `````````````````
                var audio_sink_widget = new AudioSinkWidget(_Vol);
                prepend(audio_sink_widget);
                // ._____________.
                // | Audio Sink  |
                // ```````````````
                var audio_source_widget = new AudioSourceWidget(_Vol);
                prepend(audio_source_widget);
            }
        }
        private class ExpanderWidget : TopBar.ButtonWithLabel {
            public ExpanderWidget (SideBar _Sidebar){
                css_classes = {"expander_widget"};
                label.set_text ("");
                clicked.connect (()=>{
                    _Sidebar.toggle_state(); 
                });
            } 
        }
        public class LabeledScaleWithIcon : Gtk.Box {
            public Gtk.Scale Scale;
            public Gtk.Label LabelIcon;
            public Gtk.Label Label;
            public LabeledScaleWithIcon(
                Gtk.Orientation _Orientation,
                string?         _StrIcon,
                bool            _ScaleInverted = true
                ){
                orientation = _Orientation;
                spacing     = 0;
                // Scale
                Scale = new Gtk.Scale.with_range (_Orientation, 0, 100, 1);
                Scale.inverted = _ScaleInverted;
                Scale.css_classes = {"scale"};
                // Icon
                LabelIcon = new Gtk.Label(_StrIcon);
                LabelIcon.xalign = 0.5f;
                LabelIcon.css_classes = {"icon"};
                // Label
                Label = new Gtk.Label(null);
                Label.xalign = 1f;
                Label.css_classes = {"label"};
                
                append(Scale);
                append(Label);
                append(LabelIcon);
            }
        }
        private class BrightnessWidget : LabeledScaleWithIcon {
            private void change_brightness(uint value){
                Scale.set_value(value);
                Label.set_text (@"$(value)%");
            }
            public BrightnessWidget(SharpUtils.Brightness _Brightness){
                base(Gtk.Orientation.VERTICAL,"󰖨");
                css_classes = {"brightness_widget"};

                Scale.change_value.connect((scroll,value)=>{
                    _Brightness.action(
                        SharpUtils.Brightness.Actions.SET_BRIGHTNESS,
                        (uint) Math.fmax(1,value)
                    );
                    change_brightness((uint)Math.fmax(1,value));
                    return true;
                });
                _Brightness.feed.connect((_BrightnessData)=>{
                    change_brightness(_BrightnessData.perc);
                });
            }
        }
        private class AudioSinkWidget : LabeledScaleWithIcon {
            public void set_vol(uint value){
                Label.set_text (@"$(value)%");
                Scale.set_value (value);
            }
            public AudioSinkWidget(SharpUtils.Vol _Vol) {
                base(Gtk.Orientation.VERTICAL,null);
                css_classes = {"audio_sink_widget"};

                Scale.change_value.connect((scroll,value)=>{
                    _Vol.action(SharpUtils.Vol.Actions.SET_SINK_VOL, (uint)value);
                    set_vol((uint)value);
                    return true;
                });
                _Vol.feed.connect((_VolData)=>{
                    set_vol(_VolData.sink_vol_perc);
                    var icon_sink = "󰝟";
                    if (_VolData.sink_is_muted){
                        icon_sink = "󰝟";
                    }
                    else {
                        if (_VolData.sink_vol_perc == 0){
                            icon_sink = "󰖁";
                        } 
                        else if (_VolData.sink_vol_perc <= 30){
                            icon_sink = "󰕿";
                        } 
                        else if (_VolData.sink_vol_perc <= 60){
                            icon_sink = "󰖀";
                        } 
                        else if (_VolData.sink_vol_perc <= 100){
                            icon_sink = "󰕾";
                        } 
                   }
                   LabelIcon.set_text (icon_sink);
                });
            }
        }
        private class AudioSourceWidget : LabeledScaleWithIcon {
            public void set_vol(uint value){
                Label.set_text (@"$(value)%");
                Scale.set_value (value);
            }
            public AudioSourceWidget(SharpUtils.Vol _Vol) {
                base(Gtk.Orientation.VERTICAL,null);
                css_classes = {"audio_source_widget"};
                Scale.change_value.connect((scroll,value)=>{
                    _Vol.action(SharpUtils.Vol.Actions.SET_SOURCE_VOL,(uint)value);
                    set_vol((uint)value);
                    return true;
                });
                _Vol.feed.connect((_VolData)=>{
                    set_vol(_VolData.source_vol_perc);
                    var icon_source = _VolData.source_is_muted ? "󰍭" : "󰍬";
                    LabelIcon.set_text (icon_source);
                });
            }
        }
        private class BrainWidget : Gtk.Box {
            private Gtk.Label Label;

            private void brain_feed_handler(
                SharpUtils.AnimationData? _BrainData
                ){
                Label.set_text(_BrainData.frame);
            }
            public BrainWidget(
                SideBar              _SideBar,
                SharpUtils.Animation _Brain,
                SharpUtils.Fastfetch _FastFetch,
                string[]             _COLORS
                ) {
                orientation = Gtk.Orientation.HORIZONTAL;
                spacing     = 0;
                css_classes = {"brain_widget"};

                var overlay = new Gtk.Overlay();
                Label = new Gtk.Label(null);
                overlay.set_child(Label);
                append(overlay);
                
                var fastfetch = new FastFetchWidget(
                    _FastFetch,
                    _COLORS
                );
                fastfetch.Label.halign       = Gtk.Align.START;
                fastfetch.Label.valign       = Gtk.Align.START;
                fastfetch.Label.margin_top   = 4;
                fastfetch.Label.margin_start = 4;
                overlay.add_overlay(fastfetch);

                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    () => _Brain.feed.connect(brain_feed_handler),
                    () => _Brain.feed.disconnect(brain_feed_handler)
                );
            }
        }
        private class FastFetchWidget : Gtk.Box {
            public Gtk.Label Label;
            public FastFetchWidget(
                SharpUtils.Fastfetch _FastFetch,
                string[] _COLORS
                ){
                orientation = Gtk.Orientation.HORIZONTAL;
                spacing     = 0;
                css_classes = {"fastfetch_widget"};
                Label       = new Gtk.Label(null);
                append(Label);
                _FastFetch.feed.connect((_FastFetchData)=>{
                    Label.set_markup(@"<span 
foreground=\"$(_COLORS[15])\"
background=\"$(_COLORS[0])\"
bgalpha=\"70%\"
>┌─<span 
background=\"$(_COLORS[1])\" 
foreground=\"$(_COLORS[0])\" 
bgalpha=\"100%\"> $(_FastFetchData.hostname) </span>
├> <span foreground=\"$(_COLORS[13])\"></span> $(_FastFetchData.username)
├> <span foreground=\"$(_COLORS[6])\"></span> $(_FastFetchData.os) (btw)
├> <span foreground=\"$(_COLORS[5])\"></span> $(_FastFetchData.kernel)
├> <span foreground=\"$(_COLORS[2])\">󰏓</span> $(_FastFetchData.packages)
└> <span foreground=\"$(_COLORS[14])\">󱂬</span> $(_FastFetchData.wm)</span>"
                    );
                });
            }
        }
        private static Gdk.RGBA get_col(string s){
            var rgba = Gdk.RGBA();
            rgba.parse(s);
            return rgba;
        }
        private static LiveChart.Chart get_graph(
            GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
            string[]                       _COLORS,
            string                         _FONT_FACE,
            string                         unit,
            double?                        y_axis_fixed_max,
            float?                         y_axis_tick_interval,
            uint                           height
            ){
            var _config = new LiveChart.Config ();
            // X axis
            _config.x_axis.tick_length = 60;
            _config.x_axis.axis.color = get_col(_COLORS[8]);
            _config.x_axis.lines.color = get_col(_COLORS[8]);

            _config.x_axis.labels.font.color = get_col(_COLORS[8]);
            _config.x_axis.labels.font.size = 8;
            _config.x_axis.labels.font.face = _FONT_FACE;
            _config.x_axis.labels.font.weight = Cairo.FontWeight.BOLD;
            // Y axis
            _config.y_axis.unit = unit;
            if (y_axis_fixed_max != null)
                _config.y_axis.fixed_max = y_axis_fixed_max;
            if (y_axis_tick_interval != null)
                _config.y_axis.tick_interval = y_axis_tick_interval;
            _config.y_axis.axis.color = get_col(_COLORS[8]);
            _config.y_axis.lines.color = get_col(_COLORS[8]);
            _config.y_axis.labels.font.color = get_col(_COLORS[8]);
            _config.y_axis.labels.font.size = 10;
            _config.y_axis.labels.font.face = _FONT_FACE;
            _config.y_axis.labels.font.weight = Cairo.FontWeight.BOLD;
            // Padding
            _config.padding.smart &= ~LiveChart.AutoPadding.BOTTOM;
            _config.padding.smart &= ~LiveChart.AutoPadding.RIGHT;
            _config.padding.right = 8;
            _config.padding.bottom = 16;
            _BrokenLivechartConfigs.add(_config);
            // Chart
            var _graph = new LiveChart.Chart (_config);
            _graph.hexpand = true;
            _graph.height_request = (int) height;
            _graph.legend.visible = false;
            _graph.background.color = get_col(_COLORS[0]);
            return _graph;
        }
        private static LiveChart.Serie get_smooth_line_serie(string col){
            var _renderer = new LiveChart.SmoothLine();
            _renderer.line.color = get_col(col);
            _renderer.line.width = 2;
            return new LiveChart.Serie ("",_renderer);
        }
        private static LiveChart.Serie get_smooth_line_area_serie(string col){
            var _renderer = new LiveChart.SmoothLineArea();
            _renderer.line.color = get_col(col);
            _renderer.line.width = 2;
            return new LiveChart.Serie ("",_renderer);
        }
        private static LiveChart.Serie get_bar_serie(string col){
            var _renderer = new LiveChart.Bar();
            _renderer.line.color = get_col(col);
            _renderer.line.width = 2;
            return new LiveChart.Serie ("",_renderer);
        }
        private static string simplify_kib(long kb,int precision = 2){
            var _string = "";
            if (kb > 999999){
                _string = @"%0.$(precision)lf GiB".printf (
                    ((double) kb / 1000000)
                );
            }
            else if (kb > 999){
                _string = @"%0.$(precision)lf MiB".printf (
                    ((double) kb / 1000)
                );
            }
            else {
                _string = "%lld KiB".printf (
                    kb
                );
            }
            return _string;
        }
        private class CPUAvgGraphWidget : Gtk.Box {
            private string[]         COLORS;
            private LiveChart.Serie  Serie;
            private LiveChart.Config ConfigGraph;
            private Gtk.Label        Label;

            private void cpu_feed_handler(SharpUtils.CPUData? _CPUData){
                var freq = _CPUData.freq_avg_avg;
                var freq_str = "%0.1lfGHz".printf (((double)freq) / 1000000);

                var value = _CPUData.usage_avg; 
                var value_str = "%0.1lf".printf(_CPUData.usage_avg); 
                Serie.add_with_timestamp(
                    value,
                    get_real_time() 
                        / ConfigGraph.time.conv_us
                );

                var markup_label = @"<span
                foreground=\"$(COLORS[0])\"
                background=\"$(COLORS[2])\"
                font_size=\"8pt\"
                > </span><span
                foreground=\"$(COLORS[0])\"
                background=\"$(COLORS[2])\"
                font_size=\"8pt\"
                > $(value_str)%/$(freq_str) </span>";
                Label.set_markup (markup_label);
            }
            
            public CPUAvgGraphWidget (
                SideBar                        _SideBar,
                SharpUtils.CPU                 _CPU,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _Height
                ) {
                COLORS = _COLORS;

                Label = new Gtk.Label (null);
                Label.halign = Gtk.Align.END;
                Label.valign = Gtk.Align.START;
                Label.margin_top = 4;
                Label.margin_end = 4;

                var graph = get_graph(
                    _BrokenLivechartConfigs,
                    _COLORS,
                    _FONT_FACE,
                    "%",100,20,_Height
                );

                ConfigGraph = graph.config;
                Serie = get_smooth_line_area_serie(_COLORS[2]);
                graph.add_serie (Serie);

                var overlay = new Gtk.Overlay ();
                overlay.set_child (graph);
                overlay.add_overlay (Label);
                append(overlay);
                
                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    () => _CPU.feed.connect(cpu_feed_handler),
                    () => _CPU.feed.disconnect(cpu_feed_handler)
                );
            }
        }
        private class CPUCoresGraphWidget : Gtk.Box {
            private bool Rendered = false;
            private GenericArray<LiveChart.Serie> Series
                = new GenericArray<LiveChart.Serie>();
            private LiveChart.Chart Graph; 
            private LiveChart.Config ConfigGraph; 
            private string[] COLORS; 

            private void cpu_feed_handler(SharpUtils.CPUData? _CPUData){
                    var usage = _CPUData.usage_cores;
                    if (!Rendered){
                        Rendered = true;
                        for (var i = 0; i < usage.length; i++){
                            var serie = get_smooth_line_serie(
                                COLORS[((i + 1) % COLORS.length)]
                            );
                            Graph.add_serie (serie);
                            Series.add (serie);
                        }
                    }
                    for (var i = 0; i < usage.length; i++){
                        var value = usage.index (i);
                        var serie = Series.get (i); 
                        serie.add_with_timestamp(
                            value,
                            get_real_time() 
                                / ConfigGraph.time.conv_us
                        );
                    }
            }
            public CPUCoresGraphWidget(
                SideBar                        _SideBar,
                SharpUtils.CPU                 _CPU,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _Height
                ) {
                COLORS = _COLORS;
                Graph = get_graph(
                    _BrokenLivechartConfigs,
                    _COLORS,
                    _FONT_FACE,
                    "%",100,20,_Height
                );
                ConfigGraph = Graph.config;
                append(Graph);

                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    ()=>_CPU.feed.connect(cpu_feed_handler),
                    ()=>_CPU.feed.disconnect(cpu_feed_handler)
                );
            }
        }
        private class CPUCoresBarsWidget : Gtk.Box {
            private bool Rendered = false;
            private GenericArray<Chunk> Chunks = new GenericArray<Chunk>();
            private string[] COLORS;
            private Gtk.Box  BoxInner;

            private void cpu_feed_handler(SharpUtils.CPUData? _CPUData){
                var usage = _CPUData.usage_cores;
                var freq  = _CPUData.freq_avg_cores;
                if (!Rendered) {
                    Rendered = true;
                    for (var i = 0; i < usage.length; i++){
                        var chunk = new Chunk(
                            @"$(i)",
                            COLORS, 
                            COLORS[((i + 1) % COLORS.length)]
                        );
                        Chunks.add(chunk);
                        BoxInner.append(chunk);
                    }
                }
                for (var i = 0; i < Chunks.length; i++){
                    var usage_value = usage.index (i);
                    var usage_str = "%.1lf%%".printf (usage_value);

                    var freq_value = freq.index (i);
                    var freq_str = "%0.1lfGHz".printf (
                        ((double)freq_value) / 1000000
                    );

                    var markup_bars = @"<span
                    font_size=\"8pt\"
                    foreground=\"$(COLORS[8])\"
                    >[$(freq_str)/$(usage_str)]</span>";
                    Chunks[i].InfoLevelBar.set_value (usage_value);
                    Chunks[i].InfoLabel.set_markup (markup_bars);
                }
            }

            private class Chunk : Gtk.Box { 
                public Gtk.Label    InfoLabel;
                public Gtk.LevelBar InfoLevelBar;
                public Chunk(string Name,string[] _COLORS,string _COLOR){
                    orientation = Gtk.Orientation.VERTICAL;
                    spacing     = 0;
                    css_classes = {"chunk"};

                    var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                    header.css_classes = {"header"};

                    var markup_name = @"<span
                    background=\"$(_COLOR)\"
                    foreground=\"$(_COLORS[0])\"
                    font_size=\"8pt\"
                    > CORE: $(Name) </span><span
                    foreground=\"$(_COLOR)\"
                    >🭬</span>";
                    var name = new Gtk.Label(null);
                    name.hexpand = true;
                    name.xalign  = 0;
                    name.set_markup(markup_name);

                    InfoLabel = new Gtk.Label(null);

                    header.append(name);
                    header.append(InfoLabel);
                    append(header);

                    InfoLevelBar = new Gtk.LevelBar ();
                    InfoLevelBar.css_classes = {"levelbar"};
                    InfoLevelBar.set_max_value (100);
                    InfoLevelBar.set_min_value (0);
                    InfoLevelBar.hexpand = true;
                    InfoLevelBar.add_offset_value("low", 30);
                    InfoLevelBar.add_offset_value("high", 60);
                    InfoLevelBar.add_offset_value("full", 100);
                    append(InfoLevelBar);
                }
            }
            public CPUCoresBarsWidget(
                SideBar        _SideBar,
                SharpUtils.CPU _CPU,
                string[]       _COLORS
                ) {
                orientation = Gtk.Orientation.HORIZONTAL;
                spacing     = 0;
                vexpand     = false;
                css_classes = {"bars_widget"};
                COLORS      = _COLORS;

                var scrolled_window = new Gtk.ScrolledWindow();
                scrolled_window.vexpand = true;
                scrolled_window.hexpand = true;
                append(scrolled_window);

                BoxInner = new Gtk.Box(
                    Gtk.Orientation.VERTICAL,0
                );
                scrolled_window.set_child(BoxInner);
                
                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    ()=> _CPU.feed.connect(cpu_feed_handler), 
                    ()=> _CPU.feed.disconnect(cpu_feed_handler) 
                );
            }
        }
        private class CPUPanelWidget : Gtk.Box {
            private enum States {A,B,C}
            private States State = States.A;
            private signal void state_change(States _State);

            private uint     HeaderChars;
            private ulong    HeaderScrollInterval;
            private string[] COLORS;

            private Gtk.Label NameLabel;

            private void fastfetch_feed_handler(
                SharpUtils.FastfetchData? _FastFetchData
                ){
                var cpu_name = SharpUtils.scroll_text (
                    _FastFetchData.cpu_name,
                    HeaderChars,
                    (uint) HeaderScrollInterval
                );
                var markup_label = @"<span
                foreground=\"$(COLORS[4])\"
                background=\"$(COLORS[0])\"
                >🭋</span
                ><span
                foreground=\"$(COLORS[0])\"
                background=\"$(COLORS[4])\"
                > $(cpu_name) </span
                ><span
                foreground=\"$(COLORS[4])\"
                background=\"$(COLORS[0])\"
                >🭀</span>";
                NameLabel.set_markup(markup_label);
            }
            public CPUPanelWidget (
                SideBar                        _SideBar,
                SharpUtils.CPU                 _CPU,   
                SharpUtils.Fastfetch           _FastFetch,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _Height,
                uint                           _HeaderChars,
                ulong                          _HeaderScrollInterval
                ){
                HeaderChars          = _HeaderChars;
                HeaderScrollInterval = _HeaderScrollInterval;
                COLORS               = _COLORS;
                orientation          = Gtk.Orientation.VERTICAL;
                spacing              = 0;
                css_classes          = {"cpu_panel_widget"};

                // Header
                var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                header.css_classes = {"header"};
                append(header);
                
                NameLabel = new Gtk.Label(null);
                NameLabel.xalign = 0f;
                NameLabel.hexpand = true;
                header.append(NameLabel);

                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    () => _FastFetch.feed.connect(fastfetch_feed_handler),  
                    () => _FastFetch.feed.disconnect(fastfetch_feed_handler)  
                );

                string[] button_css_class         =  {"button_nav"};
                string[] button_css_class_focused =  {
                    "button_nav",
                    "button_nav_focused"
                };
                var button_a = new Gtk.Button.with_label("क");
                button_a.css_classes = button_css_class;
                button_a.clicked.connect(()=>{state_change(States.A);});
                header.append(button_a);

                var button_b = new Gtk.Button.with_label("ख");
                button_b.css_classes = button_css_class;
                button_b.clicked.connect(()=>{state_change(States.B);});
                header.append(button_b);

                var button_c = new Gtk.Button.with_label("ग");
                button_c.css_classes = button_css_class;
                button_c.clicked.connect(()=>{state_change(States.C);});
                header.append(button_c);

                // Stack
                var stack  = new Gtk.Stack();
                stack.css_classes = {"stack"};
                append(stack);

                var graph_avg = new CPUAvgGraphWidget(
                    _SideBar,
                    _CPU,
                    _BrokenLivechartConfigs, 
                    _COLORS, 
                    _FONT_FACE, 
                    _Height
                );
                stack.add_child(graph_avg);
                var graph_cores = new CPUCoresGraphWidget(
                    _SideBar,
                    _CPU,
                    _BrokenLivechartConfigs, 
                    _COLORS, 
                    _FONT_FACE, 
                    _Height
                );
                stack.add_child(graph_cores);
                var bars_cores = new CPUCoresBarsWidget(
                    _SideBar,
                    _CPU, 
                    _COLORS
                );
                stack.add_child(bars_cores);

                state_change.connect((State)=>{
                    button_a.css_classes = button_css_class;
                    button_b.css_classes = button_css_class;
                    button_c.css_classes = button_css_class;
                     switch (State) {
                         case States.A:
                            this.State = States.A;
                            stack.set_visible_child(graph_avg);
                            button_a.css_classes = button_css_class_focused;
                            break;
                         case States.B:
                            this.State = States.B;
                            stack.set_visible_child(graph_cores);
                            button_b.css_classes = button_css_class_focused;
                            break;
                         case States.C:
                            this.State = States.C;
                            stack.set_visible_child(bars_cores);
                            button_c.css_classes = button_css_class_focused;
                            break;
                     }
                });
                state_change(States.A);
            }
        }
        private class MemPanelWidget : Gtk.Box {
            private LiveChart.Serie  SerieMem;
            private LiveChart.Serie  SerieSwap;
            private LiveChart.Config ConfigGraph;
            private Gtk.Label        InfoLabel;
            private string[]         COLORS;

            private void mem_feed_handler(SharpUtils.MemData? _MemData){
                var mem_usage = _MemData.mem_usage;
                var mem_total = _MemData.mem_total;
                var mem_usage_perc = 
                    ((double)mem_usage) / mem_total * 100;

                var mem_usage_str = simplify_kib(mem_usage);

                var swap_usage = _MemData.swap_usage;
                var swap_total = _MemData.swap_total;
                var swap_usage_perc =
                    swap_total > 0
                        ? ((double)swap_usage) / swap_total * 100
                        : 0;

                var swap_usage_str = simplify_kib(swap_usage);

                SerieMem.add_with_timestamp (
                    mem_usage_perc,
                    get_real_time() 
                        / ConfigGraph.time.conv_us
                );
                SerieSwap.add_with_timestamp (
                    swap_usage_perc,
                    get_real_time()
                        / ConfigGraph.time.conv_us
                );
                InfoLabel.set_markup(@"<span
                foreground=\"$(COLORS[0])\"
                background=\"$(COLORS[1])\"
                font_size=\"8pt\"
                > $(mem_usage_str)| $(swap_usage_str)|󰍛 </span>");
            }
            public MemPanelWidget (
                SideBar                        _SideBar,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _MemGraphHeight,
                SharpUtils.Mem                 _Mem
                ){
                COLORS      = _COLORS;
                css_classes = {"mem_panel_widget"};

                var overlay = new Gtk.Overlay();

                var graph = get_graph(
                    _BrokenLivechartConfigs,
                    _COLORS,
                    _FONT_FACE,
                    "%",
                    100,
                    20, 
                _MemGraphHeight
                );
                ConfigGraph = graph.config;
                // Mem
                SerieMem = get_smooth_line_area_serie(_COLORS[1]);
                graph.add_serie (SerieMem);

                // Swap
                SerieSwap = get_smooth_line_area_serie(_COLORS[3]);
                graph.add_serie (SerieSwap);

                // overlay 
                InfoLabel = new Gtk.Label(null);
                InfoLabel.halign = Gtk.Align.END;
                InfoLabel.valign = Gtk.Align.START;
                InfoLabel.margin_top = 8;
                InfoLabel.margin_end = 8;

                overlay.set_child (graph);
                overlay.add_overlay (InfoLabel);
                append(overlay);

                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    ()=> _Mem.feed.connect(mem_feed_handler),
                    ()=> _Mem.feed.disconnect(mem_feed_handler)
                );
            }
        }
        private class DiskIOPanelWidget : Gtk.Box {
            private Gtk.Label                      DiskNameLabel;
            private bool                           Rendered = false;
            private Gtk.Stack                      Stack;
            private Chunk[]                        Chunk_Arr;

            private SideBar                        SideBar; 
            private GenericArray<LiveChart.Config> BrokenLivechartConfigs; 
            private string[]                       COLORS; 
            private string                         FONT_FACE; 
            private uint                           DiskIOGraphHeight; 
            private SharpUtils.DiskIO              DiskIO; 

            private void diskio_feed_handler(SharpUtils.DiskIOData? _DiskIOData){
                if (!Rendered){
                    if (_DiskIOData.disks.length == 0)
                        return;
                    Rendered = true;
                    _DiskIOData.disks.foreach((_Disk)=>{
                        var chunk = new Chunk(
                            SideBar, 
                            BrokenLivechartConfigs, 
                            COLORS, 
                            FONT_FACE, 
                            DiskIOGraphHeight, 
                            DiskIO, 
                            _Disk.lookup("name")
                        );
                        Stack.add_child(chunk);
                        Chunk_Arr += chunk;
                    });
                    if (Chunk_Arr.length > 0) {
                        DiskNameLabel.set_text(Chunk_Arr[0].DiskName);
                        Stack.set_visible_child(Chunk_Arr[0]);
                    }
                }
            }

            private class Chunk : Gtk.Box {
                private string[]                  COLORS;

                private LiveChart.Config          ConfigKibps;
                private LiveChart.Config          ConfigIOps;

                private LiveChart.Serie           SerieReadKibps;
                private LiveChart.Serie           SerieWriteKibps;
                private LiveChart.Serie           SerieReadIOps;
                private LiveChart.Serie           SerieWriteIOps;

                private Gtk.Label                 InfoLabelKibps;
                private Gtk.Label                 InfoLabelIOps;

                public string                     DiskName;
                
                // pushing zero values from the start to smooth line area 
                // causes artifacts.
                public bool                       HitNonZeroReadKibps = false;
                public bool                       HitNonZeroWriteKibps = false;

                private void diskio_feed_handler(
                    SharpUtils.DiskIOData? _DiskIOData
                    ){
                    HashTable<string, string> Disk = null;
                    foreach (var _Disk in _DiskIOData.disks ){
                        if (_Disk.lookup("name") == DiskName){
                            Disk = _Disk;
                            break;
                        }
                    }
                    if (Disk == null) 
                        return;

                    var read_kibps = long.parse (Disk.lookup ("read_kibps"));
                    var read_kibps_str = simplify_kib(read_kibps);

                    if (read_kibps > 0) 
                        HitNonZeroReadKibps = true;

                    var write_kibps = long.parse (Disk.lookup ("write_kibps"));
                    var write_kibps_str = simplify_kib(write_kibps);

                    if (write_kibps > 0) 
                        HitNonZeroWriteKibps = true;

                    var read_iops = long.parse (Disk.lookup ("read_iops"));
                    var write_iops = long.parse (Disk.lookup ("write_iops"));
                    
                    var timestamp_kibps =
                        get_real_time()/ConfigKibps.time.conv_us;
                    var timestamp_iops = 
                        get_real_time()/ConfigIOps.time.conv_us;

                    if (HitNonZeroReadKibps){
                        // add_with_timestamp is essencial here
                        SerieReadKibps.add_with_timestamp(
                            read_kibps,
                            timestamp_kibps
                        );
                        SerieReadIOps.add_with_timestamp(
                            read_iops,
                            timestamp_kibps
                        );
                    }

                    InfoLabelKibps.set_markup(@"<span
                    foreground=\"$(COLORS[0])\"
                    background=\"$(COLORS[3])\"
                    font_size=\"8pt\"
                    > R:$(read_kibps_str) W:$(write_kibps_str) </span>"
                    );

                    if (HitNonZeroWriteKibps){
                        SerieWriteKibps.add_with_timestamp(
                            write_kibps,
                            timestamp_iops
                        );
                        SerieWriteIOps.add_with_timestamp(
                            write_iops,
                            timestamp_iops
                        );
                    }

                    InfoLabelIOps.set_markup(@"<span
                    foreground=\"$(COLORS[0])\"
                    background=\"$(COLORS[3])\"
                    font_size=\"8pt\"
                    > R:$(read_iops) IO/s W:$(write_iops) IO/s </span>"
                    );
                }

                public Chunk (
                    SideBar                        _SideBar,
                    GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                    string[]                       _COLORS,
                    string                         _FONT_FACE,
                    uint                           _DiskIOGraphHeight,
                    SharpUtils.DiskIO              _DiskIO,
                    string                         _DiskName
                    ) {
                    orientation = Gtk.Orientation.VERTICAL;
                    spacing     = 0;
                    css_classes = {"chunk"};

                    COLORS   = _COLORS;
                    DiskName = _DiskName;

                    var overlay_kibps = new Gtk.Overlay();
                    overlay_kibps.css_classes = {"kibps"};
                    var graph_kibps   = get_graph(
                        _BrokenLivechartConfigs, 
                        _COLORS, 
                        _FONT_FACE, 
                        "K", 
                        null, 
                        null, 
                        _DiskIOGraphHeight
                    );
                    graph_kibps.css_classes = {"graph_kibps"};
                    ConfigKibps = graph_kibps.config;
                    SerieReadKibps = get_smooth_line_area_serie(_COLORS[5]);
                    graph_kibps.add_serie(SerieReadKibps);
                    SerieWriteKibps = get_smooth_line_area_serie(_COLORS[6]);
                    graph_kibps.add_serie(SerieWriteKibps);

                    InfoLabelKibps = new Gtk.Label(null);
                    InfoLabelKibps.halign = Gtk.Align.END;
                    InfoLabelKibps.valign = Gtk.Align.START;
                    InfoLabelKibps.margin_top = 8;
                    InfoLabelKibps.margin_end = 8;
                    
                    overlay_kibps.set_child(graph_kibps);
                    overlay_kibps.add_overlay(InfoLabelKibps);
                    append(overlay_kibps);
                    
                    var overlay_iops = new Gtk.Overlay();
                    overlay_iops.css_classes = {"iops"};
                    var graph_iops   = get_graph(
                        _BrokenLivechartConfigs, 
                        _COLORS, 
                        _FONT_FACE, 
                        "", 
                        null, 
                        null, 
                        _DiskIOGraphHeight
                    );
                    graph_iops.css_classes = {"graph_iops"};
                    ConfigIOps = graph_iops.config;
                    SerieReadIOps = get_bar_serie(_COLORS[5]);
                    graph_iops.add_serie(SerieReadIOps);
                    SerieWriteIOps = get_bar_serie(_COLORS[6]);
                    graph_iops.add_serie(SerieWriteIOps);

                    InfoLabelIOps = new Gtk.Label(null);
                    InfoLabelIOps.halign = Gtk.Align.END;
                    InfoLabelIOps.valign = Gtk.Align.START;
                    InfoLabelIOps.margin_top = 8;
                    InfoLabelIOps.margin_end = 8;
                    
                    overlay_iops.set_child(graph_iops);
                    overlay_iops.add_overlay(InfoLabelIOps);
                    append(overlay_iops);

                    _SideBar.StateBindingArr += _SideBar.bind_to_state(
                        ()=> _DiskIO.feed.connect(diskio_feed_handler),
                        ()=> _DiskIO.feed.disconnect(diskio_feed_handler),
                        true
                    );
                }
            }
            public DiskIOPanelWidget(
                SideBar                        _SideBar,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _DiskIOGraphHeight,
                SharpUtils.DiskIO              _DiskIO
                ) {
                SideBar                = _SideBar;
                COLORS                 = _COLORS;
                FONT_FACE              = _FONT_FACE;
                BrokenLivechartConfigs = _BrokenLivechartConfigs;
                DiskIOGraphHeight      = _DiskIOGraphHeight;
                DiskIO                 = _DiskIO;
                orientation = Gtk.Orientation.VERTICAL;
                spacing     = 0;
                css_classes = {"diskio_panel_widget"};

                var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                header.css_classes = {"header"};

                DiskNameLabel = new Gtk.Label(null);
                DiskNameLabel.css_classes = {"disk_name"};
                DiskNameLabel.set_ellipsize (Pango.EllipsizeMode.START);
            
                var separator_header = 
                    new Gtk.Box (Gtk.Orientation.HORIZONTAL,0){
                    hexpand = true
                };

                var cursor = 0;

                var prev = new Gtk.Button.with_label ("");
                prev.css_classes = {"prev"};
                prev.clicked.connect(()=>{
                    if (Chunk_Arr.length == 0){
                        return;
                    } 
                    cursor--;
                    if (0 > cursor) {
                        cursor = (Chunk_Arr.length - 1);    
                    }
                    DiskNameLabel.set_text (
                        Chunk_Arr[cursor].DiskName
                    );
                    Stack.set_visible_child (
                        Chunk_Arr[cursor]
                    );
                });

                var next = new Gtk.Button.with_label ("");
                next.css_classes = {"next"};
                next.clicked.connect(()=>{
                    if (Chunk_Arr.length == 0){
                        return;
                    } 
                    cursor++;
                    if (Chunk_Arr.length <= cursor) {
                        cursor = 0;    
                    }
                    DiskNameLabel.set_text (
                        Chunk_Arr[cursor].DiskName
                    );
                    Stack.set_visible_child (
                        Chunk_Arr[cursor]
                    );
                });
            
                header.append (DiskNameLabel);
                header.append (separator_header);
                header.append (prev);
                header.append (next);

                Stack = new Gtk.Stack();
                Stack.css_classes = {"stack"};

                append(header);
                append(Stack);


                _SideBar.StateBindingArr += _SideBar.bind_to_state(
                    ()=> _DiskIO.feed.connect(diskio_feed_handler),
                    ()=> _DiskIO.feed.disconnect(diskio_feed_handler)
                );
            }
        }
        private class TabbedPanelWidget : Gtk.Box {
            private class RMPCWidget : Gtk.Box {
                private Gtk.Image  ImageAlbumArt;
                private Gtk.Label  LabelTitle;
                private Gtk.Label  LabelArtists;
                private Gtk.Label  LabelPrev;
                private Gtk.Button ButtonPrev;
                private Gtk.Label  LabelPP;
                private Gtk.Button ButtonPP;
                private Gtk.Label  LabelNext;
                private Gtk.Button ButtonNext;
                private Gtk.Scale  Scale;
                private Gtk.Label  LabelRepeat;
                private Gtk.Button ButtonRepeat;
                private Gtk.Label  LabelRandom;
                private Gtk.Button ButtonRandom;
                private Gtk.Label  LabelSingle;
                private Gtk.Button ButtonSingle;
                private Gtk.Label  LabelConsume;
                private Gtk.Button ButtonConsume;
                
                private uint      TitleAndArtistsChars;
                private uint      SongDuration;
                private uint      SongElapsed;

                private void rmpc_feed_handler(SharpUtils.RMPCData? _RMPCData){
                    LabelTitle.set_text(
                        SharpUtils.scroll_text(
                            _RMPCData.title,
                            TitleAndArtistsChars)
                    );
                    var artists_str = "" ; 
                    for (var i = 0; i < _RMPCData.artist.length; i++){
                        artists_str += _RMPCData.artist[i];
                        if (i < (_RMPCData.artist.length - 1)) {
                            artists_str += ",";
                        }
                    }
                    LabelArtists.set_text(
                        SharpUtils.scroll_text(artists_str, TitleAndArtistsChars)
                    );
                    ImageAlbumArt.set_from_file(_RMPCData.albumart_path);

                    SongDuration = _RMPCData.duration;
                    SongElapsed = _RMPCData.elapsed;
                    Scale.set_range(0, SongDuration);
                    Scale.set_value(SongElapsed);

                    ButtonPP.css_classes      = {"pp"};
                    ButtonNext.css_classes    = {"next"};
                    ButtonPrev.css_classes    = {"prev"};
                    ButtonRepeat.css_classes  = {"repeat"};
                    ButtonRandom.css_classes  = {"random"};
                    ButtonSingle.css_classes  = {"single"};
                    ButtonConsume.css_classes = {"consume"};

                    if (_RMPCData.state == "Pause"){
                        LabelPP.set_text ("󰐊"); 
                        ButtonPP.add_css_class("pp_paused");
                    } else {
                        LabelPP.set_text ("󰏤"); 
                        ButtonPP.add_css_class("pp_resumed");
                    }
                    if (_RMPCData.repeat){
                        ButtonRepeat.add_css_class("repeat_on");
                    } 
                    if (_RMPCData.random){
                        ButtonRandom.add_css_class("random_on");
                    } 
                    if (_RMPCData.single == "On"){
                        ButtonSingle.add_css_class("single_on");
                    } else if (_RMPCData.single == "Oneshot"){
                        ButtonSingle.add_css_class("single_oneshot");
                    }
                    if (_RMPCData.consume == "On"){
                        ButtonConsume.add_css_class("consume_on");
                    } else if (_RMPCData.consume == "Oneshot"){
                        ButtonConsume.add_css_class("consume_oneshot");
                    }
                }
                public RMPCWidget(
                    SideBar         _SideBar,  
                    SharpUtils.RMPC _RMPC,
                    uint            _AlbumArtSize,
                    uint            _TitleAndArtistsChars
                    ) {
                    orientation           = Gtk.Orientation.HORIZONTAL;
                    spacing               = 0;
                    css_classes           = {"rmpc"};
                    TitleAndArtistsChars  = _TitleAndArtistsChars;

                    ImageAlbumArt = new Gtk.Image();
                    ImageAlbumArt.pixel_size = (int)_AlbumArtSize;
                    append(ImageAlbumArt);

                    var controls = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
                    controls.css_classes = {"controls"};
                    append(controls);
                    
                    LabelTitle   = new Gtk.Label(null);
                    LabelTitle.css_classes = {"title"};
                    controls.append(LabelTitle);
                    LabelArtists = new Gtk.Label(null);
                    LabelArtists.css_classes = {"artists"};
                    controls.append(LabelArtists);

                    var nav = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                    nav.hexpand = true;
                    nav.halign  = Gtk.Align.CENTER;
                    nav.css_classes = {"nav"};
                    controls.append(nav);

                    LabelPrev = new Gtk.Label("󰒮"); 
                    ButtonPrev  = new Gtk.Button();
                    ButtonPrev.set_child(LabelPrev);
                    ButtonPrev.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.PREV);
                    });
                    nav.append(ButtonPrev);

                    LabelPP   = new Gtk.Label(null); 
                    ButtonPP    = new Gtk.Button();
                    ButtonPP.set_child(LabelPP);
                    ButtonPP.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.TOGGLEPAUSE);
                    });
                    nav.append(ButtonPP);

                    LabelNext = new Gtk.Label("󰒭"); 
                    ButtonNext  = new Gtk.Button();
                    ButtonNext.set_child(LabelNext);
                    ButtonNext.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.NEXT);
                    });
                    nav.append(ButtonNext);

                    Scale = new Gtk.Scale(Gtk.Orientation.HORIZONTAL,null);
                    Scale.hexpand     = true;
                    Scale.css_classes = {"scale"};
                    Scale.set_increments(1, 1);
                    Scale.change_value.connect((scroll,value)=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.SEEK, (uint) value);
                        Scale.set_value(value);
                        return true;
                    });

                    controls.append(Scale);
                    
                    var mods = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                    mods.css_classes = {"mods"};
                    mods.hexpand = true;
                    mods.halign = Gtk.Align.END;
                    controls.append(mods);

                    LabelRepeat  = new Gtk.Label("󰑖");
                    ButtonRepeat   = new Gtk.Button();
                    ButtonRepeat.set_child(LabelRepeat);
                    ButtonRepeat.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.TOGGLEREPEAT);
                    });
                    mods.append(ButtonRepeat);

                    LabelRandom  = new Gtk.Label("");
                    ButtonRandom   = new Gtk.Button();
                    ButtonRandom.set_child(LabelRandom);
                    ButtonRandom.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.TOGGLERANDOM);
                    });
                    mods.append(ButtonRandom);

                    LabelSingle  = new Gtk.Label("󰑊");
                    ButtonSingle   = new Gtk.Button();
                    ButtonSingle.set_child(LabelSingle);
                    ButtonSingle.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.TOGGLESINGLE);
                    });
                    mods.append(ButtonSingle);

                    LabelConsume = new Gtk.Label("󰆴");
                    ButtonConsume   = new Gtk.Button();
                    ButtonConsume.set_child(LabelConsume);
                    ButtonConsume.clicked.connect(()=>{
                        _RMPC.action(SharpUtils.RMPC.Actions.TOGGLECONSUME);
                    });
                    mods.append(ButtonConsume);
                    
                    _SideBar.StateBindingArr += _SideBar.bind_to_state(
                        ()=> _RMPC.feed.connect(rmpc_feed_handler), 
                        ()=> _RMPC.feed.disconnect(rmpc_feed_handler) 
                    );
                }
            }
            private class CavaWidget : Gtk.Box {
                private bool           Rendered = false;
                private Gtk.LevelBar[] LevelBarArr = {};
                private void cava_feed_handler(SharpUtils.CavaData? _CavaData){
                    if (!Rendered) {
                        _CavaData.data.foreach((i)=>{
                            var levelbar = new Gtk.LevelBar.for_interval(0, 100){
                                css_classes = {"levelbar"},
                                orientation = Gtk.Orientation.VERTICAL,
                                inverted = true,
                                hexpand = true,
                                vexpand = true
                            }; 
                            levelbar.add_offset_value("low", 30);
                            levelbar.add_offset_value("high", 60);
                            levelbar.add_offset_value("full", 100);
                            LevelBarArr += levelbar;
                            append(levelbar);
                        });
                        Rendered = true;
                    }
                    for (var i = 0; i < LevelBarArr.length; i++){
                        var levelbar = LevelBarArr[i];
                        var value = (int) Math.fmin (
                            Math.fmax (_CavaData.data[i], 1), 100
                        );
                        levelbar.set_value (value);
                    }
                }
                public CavaWidget(
                    SideBar         _SideBar,  
                    SharpUtils.Cava _Cava
                    ){
                    orientation           = Gtk.Orientation.HORIZONTAL;
                    spacing               = 0;
                    css_classes           = {"cava"};
                    // Start is paused 
                    _SideBar.StateBindingArr += _SideBar.bind_to_state(
                        ()=>{
                            _Cava.resume();
                            _Cava.feed.connect(cava_feed_handler);
                        },
                        ()=>{
                            _Cava.pause();
                            _Cava.feed.disconnect(cava_feed_handler); 
                        },
                        true
                    );
                }
            }
            private class BTWidget : Gtk.Box {
                private class ControllerWidget : Gtk.Box {
                    private Gtk.Label         LabelDefaultStatus;
                    private Gtk.Label         LabelName;
                    private Gtk.Label         LabelScanningStatus;
                    private Gtk.Button        ButtonPowered;
                    private Gtk.Button        ButtonDiscoverable;
                    private Gtk.Button        ButtonPairable;
                    private bool              Powered;
                    private bool              Discoverable;
                    private bool              Pairable;

                    private string     MAC;

                    private void bt_feed_handler(SharpUtils.BTData? _BTData){
                        HashTable<string, string> controller = null;
                        foreach (var ctrl in _BTData.controllers){
                            if (ctrl.lookup("mac") == MAC){
                                controller = ctrl;
                            }
                        }
                        if (controller == null) return;

                        if (controller.lookup("is_default") == "yes"){
                            LabelDefaultStatus.set_text("[D]");
                        } else LabelDefaultStatus.set_text("");

                        LabelName.set_text(controller.lookup("alias"));
                
                        if (controller.lookup("is_discovering") == "yes"){
                            LabelScanningStatus.set_text(
                                SharpUtils.simple_animate(
                                    {"", "" ,"", "", "", ""}
                                )
                            );
                        } else {
                            LabelScanningStatus.set_text("");
                        }

                        ButtonPowered.css_classes      = {"powered"};
                        ButtonDiscoverable.css_classes = {"discoverable"};
                        ButtonPairable.css_classes     = {"pairable"};

                        if (controller.lookup("is_powered") == "yes"){
                            ButtonPowered.add_css_class("powered_on");
                            Powered = true;
                        } else Powered = false;

                        if (controller.lookup("is_discoverable") == "yes"){
                            ButtonDiscoverable.add_css_class("discoverable_on");
                            Discoverable = true;
                        } else Discoverable = false;

                        if (controller.lookup("is_pairable") == "yes"){
                            ButtonPairable.add_css_class("pairable_on");
                            Pairable = true;
                        } else Pairable = false;
                    }
                    public signal void remove_feed_handler();
                    public ControllerWidget(
                        SideBar         _SideBar,  
                        BTWidget        _BTWidget,
                        SharpUtils.BT   _BT,
                        string          _MAC
                        ){
                        MAC         = _MAC;
                        orientation = Gtk.Orientation.VERTICAL;
                        spacing     = 0;
                        css_classes = {"controller_widget"};

                        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                        header.css_classes = {"header"};
                        append(header);
                        
                        LabelDefaultStatus = new Gtk.Label(null);
                        LabelDefaultStatus.css_classes = {"default_status"};
                        header.append(LabelDefaultStatus);

                        LabelName = new Gtk.Label(null);
                        LabelName.css_classes = {"name"};
                        LabelName.hexpand = true;
                        LabelName.xalign = 0f;
                        header.append(LabelName);

                        LabelScanningStatus = new Gtk.Label(null);
                        LabelScanningStatus.css_classes = {"scanning_status"};
                        header.append(LabelScanningStatus);

                        var nav = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                        nav.css_classes = {"nav"};
                        append(nav);

                        ButtonPowered = new Gtk.Button.with_label("Power");
                        ButtonPowered.hexpand = true;
                        ButtonPowered.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.CONTROLLER_POWER,
                                !Powered
                            );
                        });
                        nav.append(ButtonPowered);

                        ButtonDiscoverable = new Gtk.Button.with_label(
                            "Discoverable"
                        );
                        ButtonDiscoverable.hexpand = true;
                        ButtonDiscoverable.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.CONTROLLER_DISCOVERABLE,
                                !Discoverable
                            );
                        });
                        nav.append(ButtonDiscoverable);

                        ButtonPairable = new Gtk.Button.with_label("Pairable");
                        ButtonPairable.hexpand = true;
                        ButtonPairable.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.CONTROLLER_PAIRABLE,
                                !Pairable
                            );
                        });
                        nav.append(ButtonPairable);

                        _BTWidget.StateBindingArr += _SideBar.bind_to_state(
                            ()=> {
                                _BT.feed.connect(bt_feed_handler);
                                _BT.action.begin(SharpUtils.BT.Actions.SCAN,true);
                                }, 
                            ()=> {
                                _BT.feed.disconnect(bt_feed_handler);
                                _BT.action.begin(
                                    SharpUtils.BT.Actions.SCAN,false
                                    );
                                }, 
                            true
                        );
                        remove_feed_handler.connect(()=>{
                            _BT.feed.disconnect(bt_feed_handler);
                        });
                    }
                } 

                private class DevicesWidget : Gtk.Box {
                    private Gtk.Label  LabelDeviceType;
                    private Gtk.Label  LabelName;
                    private Gtk.Label  LabelBattery;
                    private Gtk.Button ButtonRemove;

                    private Gtk.Button ButtonPaired;
                    private Gtk.Button ButtonTrusted;
                    private Gtk.Button ButtonBlocked;
                    private Gtk.Button ButtonConnected;

                    private bool       Paired;
                    private bool       Trusted;
                    private bool       Blocked;
                    private bool       Connected;

                    public string     MAC;

                    private void bt_feed_handler(SharpUtils.BTData? _BTData){
                        HashTable<string, string> device = null;
                        foreach (var dev in _BTData.devices){
                            if (dev.lookup("mac") == MAC){
                                device = dev;
                            }
                        }

                        if (device == null) return;

                        //print("[%lld] (%s) %d\n",  
                        //   get_real_time(),
                        //   MAC,
                        //  ref_count);

                        if (device.lookup("is_audio_device") == "yes"){
                            LabelDeviceType.set_text("󰋋");
                        } else LabelDeviceType.set_text("󰂯");

                        LabelName.set_text(device.lookup("name"));

                        if (device.contains("battery_perc")){
                            LabelBattery.set_text(
                                @"$(device.lookup("battery_perc"))% 󰥈"
                            );
                        } else LabelBattery.set_text("");
                

                        ButtonPaired.css_classes    = {"paired"};
                        ButtonTrusted.css_classes   = {"trusted"};
                        ButtonBlocked.css_classes   = {"blocked"};
                        ButtonConnected.css_classes = {"connected"};

                        if (device.lookup("is_paired") == "yes"){
                            ButtonPaired.add_css_class("paired_on");
                            Paired = true;
                        } else Paired  = false;

                        if (device.lookup("is_trusted") == "yes"){
                            ButtonTrusted.add_css_class("trusted_on");
                            Trusted = true;
                        } else Trusted  = false;

                        if (device.lookup("is_blocked") == "yes"){
                            ButtonBlocked.add_css_class("blocked_on");
                            Blocked = true;
                        } else Blocked  = false;

                        if (device.lookup("is_connected") == "yes"){
                            ButtonConnected.add_css_class("connected_on");
                            Connected = true;
                        } else Connected  = false;
                    }

                    public signal void remove_feed_handler();
                    public DevicesWidget(
                        SideBar         _SideBar,  
                        BTWidget        _BTWidget,
                        SharpUtils.BT   _BT,
                        string          _MAC
                        ){
                        MAC         = _MAC;
                        orientation = Gtk.Orientation.VERTICAL;
                        spacing     = 0;
                        css_classes = {"devices_widget"};

                        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                        header.css_classes = {"header"};
                        append(header);
                        
                        LabelDeviceType = new Gtk.Label(null);
                        LabelDeviceType.css_classes = {"device_type"};
                        header.append(LabelDeviceType);

                        LabelName = new Gtk.Label(null);
                        LabelName.css_classes = {"name"};
                        LabelName.hexpand = true;
                        LabelName.xalign = 0f;
                        header.append(LabelName);

                        LabelBattery = new Gtk.Label(null);
                        LabelBattery.css_classes = {"battery"};
                        header.append(LabelBattery);

                        ButtonRemove = new Gtk.Button.with_label("X");
                        ButtonRemove.css_classes = {"remove"};
                        ButtonRemove.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.DEVICE_REMOVE,
                                true,MAC
                            );
                        });
                        header.append(ButtonRemove);

                        var nav = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                        nav.css_classes = {"nav"};
                        append(nav);

                        ButtonPaired = new Gtk.Button.with_label("Pair");
                        ButtonPaired.hexpand = true;
                        ButtonPaired.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.DEVICE_PAIR,
                                !Paired, MAC
                            );
                        });
                        nav.append(ButtonPaired);

                        ButtonTrusted = new Gtk.Button.with_label("Trust");
                        ButtonTrusted.hexpand = true;
                        ButtonTrusted.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.DEVICE_TRUST,
                                !Trusted, MAC
                            );
                        });
                        nav.append(ButtonTrusted);

                        ButtonBlocked = new Gtk.Button.with_label("Block");
                        ButtonBlocked.hexpand = true;
                        ButtonBlocked.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.DEVICE_BLOCK,
                                !Blocked, MAC
                            );
                        });
                        nav.append(ButtonBlocked);

                        ButtonConnected = new Gtk.Button.with_label("Connect");
                        ButtonConnected.hexpand = true;
                        ButtonConnected.clicked.connect(()=>{
                            _BT.action.begin(
                                SharpUtils.BT.Actions.DEVICE_CONNECT,
                                !Connected, MAC
                            );
                        });
                        nav.append(ButtonConnected);

                        _BTWidget.StateBindingArr += _SideBar.bind_to_state(
                            ()=> _BT.feed.connect(bt_feed_handler), 
                            ()=> _BT.feed.disconnect(bt_feed_handler),
                            true
                        );
                        remove_feed_handler.connect(()=>{
                            _BT.feed.disconnect(bt_feed_handler);
                        });
                    }
                } 
                private SideBar             SideBar;
                private SharpUtils.BT       BT;
                private bool                Rendered = false;
                private Gtk.Box             Box;
                private string[]            ControllerArr       = {};
                private string[]            DevicesArr          = {};
                public  StateBinding[]      StateBindingArr     = {};
                private  DevicesWidget[]    DevicesWidgetArr    = {};
                private  ControllerWidget[] ControllerWidgetArr = {};

                private void bt_feed_handler(SharpUtils.BTData? _BTData){
                    // check for change
                    string[] ControllerArrFresh = {};
                    string[] DevicesArrFresh    = {};
                    foreach (var ctrl in _BTData.controllers){
                        ControllerArrFresh += ctrl.lookup("mac");
                    }
                    foreach (var dev in _BTData.devices){
                        DevicesArrFresh += dev.lookup("mac");
                    }

                    if (!SharpUtils.simple_cmp_str_arr(
                            ControllerArr, ControllerArrFresh
                        ) || !SharpUtils.simple_cmp_str_arr(
                            DevicesArr, DevicesArrFresh)
                        ) {
                        // Total 4 refs are to be removed to fully remove the
                        // old widgets to not have duplicates.

                        // 1. Held by Box as a child
                        // 2. Held by StateBindingArr as it explicitly 
                        //    owns the two closures.
                        // 3. Held by Either ControllerWidgetArr or 
                        //    DevicesWidgetArr
                        // 4. No clue but somehow gets removed by the end of this 
                        //    function 
                        // Note: Objects with signals do not seem to own the 
                        //       signal handlers strongly.

                        // Just in case, although I dont think lingering 
                        // connections do anything bad. They just get ignored.
                        foreach (var sb in StateBindingArr){
                            sb.remove_binding();
                        }
                        foreach (var ctrl in ControllerWidgetArr){
                            ctrl.remove_feed_handler();
                        }
                        foreach (var dev in DevicesWidgetArr){
                            dev.remove_feed_handler();
                        }
                        
                        SharpUtils.empty_box(Box); // (1)
                        this.StateBindingArr = {}; // (2)
                        ControllerWidgetArr = {}; // (3)
                        DevicesWidgetArr    = {}; // (3)
                        Rendered = false;
                    }

                    ControllerArr = ControllerArrFresh;
                    DevicesArr    = DevicesArrFresh;

                    if (!Rendered){
                        foreach (var ctrl in _BTData.controllers){
                            var mac = ctrl.lookup("mac");
                            var controller_widget = new ControllerWidget(
                                this.SideBar, 
                                this,
                                BT,
                                mac
                            );
                            Box.append(controller_widget);
                            ControllerWidgetArr += controller_widget;
                        }
                        foreach (var dev in _BTData.devices){
                            var mac = dev.lookup("mac");
                            var devices_widget = new DevicesWidget(
                                this.SideBar, 
                                this,
                                BT,
                                mac
                            );
                            Box.append(devices_widget);
                            DevicesWidgetArr += devices_widget;
                        }
                        Rendered = true;
                    }

                }
                public BTWidget(
                    SideBar         _SideBar,  
                    SharpUtils.BT   _BT
                    ){
                    SideBar     = _SideBar;
                    BT          = _BT;
                    css_classes = {"bt_widget"};
                    var scrolled_window = new Gtk.ScrolledWindow();
                    append(scrolled_window);

                    Box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
                    Box.hexpand = true;
                    Box.vexpand = true;
                    Box.css_classes = {"box"};
                    scrolled_window.set_child(Box);

                    _SideBar.StateBindingArr += _SideBar.bind_to_state(
                        ()=> _BT.feed.connect(bt_feed_handler), 
                        ()=> _BT.feed.disconnect(bt_feed_handler) 
                    );
                }
            }
            private enum States {MUSIC,BT}
            private States State = States.MUSIC;
            private signal void state_change(States _State);

            public TabbedPanelWidget(
                SideBar         _SideBar,  
                SharpUtils.RMPC _RMPC,
                SharpUtils.Cava _Cava,
                SharpUtils.BT   _BT,
                uint            _AlbumArtSize, 
                uint            _TitleAndArtistsChars
                ) {
                orientation = Gtk.Orientation.VERTICAL;
                spacing     = 0;
                css_classes = {"tabbed_widget_panel"}; 
                var stack = new Gtk.Stack();
                append(stack);

                var nav = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
                nav.css_classes = {"nav"};
                append(nav);

                var music = new Gtk.Button.with_label("󰽰");
                music.css_classes = {"music"};
                music.clicked.connect(()=> state_change(States.MUSIC));
                nav.append(music);

                var bt = new Gtk.Button.with_label("󰂯");
                bt.css_classes = {"bt"};
                bt.clicked.connect(()=> state_change(States.BT));
                nav.append(bt);

                var music_tab = new Gtk.Box(Gtk.Orientation.VERTICAL,0);
                var rmpc_widget = new RMPCWidget(
                    _SideBar, 
                    _RMPC, 
                    _AlbumArtSize, 
                    _TitleAndArtistsChars
                );
                var cava_widget = new CavaWidget(
                    _SideBar, 
                    _Cava
                );
                music_tab.append(rmpc_widget);
                music_tab.append(cava_widget);
                stack.add_child(music_tab);

                var bt_widget = new BTWidget(
                    _SideBar, 
                    _BT
                );
                stack.add_child(bt_widget);

                state_change.connect((_State)=>{
                    switch (_State) {
                        case States.MUSIC: 
                            State = _State;
                            stack.set_visible_child(music_tab);
                            break;
                        case States.BT: 
                            State = _State;
                            stack.set_visible_child(bt_widget);
                            break;
                    } 
                });
            }
        }
        private class ActionSlab : Gtk.Box {
            public ActionSlab(
                SideBar                        _SideBar,
                SharpUtils.Animation           _Brain,
                SharpUtils.Fastfetch           _FastFetch,
                SharpUtils.CPU                 _CPU,
                SharpUtils.Mem                 _Mem,
                SharpUtils.DiskIO              _DiskIO,
                SharpUtils.RMPC                _RMPC,
                SharpUtils.Cava                _Cava,
                SharpUtils.BT                  _BT,
                GenericArray<LiveChart.Config> _BrokenLivechartConfigs,
                string[]                       _COLORS,
                string                         _FONT_FACE,
                uint                           _CPUPanelHeight,
                uint                           _CPUPanelHeaderChars,
                ulong                          _CPUPanelHeaderScrollInterval,
                uint                           _MemGraphHeight,
                uint                           _DiskIOGraphHeight,
                uint                           _RMPCAlbumArtSize,
                uint                           _RMPCTitleAndArtistsChars
                ){
                orientation = Gtk.Orientation.VERTICAL;
                spacing     = 0;
                css_classes = {"action_slab_widget"};
                // ._________.
                // | Brain  |
                // ``````````
                var brain_widget = new BrainWidget(
                    _SideBar,
                    _Brain,
                    _FastFetch,
                    _COLORS
                );
                append(brain_widget);
                // ._____________.
                // | CPU Panel  |
                // ``````````````
                var cpu_panel_widget = new CPUPanelWidget(
                    _SideBar,
                    _CPU,
                    _FastFetch,
                    _BrokenLivechartConfigs,
                    _COLORS,
                    _FONT_FACE,
                    _CPUPanelHeight,
                    _CPUPanelHeaderChars,
                    _CPUPanelHeaderScrollInterval
                );
                append(cpu_panel_widget);
                // ._____________.
                // | Mem Panel  |
                // ``````````````
                var mem_panel_widget = new MemPanelWidget(
                    _SideBar, 
                    _BrokenLivechartConfigs, 
                    _COLORS, 
                    _FONT_FACE, 
                    _MemGraphHeight, 
                    _Mem
                );
                append(mem_panel_widget);
                // .________________.
                // | DiskIO Panel  |
                // `````````````````
                var diskio_panel_widget = new DiskIOPanelWidget(
                    _SideBar, 
                    _BrokenLivechartConfigs, 
                    _COLORS, 
                    _FONT_FACE, 
                    _DiskIOGraphHeight, 
                    _DiskIO
                );
                append(diskio_panel_widget);
                // .________________.
                // | Tabbed Panel  |
                // `````````````````
                var tabbed_panel_widget = new TabbedPanelWidget(
                    _SideBar, 
                    _RMPC, 
                    _Cava, 
                    _BT,
                    _RMPCAlbumArtSize, 
                    _RMPCTitleAndArtistsChars
                );
                append(tabbed_panel_widget);
            }
        }
        public SideBar(
            SharpShell            _SharpShell,
            bool                  _IS_DEBUG,
            SharpUtils.Brightness _Brightness,
            SharpUtils.Vol        _Vol,
            SharpUtils.Animation  _Brain,
            SharpUtils.Fastfetch  _FastFetch,
            SharpUtils.CPU        _CPU,
            SharpUtils.Mem        _Mem,
            SharpUtils.DiskIO     _DiskIO,
            SharpUtils.RMPC       _RMPC,
            SharpUtils.Cava       _Cava,
            SharpUtils.BT         _BT,
            string[]              _COLORS,
            string                _FONT_FACE,
            uint                  _CPUPanelHeight = 120,
            uint                  _CPUPanelHeaderChars = 16,
            ulong                 _CPUPanelHeaderScrollInterval = 1000000,
            uint                  _MemGraphHeight = 90,
            uint                  _DiskIOGraphHeight = 80,
            uint                  _RMPCAlbumArtSize = 120,
            uint                  _RMPCTitleAndArtistsChars = 11
            ) {
            application = _SharpShell;
            css_classes ={"sidebar"};

            // Set as shell layer
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.auto_exclusive_zone_enable (this);
            GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.TOP,   true);
            GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.BOTTOM,true);
            GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.RIGHT, true);
            // Main Box
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
            set_child (box);
            // +-----------+
            // | ActionBar |
            // +-----------+
            var action_bar_widget = new ActionBarWidget(
                this,
                _Brightness,
                _Vol
            );
            box.append (action_bar_widget);
            // +-------------+
            // | ActionSlab |
            // +------------+
            var action_slab_widget = new ActionSlab(
                this,
                _Brain,
                _FastFetch,
                _CPU,
                _Mem,
                _DiskIO,
                _RMPC,
                _Cava,
                _BT,
                BrokenLivechartConfigs,
                _COLORS,
                _FONT_FACE,
                _CPUPanelHeight,
                _CPUPanelHeaderChars,
                _CPUPanelHeaderScrollInterval,
                _MemGraphHeight,
                _DiskIOGraphHeight,
                _RMPCAlbumArtSize,
                _RMPCTitleAndArtistsChars
            );
            StateBindingArr += bind_to_state(
                () => {
                    handle_broken_configs();
                    box.prepend(action_slab_widget);
                },
                () => {
                    box.remove(action_slab_widget);
                    hide();
                    present();
                }
            );
        }
    }
}
